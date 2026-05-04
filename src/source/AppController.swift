/*
    AppController.swift

    Main application controller for the otx GUI target.
    All UI — menus, windows, views — is built programmatically.
    No NIB or Storyboard is used.

    This file is in the public domain.
*/

import AppKit
import Darwin.Mach

// HOST_BASIC_INFO_COUNT is a C macro not automatically bridged to Swift.
private let kHostBasicInfoCount = mach_msg_type_number_t(
    MemoryLayout<host_basic_info_data_t>.size / MemoryLayout<integer_t>.size)

// MARK: - OTXApplication
// Subclasses NSApplication so we can wire up AppController as the delegate
// before the event loop starts — without relying on a NIB file.

@objc(OTXApplication)
class OTXApplication: NSApplication {
    private var _controller: AppController?

    override func finishLaunching() {
        let ctrl = AppController()
        _controller = ctrl
        delegate    = ctrl
        super.finishLaunching()
    }
}

// MARK: - Constants

private let kOutputTextTag     = 100
private let kOutputFileBaseTag = 200
private let kOutputFileExtTag  = 201
private let kProcessSuccess    = "PROCESS_SUCCESS"

// MARK: - CPUID

private struct CPUID {
    var type:    cpu_type_t    = 0
    var subtype: cpu_subtype_t = 0
}

// MARK: - AppController

@objc class AppController: NSObject,
                            NSApplicationDelegate,
                            NSWindowDelegate,
                            NSMenuItemValidation,
                            NSTextFieldDelegate,
                            ProgressReporter,
                            ErrorReporter,
                            DropBoxDelegate {

    // MARK: - UI Properties (all built programmatically)

    private var mainWindow:    NSWindow!
    private var archPopup:     NSPopUpButton!
    private var thinButton:    NSButton!
    private var verifyButton:  NSButton!
    private var outputText:    NSTextField!
    private var pathText:      NSTextField!
    private var progText:      NSTextField!
    private var typeText:      NSTextField!
    private var progBar:       NSProgressIndicator!
    private var saveButton:    NSButton!
    private var dropBox:       DropBox!

    private var dropHintView:  NSView!
    private var fileInfoView:  NSView!
    private var metaBar:       NSView!
    private var outputBarView: NSView!
    private var progView:      NSView!

    private var prefsWindow: NSWindow!

    // MARK: - State

    private var objectFile: URL?
    private var selectedArchCPUType:    cpu_type_t    = 0
    private var selectedArchCPUSubType: cpu_subtype_t = 0
    private var cpuIDs: [CPUID] = Array(repeating: CPUID(), count: 10)
    private var fileArchMagic: UInt32 = 0
    private var fileIsValid    = false
    private var ignoreArch     = false
    private var exeIsFat       = false
    private var isProcessing   = false
    private var exeName:         String?
    private var outputFileLabel: String?
    private var outputFileName:  String?
    private var outputFilePath:  String?
    private var hostInfo = host_basic_info_data_t()
    private var indeterminateTimer: Timer?

    // MARK: - NSUserDefaults Setup

    private func registerDefaults() {
        let defaults: [String: Any] = [
            UserDefaultKey.askOutputDir:            "1",
            UserDefaultKey.demangleCppNames:        "YES",
            UserDefaultKey.entabOutput:             "NO",
            UserDefaultKey.openOutputFile:          "NO",
            UserDefaultKey.outputApp:               "TextEdit",
            UserDefaultKey.outputFileExtension:     "txt",
            UserDefaultKey.outputFileName:          "output",
            UserDefaultKey.separateLogicalBlocks:   "NO",
            UserDefaultKey.showDataSection:         "NO",
            UserDefaultKey.showIvarTypes:           "YES",
            UserDefaultKey.showLocalOffsets:        "YES",
            UserDefaultKey.checksumAlgorithm:       "sha256",
            UserDefaultKey.showMethodReturnTypes:   "YES",
            UserDefaultKey.showReturnStatements:    "YES",
            UserDefaultKey.useCustomName:           "0",
            UserDefaultKey.verboseMsgSends:         "YES",
        ]
        let ctrl = NSUserDefaultsController.shared
        ctrl.initialValues = defaults
        ctrl.defaults.register(defaults: defaults)
    }

    // MARK: - Application Lifecycle

    func applicationWillFinishLaunching(_ notification: Notification) {
        registerDefaults()

        var count = kHostBasicInfoCount
        withUnsafeMutablePointer(to: &hostInfo) { ptr in
            _ = ptr.withMemoryRebound(to: integer_t.self, capacity: Int(kHostBasicInfoCount)) {
                host_info(mach_host_self(), HOST_BASIC_INFO, $0, &count)
            }
        }
        selectedArchCPUType = hostInfo.cpu_type

        buildMenuBar()
        buildMainWindow()
        buildPrefsWindow()

        mainWindow.center()
        mainWindow.makeKeyAndOrderFront(nil)
    }

    func application(_ app: NSApplication, openFile filename: String) -> Bool {
        if NSWorkspace.shared.isFilePackage(atPath: filename) {
            newPackageFile(URL(fileURLWithPath: filename))
        } else {
            newOFile(URL(fileURLWithPath: filename), needsPath: true)
        }
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ app: NSApplication) -> Bool { true }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool { true }

    // MARK: - Menu Bar Builder

    private func buildMenuBar() {
        let mainMenu = NSMenu()

        // ── App menu ─────────────────────────────────────────────────────────
        let appItem = NSMenuItem()
        mainMenu.addItem(appItem)
        let appMenu = NSMenu()
        appItem.submenu = appMenu

        appMenu.addItem(withTitle: "About otx",
                        action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)),
                        keyEquivalent: "")
        appMenu.addItem(.separator())

        let prefsItem = NSMenuItem(title: "Preferences…",
                                   action: #selector(showPrefs(_:)),
                                   keyEquivalent: ",")
        prefsItem.target = self
        appMenu.addItem(prefsItem)
        appMenu.addItem(.separator())

        let servicesItem = NSMenuItem(title: "Services", action: nil, keyEquivalent: "")
        let servicesMenu = NSMenu(title: "Services")
        servicesItem.submenu = servicesMenu
        NSApp.servicesMenu   = servicesMenu
        appMenu.addItem(servicesItem)
        appMenu.addItem(.separator())

        appMenu.addItem(withTitle: "Hide otx",
                        action: #selector(NSApplication.hide(_:)),
                        keyEquivalent: "h")
        let hideOthers = NSMenuItem(title: "Hide Others",
                                    action: #selector(NSApplication.hideOtherApplications(_:)),
                                    keyEquivalent: "h")
        hideOthers.keyEquivalentModifierMask = [.command, .option]
        appMenu.addItem(hideOthers)
        appMenu.addItem(withTitle: "Show All",
                        action: #selector(NSApplication.unhideAllApplications(_:)),
                        keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit otx",
                        action: #selector(NSApplication.terminate(_:)),
                        keyEquivalent: "q")

        // ── File menu ─────────────────────────────────────────────────────────
        let fileItem = NSMenuItem(title: "File", action: nil, keyEquivalent: "")
        mainMenu.addItem(fileItem)
        let fileMenu = NSMenu(title: "File")
        fileItem.submenu = fileMenu

        let openItem = NSMenuItem(title: "Open…",
                                  action: #selector(openExe(_:)),
                                  keyEquivalent: "o")
        openItem.target = self
        fileMenu.addItem(openItem)
        fileMenu.addItem(.separator())
        fileMenu.addItem(withTitle: "Close",
                         action: #selector(NSWindow.performClose(_:)),
                         keyEquivalent: "w")
        let saveItem = NSMenuItem(title: "Save",
                                  action: #selector(attemptToProcessFile(_:)),
                                  keyEquivalent: "s")
        saveItem.target = self
        fileMenu.addItem(saveItem)

        // ── Edit menu ─────────────────────────────────────────────────────────
        let editItem = NSMenuItem(title: "Edit", action: nil, keyEquivalent: "")
        mainMenu.addItem(editItem)
        let editMenu = NSMenu(title: "Edit")
        editItem.submenu = editMenu

        editMenu.addItem(withTitle: "Undo",   action: Selector(("undo:")),      keyEquivalent: "z")
        editMenu.addItem(withTitle: "Redo",   action: Selector(("redo:")),      keyEquivalent: "Z")
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "Cut",    action: #selector(NSText.cut(_:)),       keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy",   action: #selector(NSText.copy(_:)),      keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste",  action: #selector(NSText.paste(_:)),     keyEquivalent: "v")
        editMenu.addItem(withTitle: "Delete", action: #selector(NSText.delete(_:)),    keyEquivalent: "")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")

        // ── Window menu ───────────────────────────────────────────────────────
        let windowItem = NSMenuItem(title: "Window", action: nil, keyEquivalent: "")
        mainMenu.addItem(windowItem)
        let windowMenu = NSMenu(title: "Window")
        windowItem.submenu = windowMenu

        windowMenu.addItem(withTitle: "Minimize",
                           action: #selector(NSWindow.performMiniaturize(_:)),
                           keyEquivalent: "m")
        windowMenu.addItem(withTitle: "Zoom",
                           action: #selector(NSWindow.performZoom(_:)),
                           keyEquivalent: "")
        windowMenu.addItem(.separator())
        let showMainItem = NSMenuItem(title: "otx",
                                      action: #selector(showMainWindow(_:)),
                                      keyEquivalent: "")
        showMainItem.target = self
        windowMenu.addItem(showMainItem)
        windowMenu.addItem(.separator())
        windowMenu.addItem(withTitle: "Bring All to Front",
                           action: #selector(NSApplication.arrangeInFront(_:)),
                           keyEquivalent: "")
        NSApp.windowsMenu = windowMenu

        // ── Help menu ─────────────────────────────────────────────────────────
        let helpItem = NSMenuItem(title: "Help", action: nil, keyEquivalent: "")
        mainMenu.addItem(helpItem)
        let helpMenu = NSMenu(title: "Help")
        helpItem.submenu = helpMenu
        helpMenu.addItem(withTitle: "otx Help",
                         action: #selector(NSApplication.showHelp(_:)),
                         keyEquivalent: "?")

        NSApp.mainMenu = mainMenu
    }

    // MARK: - Main Window Builder

    private func buildMainWindow() {
        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 300),
            styleMask:   [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing:     .buffered,
            defer:       false)
        win.title                       = "otx"
        win.titlebarAppearsTransparent  = true
        win.isMovableByWindowBackground = true
        win.minSize      = NSSize(width: 400, height: 260)
        win.maxSize      = NSSize(width: 900, height: 700)
        win.delegate     = self
        win.isRestorable = false
        win.isOpaque     = false
        win.backgroundColor = .clear
        win.setFrameAutosaveName("otx Main Window")

        let vfx = NSVisualEffectView()
        vfx.material     = .sidebar
        vfx.blendingMode = .behindWindow
        vfx.state        = .active
        win.contentView  = vfx

        let content = vfx

        // ── Drop Zone ─────────────────────────────────────────────────────────
        let db = DropBox(frame: .zero)
        db.translatesAutoresizingMaskIntoConstraints = false
        db.cornerRadius = 12
        db.borderColor  = NSColor.separatorColor
        db.fillColor    = NSColor.white.withAlphaComponent(0.06)
        db.delegate     = self
        content.addSubview(db)
        dropBox = db

        let hintView = buildDropHintView()
        hintView.translatesAutoresizingMaskIntoConstraints = false
        db.addSubview(hintView)
        dropHintView = hintView

        let infoView = buildFileInfoView()
        infoView.translatesAutoresizingMaskIntoConstraints = false
        infoView.isHidden = true
        db.addSubview(infoView)
        fileInfoView = infoView

        // ── Meta Bar (Type / Arch / Thin / Verify) ───────────────────────────
        let mBar = buildMetaBar()
        mBar.translatesAutoresizingMaskIntoConstraints = false
        mBar.isHidden = true
        content.addSubview(mBar)
        metaBar = mBar

        // ── Output Bar ───────────────────────────────────────────────────────
        let outBar = buildOutputBar()
        outBar.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(outBar)
        outputBarView = outBar

        // ── Progress View ────────────────────────────────────────────────────
        let prgView = buildProgressView()
        prgView.translatesAutoresizingMaskIntoConstraints = false
        prgView.isHidden = true
        content.addSubview(prgView)
        progView = prgView

        // ── Auto Layout ───────────────────────────────────────────────────────
        let m: CGFloat = 16
        NSLayoutConstraint.activate([
            db.topAnchor.constraint(equalTo: content.safeAreaLayoutGuide.topAnchor, constant: m),
            db.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: m),
            db.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -m),
            db.bottomAnchor.constraint(equalTo: mBar.topAnchor, constant: -8),

            hintView.centerXAnchor.constraint(equalTo: db.centerXAnchor),
            hintView.centerYAnchor.constraint(equalTo: db.centerYAnchor),

            infoView.topAnchor.constraint(equalTo: db.topAnchor, constant: 14),
            infoView.leadingAnchor.constraint(equalTo: db.leadingAnchor, constant: 16),
            infoView.trailingAnchor.constraint(equalTo: db.trailingAnchor, constant: -16),
            infoView.bottomAnchor.constraint(lessThanOrEqualTo: db.bottomAnchor, constant: -14),

            mBar.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            mBar.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            mBar.bottomAnchor.constraint(equalTo: outBar.topAnchor),
            mBar.heightAnchor.constraint(equalToConstant: 40),

            outBar.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            outBar.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            outBar.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            outBar.heightAnchor.constraint(equalToConstant: 52),

            prgView.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            prgView.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            prgView.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            prgView.heightAnchor.constraint(equalToConstant: 52),
        ])

        mainWindow = win

        let click = NSClickGestureRecognizer(target: self, action: #selector(openExe(_:)))
        db.addGestureRecognizer(click)
    }

    // MARK: - Drop Hint View

    private func buildDropHintView() -> NSView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment   = .centerX
        stack.spacing     = 8

        let imgView = NSImageView()
        imgView.translatesAutoresizingMaskIntoConstraints = false
        if let sym = NSImage(systemSymbolName: "arrow.down.doc",
                             accessibilityDescription: nil) {
            imgView.image = sym.withSymbolConfiguration(
                .init(pointSize: 36, weight: .light))
        }
        imgView.contentTintColor = .tertiaryLabelColor
        NSLayoutConstraint.activate([
            imgView.widthAnchor.constraint(equalToConstant: 44),
            imgView.heightAnchor.constraint(equalToConstant: 44),
        ])

        let label = NSTextField(labelWithString:
            "Drop Mach-O executable here\nor click to open")
        label.alignment = .center
        label.textColor = .secondaryLabelColor
        label.font      = .systemFont(ofSize: 13)

        stack.addArrangedSubview(imgView)
        stack.addArrangedSubview(label)
        return stack
    }

    // MARK: - File Info View

    private func buildFileInfoView() -> NSView {
        let pathRow = NSStackView()
        pathRow.orientation = .horizontal
        pathRow.spacing     = 6

        let pathLbl = makeLabel("File:")
        pathLbl.setContentHuggingPriority(.required, for: .horizontal)

        let pathField = NSTextField(labelWithString: "")
        pathField.textColor      = .labelColor
        pathField.font           = .monospacedSystemFont(ofSize: 12, weight: .regular)
        pathField.lineBreakMode  = .byTruncatingMiddle
        pathField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        pathText = pathField

        pathRow.addArrangedSubview(pathLbl)
        pathRow.addArrangedSubview(pathField)
        return pathRow
    }

    // MARK: - Meta Bar (Type / Arch / Thin / Verify)

    private func buildMetaBar() -> NSView {
        let bar = NSView()

        let typeLbl = makeLabel("Type:")
        typeLbl.translatesAutoresizingMaskIntoConstraints = false
        typeLbl.setContentHuggingPriority(.required, for: .horizontal)
        bar.addSubview(typeLbl)

        let typeField = NSTextField(labelWithString: "")
        typeField.translatesAutoresizingMaskIntoConstraints = false
        typeField.textColor = .secondaryLabelColor
        typeField.font      = .systemFont(ofSize: 12)
        typeField.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        bar.addSubview(typeField)
        typeText = typeField

        let popup = NSPopUpButton(frame: .zero, pullsDown: false)
        popup.translatesAutoresizingMaskIntoConstraints = false
        popup.controlSize = .small
        popup.font        = .systemFont(ofSize: NSFont.systemFontSize(for: .small))
        popup.target      = self
        popup.action      = #selector(selectArch(_:))
        popup.isEnabled   = false
        bar.addSubview(popup)
        archPopup = popup

        let thinBtn   = makeSmallButton("Thin…",  action: #selector(thinFile(_:)))
        let verifyBtn = makeSmallButton("Verify", action: #selector(verifyNops(_:)))
        thinBtn.translatesAutoresizingMaskIntoConstraints   = false
        verifyBtn.translatesAutoresizingMaskIntoConstraints = false
        thinBtn.isEnabled   = false
        verifyBtn.isEnabled = false
        bar.addSubview(thinBtn)
        bar.addSubview(verifyBtn)
        thinButton   = thinBtn
        verifyButton = verifyBtn

        NSLayoutConstraint.activate([
            typeLbl.leadingAnchor.constraint(equalTo: bar.leadingAnchor, constant: 16),
            typeLbl.centerYAnchor.constraint(equalTo: bar.centerYAnchor, constant: 4),

            typeField.leadingAnchor.constraint(equalTo: typeLbl.trailingAnchor, constant: 6),
            typeField.centerYAnchor.constraint(equalTo: typeLbl.centerYAnchor),

            popup.leadingAnchor.constraint(equalTo: typeField.trailingAnchor, constant: 10),
            popup.centerYAnchor.constraint(equalTo: typeLbl.centerYAnchor),

            verifyBtn.trailingAnchor.constraint(equalTo: bar.trailingAnchor, constant: -16),
            verifyBtn.centerYAnchor.constraint(equalTo: typeLbl.centerYAnchor),

            thinBtn.trailingAnchor.constraint(equalTo: verifyBtn.leadingAnchor, constant: -8),
            thinBtn.centerYAnchor.constraint(equalTo: typeLbl.centerYAnchor),
        ])
        return bar
    }

    // MARK: - Output Bar

    private func buildOutputBar() -> NSView {
        let bar = NSView()

        let outLabel = makeLabel("Output:")
        outLabel.translatesAutoresizingMaskIntoConstraints = false
        bar.addSubview(outLabel)

        let outField = NSTextField()
        outField.translatesAutoresizingMaskIntoConstraints = false
        outField.placeholderString = "output.txt"
        outField.tag               = kOutputTextTag
        outField.delegate          = self
        outField.font              = .systemFont(ofSize: 13)
        outField.bezelStyle        = .roundedBezel
        bar.addSubview(outField)
        outputText = outField

        let saveBtn = NSButton(title: "Save", target: self,
                               action: #selector(attemptToProcessFile(_:)))
        saveBtn.translatesAutoresizingMaskIntoConstraints = false
        saveBtn.bezelStyle     = .rounded
        saveBtn.keyEquivalent  = "\r"
        saveBtn.isEnabled      = false
        bar.addSubview(saveBtn)
        saveButton = saveBtn

        NSLayoutConstraint.activate([
            outLabel.leadingAnchor.constraint(equalTo: bar.leadingAnchor, constant: 16),
            outLabel.centerYAnchor.constraint(equalTo: bar.centerYAnchor, constant: 4),

            outField.leadingAnchor.constraint(equalTo: outLabel.trailingAnchor, constant: 8),
            outField.centerYAnchor.constraint(equalTo: outLabel.centerYAnchor),
            outField.trailingAnchor.constraint(equalTo: saveBtn.leadingAnchor, constant: -10),

            saveBtn.trailingAnchor.constraint(equalTo: bar.trailingAnchor, constant: -16),
            saveBtn.centerYAnchor.constraint(equalTo: bar.centerYAnchor, constant: 4),
            saveBtn.widthAnchor.constraint(greaterThanOrEqualToConstant: 70),
        ])
        return bar
    }

    // MARK: - Progress View

    private func buildProgressView() -> NSView {
        let view = NSView()

        let label = NSTextField(labelWithString: "")
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textColor = .secondaryLabelColor
        label.font      = .systemFont(ofSize: 12)
        view.addSubview(label)
        progText = label

        let bar = NSProgressIndicator()
        bar.translatesAutoresizingMaskIntoConstraints = false
        bar.style           = .bar
        bar.isIndeterminate = true
        bar.controlSize     = .small
        bar.minValue        = 0
        bar.maxValue        = 100
        view.addSubview(bar)
        progBar = bar

        let cancelBtn = NSButton(title: "Cancel", target: self,
                                 action: #selector(cancel(_:)))
        cancelBtn.translatesAutoresizingMaskIntoConstraints = false
        cancelBtn.bezelStyle  = .rounded
        cancelBtn.controlSize = .small
        view.addSubview(cancelBtn)

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            label.topAnchor.constraint(equalTo: view.topAnchor, constant: 6),

            bar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            bar.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 4),
            bar.trailingAnchor.constraint(equalTo: cancelBtn.leadingAnchor, constant: -12),

            cancelBtn.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            cancelBtn.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: 6),
        ])
        return view
    }

    // MARK: - Preferences Window Builder

    private func buildPrefsWindow() {
        let tabVC = NSTabViewController()
        tabVC.tabStyle = .toolbar

        let genItem = NSTabViewItem(identifier: "general")
        genItem.label           = "General"
        genItem.image           = NSImage(systemSymbolName: "gearshape",
                                          accessibilityDescription: nil)
        genItem.viewController  = makeGeneralPrefsVC()
        tabVC.addTabViewItem(genItem)

        let outItem = NSTabViewItem(identifier: "output")
        outItem.label           = "Output"
        outItem.image           = NSImage(systemSymbolName: "doc.text",
                                          accessibilityDescription: nil)
        outItem.viewController  = makeOutputPrefsVC()
        tabVC.addTabViewItem(outItem)

        let win = NSWindow(contentViewController: tabVC)
        win.title              = "otx Preferences"
        win.styleMask            = [.titled, .closable]
        win.isReleasedWhenClosed = false
        win.isRestorable         = false
        prefsWindow = win
    }

    // MARK: - General Prefs VC

    private func makeGeneralPrefsVC() -> NSViewController {
        let vc   = NSViewController()
        vc.title = "General"
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 360, height: 280))

        let stack = prefStack()
        view.addSubview(stack)

        stack.addArrangedSubview(sectionLabel("Objective-C"))
        stack.addArrangedSubview(prefCheckbox("Show method return types",
                                              key: UserDefaultKey.showMethodReturnTypes))
        stack.addArrangedSubview(prefCheckbox("Show variable types",
                                              key: UserDefaultKey.showIvarTypes))
        stack.addArrangedSubview(prefCheckbox("Show verbose message sends",
                                              key: UserDefaultKey.verboseMsgSends))

        stack.addArrangedSubview(sectionLabel("Assembly"))
        stack.addArrangedSubview(prefCheckbox("Show local offsets",
                                              key: UserDefaultKey.showLocalOffsets))
        stack.addArrangedSubview(prefCheckbox("Show return statements",
                                              key: UserDefaultKey.showReturnStatements))
        stack.addArrangedSubview(prefCheckbox("Separate logical blocks",
                                              key: UserDefaultKey.separateLogicalBlocks))
        stack.addArrangedSubview(prefCheckbox("Show data sections",
                                              key: UserDefaultKey.showDataSection))
        stack.addArrangedSubview(checksumAlgorithmRow())
        stack.addArrangedSubview(prefCheckbox("Entab output",
                                              key: UserDefaultKey.entabOutput))

        stack.addArrangedSubview(sectionLabel("C++"))
        stack.addArrangedSubview(prefCheckbox("Demangle C++ names",
                                              key: UserDefaultKey.demangleCppNames))

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
        ])

        vc.view = view
        return vc
    }

    // MARK: - Output Prefs VC

    private func makeOutputPrefsVC() -> NSViewController {
        let vc   = NSViewController()
        vc.title = "Output"
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 360, height: 260))

        let stack = prefStack()
        view.addSubview(stack)

        // Filename section
        stack.addArrangedSubview(sectionLabel("Filename"))

        let useExeBtn    = NSButton(radioButtonWithTitle: "Use executable's name",
                                    target: self, action: #selector(syncOutputText(_:)))
        let useCustomBtn = NSButton(radioButtonWithTitle: "Use custom name:",
                                    target: self, action: #selector(syncOutputText(_:)))
        useExeBtn.bind(.value, to: NSUserDefaultsController.shared,
                       withKeyPath: "values.\(UserDefaultKey.useCustomName)",
                       options: [.valueTransformerName:
                           NSValueTransformerName.negateBooleanTransformerName])
        useCustomBtn.bind(.value, to: NSUserDefaultsController.shared,
                          withKeyPath: "values.\(UserDefaultKey.useCustomName)",
                          options: nil)
        stack.addArrangedSubview(useExeBtn)

        let nameRow = NSStackView()
        nameRow.orientation = .horizontal
        nameRow.spacing     = 6
        nameRow.addArrangedSubview(useCustomBtn)

        let nameField = NSTextField()
        nameField.tag               = kOutputFileBaseTag
        nameField.delegate          = self
        nameField.placeholderString = "output"
        nameField.widthAnchor.constraint(equalToConstant: 120).isActive = true
        nameField.bind(.value, to: NSUserDefaultsController.shared,
                       withKeyPath: "values.\(UserDefaultKey.outputFileName)",
                       options: [.continuouslyUpdatesValue: true,
                                 .nullPlaceholder: "output"])
        nameField.bind(.enabled, to: NSUserDefaultsController.shared,
                       withKeyPath: "values.\(UserDefaultKey.useCustomName)", options: nil)
        nameRow.addArrangedSubview(nameField)
        stack.addArrangedSubview(nameRow)

        let extRow = NSStackView()
        extRow.orientation = .horizontal
        extRow.spacing     = 6
        extRow.addArrangedSubview(makeLabel("Extension:"))

        let extField = NSTextField()
        extField.tag               = kOutputFileExtTag
        extField.delegate          = self
        extField.placeholderString = "txt"
        extField.widthAnchor.constraint(equalToConstant: 60).isActive = true
        extField.bind(.value, to: NSUserDefaultsController.shared,
                      withKeyPath: "values.\(UserDefaultKey.outputFileExtension)",
                      options: [.continuouslyUpdatesValue: true,
                                .nullPlaceholder: "txt"])
        extRow.addArrangedSubview(extField)
        stack.addArrangedSubview(extRow)

        // Location section
        stack.addArrangedSubview(sectionLabel("Location"))

        let sameBtn = NSButton(radioButtonWithTitle: "Same folder as executable",
                               target: nil, action: nil)
        let askBtn  = NSButton(radioButtonWithTitle: "Ask where to save",
                               target: nil, action: nil)
        sameBtn.bind(.value, to: NSUserDefaultsController.shared,
                     withKeyPath: "values.\(UserDefaultKey.askOutputDir)",
                     options: [.valueTransformerName:
                         NSValueTransformerName.negateBooleanTransformerName])
        askBtn.bind(.value, to: NSUserDefaultsController.shared,
                    withKeyPath: "values.\(UserDefaultKey.askOutputDir)", options: nil)
        stack.addArrangedSubview(sameBtn)
        stack.addArrangedSubview(askBtn)

        // After Saving section
        stack.addArrangedSubview(sectionLabel("After Saving"))

        let openRow = NSStackView()
        openRow.orientation = .horizontal
        openRow.spacing     = 6
        openRow.addArrangedSubview(prefCheckbox("Open file with:",
                                                key: UserDefaultKey.openOutputFile))
        let appField = NSTextField()
        appField.placeholderString = "TextEdit"
        appField.widthAnchor.constraint(equalToConstant: 100).isActive = true
        appField.bind(.value, to: NSUserDefaultsController.shared,
                      withKeyPath: "values.\(UserDefaultKey.outputApp)",
                      options: [.continuouslyUpdatesValue: true])
        appField.bind(.enabled, to: NSUserDefaultsController.shared,
                      withKeyPath: "values.\(UserDefaultKey.openOutputFile)", options: nil)
        openRow.addArrangedSubview(appField)
        stack.addArrangedSubview(openRow)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
        ])

        vc.view = view
        return vc
    }

    // MARK: - Prefs Helpers

    private func prefStack() -> NSStackView {
        let s = NSStackView()
        s.translatesAutoresizingMaskIntoConstraints = false
        s.orientation = .vertical
        s.alignment   = .leading
        s.spacing     = 8
        return s
    }

    private func sectionLabel(_ text: String) -> NSTextField {
        let f = NSTextField(labelWithString: text)
        f.font      = .boldSystemFont(ofSize: NSFont.systemFontSize)
        f.textColor = .labelColor
        return f
    }

    private func prefCheckbox(_ title: String, key: String) -> NSButton {
        let b = NSButton(checkboxWithTitle: title, target: nil, action: nil)
        b.bind(.value, to: NSUserDefaultsController.shared,
               withKeyPath: "values.\(key)", options: nil)
        return b
    }

    private func checksumAlgorithmRow() -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing     = 8

        let lbl = NSTextField(labelWithString: "Checksum:")
        lbl.textColor = .secondaryLabelColor
        lbl.font      = .systemFont(ofSize: NSFont.systemFontSize)
        lbl.setContentHuggingPriority(.required, for: .horizontal)

        let popup = NSPopUpButton(frame: .zero, pullsDown: false)
        popup.addItems(withTitles: ["None", "MD5", "SHA-1", "SHA-256"])
        let algoMap = ["none": 0, "md5": 1, "sha1": 2, "sha256": 3]
        let current = UserDefaults.standard.string(forKey: UserDefaultKey.checksumAlgorithm) ?? "sha256"
        popup.selectItem(at: algoMap[current] ?? 3)
        popup.target = self
        popup.action = #selector(checksumAlgorithmChanged(_:))

        row.addArrangedSubview(lbl)
        row.addArrangedSubview(popup)
        return row
    }

    // MARK: - Prefs Actions

    @objc private func checksumAlgorithmChanged(_ sender: NSPopUpButton) {
        let algos = ["none", "md5", "sha1", "sha256"]
        let idx = sender.indexOfSelectedItem
        let algo = (idx >= 0 && idx < algos.count) ? algos[idx] : "sha256"
        UserDefaults.standard.set(algo, forKey: UserDefaultKey.checksumAlgorithm)
    }

    @objc func showPrefs(_ sender: Any) {
        if !prefsWindow.isVisible { prefsWindow.center() }
        prefsWindow.makeKeyAndOrderFront(nil)
    }

    // MARK: - Main Window Actions

    @objc func showMainWindow(_ sender: Any) {
        mainWindow.makeKeyAndOrderFront(nil)
    }

    // MARK: - File Opening

    @objc func openExe(_ sender: Any) {
        let panel = NSOpenPanel()
        panel.treatsFilePackagesAsDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        newOFile(url, needsPath: true)
    }

    private func newPackageFile(_ packageURL: URL) {
        outputFilePath = packageURL.path
        guard let bundle = Bundle(path: packageURL.path),
              let exePath = bundle.executablePath else {
            fputs("otx: unable to get executable from package\n", stderr)
            return
        }
        newOFile(URL(fileURLWithPath: exePath), needsPath: false)
    }

    private func newOFile(_ url: URL, needsPath: Bool) {
        objectFile = url
        if needsPath { outputFilePath = url.path }

        let ws = NSWorkspace.shared
        if ws.isFilePackage(atPath: outputFilePath ?? "") {
            exeName = URL(fileURLWithPath: outputFilePath!)
                .deletingPathExtension().lastPathComponent
        } else {
            exeName = URL(fileURLWithPath: outputFilePath!).lastPathComponent
        }

        refreshMainWindow()
        syncOutputText(nil)
        syncSaveButton()
    }

    // MARK: - Arch Selection

    @objc func selectArch(_ sender: Any) {
        guard let item = archPopup.selectedItem else { return }
        let idx = item.tag
        guard idx < cpuIDs.count else { return }

        selectedArchCPUType    = cpuIDs[idx].type
        selectedArchCPUSubType = cpuIDs[idx].subtype
        outputFileLabel = archName(for: selectedArchCPUType).map { "_\($0)" }

        verifyButton.isEnabled = selectedArchCPUType == CPU_TYPE_X86_64
        syncOutputText(nil)
        syncSaveButton()
    }

    // MARK: - Processing

    @objc func attemptToProcessFile(_ sender: Any) {
        gCancel = false

        indeterminateTimer?.invalidate()
        indeterminateTimer = Timer.scheduledTimer(
            timeInterval: 1.0 / 30.0, target: self,
            selector: #selector(nudgeIndeterminateProgBar(_:)),
            userInfo: nil, repeats: true)

        guard objectFile != nil else { return }

        outputFileName = outputText.stringValue
        let savedPath  = outputFilePath

        if UserDefaults.standard.bool(forKey: UserDefaultKey.askOutputDir) {
            let panel = NSSavePanel()
            panel.nameFieldStringValue        = outputFileName ?? ""
            panel.treatsFilePackagesAsDirectories = true
            guard panel.runModal() == .OK, let url = panel.url else { return }
            outputFilePath = url.path
        } else {
            if let base = savedPath.map({
                URL(fileURLWithPath: $0).deletingLastPathComponent().path }) {
                outputFilePath = (base as NSString)
                    .appendingPathComponent(outputText.stringValue)
            }
        }

        let needsConfirm = !UserDefaults.standard.bool(forKey: UserDefaultKey.askOutputDir)
        if needsConfirm, let path = outputFilePath,
           FileManager.default.fileExists(atPath: path) {
            let name   = URL(fileURLWithPath: path).lastPathComponent
            let folder = URL(fileURLWithPath: path)
                .deletingLastPathComponent().lastPathComponent
            let alert = NSAlert()
            alert.addButton(withTitle: "Replace")
            alert.addButton(withTitle: "Cancel")
            alert.messageText     = "\"\(name)\" already exists. Do you want to replace it?"
            alert.informativeText =
                "A file with the same name already exists in \(folder)."
            alert.beginSheetModal(for: mainWindow) { [weak self] r in
                if r == .alertFirstButtonReturn { self?.processFile() }
            }
        } else {
            processFile()
        }
    }

    private func processFile() {
        reportProgress([PRIndeterminateKey: true, PRDescriptionKey: "Loading executable"])

        guard let oFile = objectFile, checkOtool(oFile.path) else {
            reportError("otool was not found.",
                        suggestion: "Please install Xcode command-line tools and try again.")
            return
        }
        isProcessing = true
        adjustInterfaceForMultiThread()
        showProgView()
    }

    @objc func continueProcessingFile() {
        let result = autoreleasepool(invoking: { () -> String in
            guard let procClass = processorClass() else { return "Unsupported architecture." }

            let d = UserDefaults.standard
            var opts = ProcOptions()
            opts.localOffsets          = ObjCBool(d.bool(forKey: UserDefaultKey.showLocalOffsets))
            opts.entabOutput           = ObjCBool(d.bool(forKey: UserDefaultKey.entabOutput))
            opts.dataSections          = ObjCBool(d.bool(forKey: UserDefaultKey.showDataSection))
            let algoMap: [String: UInt8] = ["md5": 1, "sha1": 2, "sha256": 3]
            opts.checksumAlgorithm     = algoMap[d.string(forKey: UserDefaultKey.checksumAlgorithm) ?? "sha256"] ?? 3
            opts.verboseMsgSends       = ObjCBool(d.bool(forKey: UserDefaultKey.verboseMsgSends))
            opts.separateLogicalBlocks = ObjCBool(d.bool(forKey: UserDefaultKey.separateLogicalBlocks))
            opts.demangleCppNames      = ObjCBool(d.bool(forKey: UserDefaultKey.demangleCppNames))
            opts.returnTypes           = ObjCBool(d.bool(forKey: UserDefaultKey.showMethodReturnTypes))
            opts.variableTypes         = ObjCBool(d.bool(forKey: UserDefaultKey.showIvarTypes))
            opts.returnStatements      = ObjCBool(d.bool(forKey: UserDefaultKey.showReturnStatements))

            guard let oFile = objectFile else { return "Unable to create processor." }

            if let p64 = procClass as? Exe64Processor.Type {
                guard let proc = p64.init(url: oFile, controller: self, options: &opts) else {
                    return "Unable to create processor."
                }
                if !proc.processExe(outputFilePath) {
                    return gCancel.boolValue ? kProcessSuccess
                        : "Unable to process \(oFile.path)."
                }
            }
            return kProcessSuccess
        })

        DispatchQueue.main.async { [weak self] in
            self?.processingThreadDidFinish(result)
        }
    }

    private func processingThreadDidFinish(_ result: String) {
        isProcessing = false
        indeterminateTimer?.invalidate()
        indeterminateTimer = nil

        let openFile = result == kProcessSuccess
            && !gCancel.boolValue
            && UserDefaults.standard.bool(forKey: UserDefaultKey.openOutputFile)

        hideProgView()

        if openFile, let path = outputFilePath {
            openOutputFile(atPath: path,
                           withApp: UserDefaults.standard.string(
                               forKey: UserDefaultKey.outputApp) ?? "")
        }

        if result != kProcessSuccess {
            reportError("Error processing file.", suggestion: result)
        }
    }

    // MARK: - Progress View Show / Hide

    private func showProgView() {
        outputBarView.isHidden = true
        progView.alphaValue    = 0
        progView.isHidden      = false
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.15
            progView.animator().alphaValue = 1
        } completionHandler: {
            Thread.detachNewThreadSelector(
                #selector(self.continueProcessingFile),
                toTarget: self, with: nil)
        }
    }

    private func hideProgView() {
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.15
            progView.animator().alphaValue = 0
        } completionHandler: {
            self.progView.isHidden      = true
            self.progView.alphaValue    = 1
            self.outputBarView.isHidden = false
            self.adjustInterfaceForSingleThread()
        }
    }

    // MARK: - UI State

    private func processorClass() -> AnyClass? {
        switch selectedArchCPUType {
        case CPU_TYPE_X86_64: return X8664Processor.self
        case CPU_TYPE_ARM64:  return ARM64Processor.self
        default:
            fputs("otx: unknown cpu type \(selectedArchCPUType)\n", stderr)
            return nil
        }
    }

    private func adjustInterfaceForMultiThread() {
        syncSaveButton()
        archPopup.isEnabled    = false
        thinButton.isEnabled   = false
        verifyButton.isEnabled = false
        outputText.isEnabled   = false
        mainWindow.standardWindowButton(.closeButton)?.isEnabled = false
    }

    @objc private func adjustInterfaceForSingleThread() {
        syncSaveButton()
        archPopup.isEnabled  = exeIsFat
        thinButton.isEnabled = exeIsFat
        verifyButton.isEnabled = selectedArchCPUType == CPU_TYPE_X86_64
        outputText.isEnabled   = true
        mainWindow.standardWindowButton(.closeButton)?.isEnabled = true
    }

    // MARK: - Thinning & Verification

    @objc func thinFile(_ sender: Any) {
        let archExt: String
        switch selectedArchCPUType {
        case CPU_TYPE_X86_64: archExt = "_x86_64"
        case CPU_TYPE_ARM64:  archExt = "_arm64"
        default: return
        }

        let thinOutputPath: String
        if UserDefaults.standard.bool(forKey: UserDefaultKey.askOutputDir) {
            let panel = NSSavePanel()
            panel.treatsFilePackagesAsDirectories = true
            guard panel.runModal() == .OK, let url = panel.url else { return }
            thinOutputPath = url.path
        } else {
            guard let base = outputFilePath.map({
                      URL(fileURLWithPath: $0).deletingLastPathComponent().path }),
                  let name = exeName else { return }
            thinOutputPath = (base as NSString).appendingPathComponent(name + archExt)
        }

        guard let archStr = archName(for: selectedArchCPUType),
              let oFile   = objectFile else { return }

        let task = Process()
        task.launchPath = "/usr/bin/lipo"
        task.arguments  = [oFile.path, "-output", thinOutputPath, "-thin", archStr]
        do {
            try task.run(); task.waitUntilExit()
            if task.terminationStatus != 0 {
                reportError("lipo failed.",
                            suggestion: "Please install Xcode command-line tools.")
            }
        } catch {
            reportError("lipo was not found.",
                        suggestion: "Please install Xcode command-line tools.")
        }
    }

    @objc func verifyNops(_ sender: Any) {
        guard selectedArchCPUType == CPU_TYPE_X86_64, let oFile = objectFile else { return }
        var opts = ProcOptions()
        let proc = X8664Processor(url: oFile, controller: self, options: &opts)!

        var foundList:  UnsafeMutablePointer<UnsafeMutablePointer<UInt8>?>? = nil
        var foundCount: UInt32 = 0

        let alert = NSAlert()
        if proc.verifyNops(&foundList, numFound: &foundCount) {
            let theNops  = NopList(list: foundList, count: foundCount)
            var nopsCopy = theNops
            alert.addButton(withTitle: "Fix")
            alert.addButton(withTitle: "Cancel")
            alert.messageText     = "Broken nops found."
            alert.informativeText =
                "otx found \(foundCount) broken nops. Would you like to save a copy with fixed nops?"
            alert.beginSheetModal(for: mainWindow) { [weak self] r in
                guard let self else { return }
                if r == .alertFirstButtonReturn {
                    if let fixed = proc.fixNops(&nopsCopy, toPath: self.outputFilePath) {
                        self.ignoreArch = true
                        self.newOFile(fixed, needsPath: true)
                    }
                }
                if let list = nopsCopy.list { free(list) }
            }
        } else {
            alert.addButton(withTitle: "OK")
            alert.messageText     = "No broken nops."
            alert.informativeText = "The executable is healthy."
            alert.beginSheetModal(for: mainWindow, completionHandler: nil)
        }
    }

    // MARK: - Main Window Refresh

    private func refreshMainWindow() {
        archPopup.removeAllItems()

        guard let oFile = objectFile,
              let fh    = try? FileHandle(forReadingFrom: oFile) else { return }
        defer { fh.closeFile() }

        let headerSize = max(MemoryLayout<mach_header>.size,
                             MemoryLayout<fat_header>.size)
            + MemoryLayout<fat_arch>.size * 10
        let fileData = fh.readData(ofLength: headerSize)
        guard fileData.count >= MemoryLayout<mach_header>.size else { return }

        let magic: UInt32 = fileData.withUnsafeBytes { $0.load(as: UInt32.self) }
        fileArchMagic = magic

        switch magic {
        case MH_MAGIC_64, MH_CIGAM_64, FAT_MAGIC, FAT_CIGAM:
            break
        default:
            return
        }

        fileIsValid = true
        pathText.stringValue = oFile.path

        let archMenu = archPopup.menu!
        selectedArchCPUType    = hostInfo.cpu_type
        selectedArchCPUSubType = 0

        var tempString: String = ""
        var menuItemTitleToSelect: String?
        var shouldEnableArch = false
        exeIsFat = false

        if magic == FAT_MAGIC || magic == FAT_CIGAM {
            fileData.withUnsafeBytes { ptr in
                var fh = ptr.load(as: fat_header.self)
                fh.magic     = UInt32(bigEndian: fh.magic)
                fh.nfat_arch = UInt32(bigEndian: fh.nfat_arch)

                let offset = MemoryLayout<fat_header>.size
                let count  = Int(fh.nfat_arch)
                for i in 0 ..< count {
                    let ao = offset + i * MemoryLayout<fat_arch>.size
                    guard ao + MemoryLayout<fat_arch>.size <= fileData.count else { break }
                    var fa = ptr.load(fromByteOffset: ao, as: fat_arch.self)
                    fa.cputype    = cpu_type_t(bigEndian: fa.cputype)
                    fa.cpusubtype = cpu_subtype_t(bigEndian: fa.cpusubtype)
                    if i < cpuIDs.count {
                        cpuIDs[i].type    = fa.cputype
                        cpuIDs[i].subtype = fa.cpusubtype
                    }
                    let name = archName(for: fa.cputype) ?? "unknown"
                    let item = NSMenuItem(title: name, action: nil, keyEquivalent: "")
                    item.tag = i
                    archMenu.addItem(item)
                }
            }

            let best = bestArchType(in: fileData, preferring: hostInfo.cpu_type)
            if let name = best.flatMap({ archName(for: $0) }) {
                outputFileLabel       = "_\(name)"
                menuItemTitleToSelect = name
            }

            verifyButton.isEnabled = hostInfo.cpu_type == CPU_TYPE_X86_64
            exeIsFat               = true
            shouldEnableArch        = true
            tempString              = "Fat"
        } else {
            fileData.withUnsafeBytes { ptr in
                var mh = ptr.load(as: mach_header.self)
                if mh.magic == MH_CIGAM || mh.magic == MH_CIGAM_64 {
                    mh.cputype    = cpu_type_t(bigEndian: mh.cputype)
                    mh.cpusubtype = cpu_subtype_t(bigEndian: mh.cpusubtype)
                }
                selectedArchCPUType    = mh.cputype
                selectedArchCPUSubType = mh.cpusubtype
                if let name = archName(for: mh.cputype) {
                    tempString            = name
                    menuItemTitleToSelect = name
                    let item = NSMenuItem(title: name, action: nil, keyEquivalent: "")
                    item.tag = 0
                    cpuIDs[0] = CPUID(type: mh.cputype, subtype: mh.cpusubtype)
                    archMenu.addItem(item)
                } else {
                    tempString = "Unknown"
                }
                verifyButton.isEnabled = mh.cputype == CPU_TYPE_X86_64
            }
        }

        typeText.stringValue = tempString

        if let title = menuItemTitleToSelect {
            archPopup.selectItem(withTitle: title)
            archPopup.synchronizeTitleAndSelectedItem()
        }
        thinButton.isEnabled = shouldEnableArch
        archPopup.isEnabled  = shouldEnableArch

        dropHintView.isHidden = true
        fileInfoView.isHidden = false
        metaBar.isHidden      = false

        if ignoreArch { ignoreArch = false }
    }

    private func syncSaveButton() {
        saveButton.isEnabled = fileIsValid && !isProcessing &&
                               !outputText.stringValue.isEmpty
    }

    @objc func syncOutputText(_ sender: Any?) {
        guard fileIsValid && !isProcessing else { return }
        let d   = UserDefaults.standard
        var name = d.bool(forKey: UserDefaultKey.useCustomName)
            ? (d.string(forKey: UserDefaultKey.outputFileName) ?? "error")
            : (exeName ?? "error")
        let ext = d.string(forKey: UserDefaultKey.outputFileExtension) ?? "txt"
        if let label = outputFileLabel { name += label }
        outputText.stringValue = (name as NSString).appendingPathExtension(ext) ?? name
    }

    // MARK: - Cancel

    @objc func cancel(_ sender: Any) {
        reportProgress([PRIndeterminateKey: true, PRDescriptionKey: "Cancelling"])
        gCancel = true
    }

    // MARK: - Timer

    @objc func nudgeIndeterminateProgBar(_ timer: Timer) {
        if progBar.isIndeterminate { progBar.startAnimation(self) }
    }

    // MARK: - ProgressReporter

    func reportProgress(_ inDict: [AnyHashable: Any]!) {
        guard let dict = inDict else { return }
        if let d = dict[PRDescriptionKey]   as? String    { progText.stringValue    = d }
        if let v = dict[PRValueKey]         as? NSNumber  { progBar.doubleValue     = v.doubleValue }
        if let i = dict[PRIndeterminateKey] as? NSNumber  { progBar.isIndeterminate = i.boolValue }

        let ping = NSEvent.otherEvent(with: .applicationDefined, location: .zero,
                                      modifierFlags: [], timestamp: 0, windowNumber: 0,
                                      context: nil, subtype: 0, data1: 0, data2: 0)!
        NSApplication.shared.postEvent(ping, atStart: false)
    }

    // MARK: - ErrorReporter

    func reportError(_ inMessageText: String!, suggestion inInformativeText: String!) {
        let alert = NSAlert()
        alert.addButton(withTitle: "OK")
        alert.messageText     = inMessageText ?? ""
        alert.informativeText = inInformativeText ?? ""
        alert.beginSheetModal(for: mainWindow, completionHandler: nil)
    }

    // MARK: - DropBoxDelegate

    func dropBox(_ dropBox: DropBox, dragDidEnter sender: NSDraggingInfo) -> NSDragOperation {
        guard dropBox === self.dropBox && !isProcessing else { return [] }

        let pb = sender.draggingPasteboard
        guard let urls = pb.readObjects(forClasses: [NSURL.self],
                                        options: [.urlReadingFileURLsOnly: true]) as? [URL],
              urls.count == 1 else { return [] }

        let url = urls[0]
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) else {
            return []
        }

        // For app bundles, verify there is an executable — but do NOT open the
        // file here.  File I/O on the main thread inside draggingEntered stalls
        // the drag IPC state machine and causes reentrant-message warnings.
        // The Mach-O magic check is deferred to performDragOperation.
        if isDir.boolValue {
            guard NSWorkspace.shared.isFilePackage(atPath: url.path),
                  Bundle(path: url.path)?.executablePath != nil
            else { return [] }
        }

        return sender.draggingSourceOperationMask.contains(.link) ? .link : []
    }

    func dropBox(_ dropBox: DropBox, didReceiveItem sender: NSDraggingInfo) -> Bool {
        guard dropBox === self.dropBox && !isProcessing else { return false }
        let pb = sender.draggingPasteboard
        guard let urls = pb.readObjects(forClasses: [NSURL.self],
                                        options: [.urlReadingFileURLsOnly: true]) as? [URL],
              let url  = urls.first else { return false }

        if NSWorkspace.shared.isFilePackage(atPath: url.path) {
            newPackageFile(url)
        } else {
            newOFile(url, needsPath: true)
        }
        return true
    }

    // MARK: - NSControl / NSTextField Delegate

    func controlTextDidChange(_ notification: Notification) {
        guard let field = notification.object as? NSControl else { return }
        switch field.tag {
        case kOutputTextTag:                        syncSaveButton()
        case kOutputFileBaseTag, kOutputFileExtTag: syncOutputText(nil)
        default: break
        }
    }

    // MARK: - NSMenu Validation

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector(attemptToProcessFile(_:)) {
            let ask = UserDefaults.standard.bool(forKey: UserDefaultKey.askOutputDir)
            menuItem.title = ask ? "Save…" : "Save"
            return fileIsValid
        }
        return true
    }

    // MARK: - NSWindow Delegate

    func windowDidResize(_ notification: Notification) {
        if (notification.object as? NSWindow) == mainWindow { mainWindow.display() }
    }

    // MARK: - Arch Helpers

    private func archName(for cpuType: cpu_type_t) -> String? {
        switch cpuType {
        case CPU_TYPE_X86_64: return "x86_64"
        case CPU_TYPE_ARM64:  return "arm64"
        default:              return nil
        }
    }

    private func bestArchType(in fileData: Data,
                              preferring hostType: cpu_type_t) -> cpu_type_t? {
        fileData.withUnsafeBytes { ptr -> cpu_type_t? in
            var fh = ptr.load(as: fat_header.self)
            fh.nfat_arch = UInt32(bigEndian: fh.nfat_arch)
            let base  = MemoryLayout<fat_header>.size
            var first: cpu_type_t?
            for i in 0 ..< Int(fh.nfat_arch) {
                let off = base + i * MemoryLayout<fat_arch>.size
                guard off + MemoryLayout<fat_arch>.size <= fileData.count else { break }
                var fa = ptr.load(fromByteOffset: off, as: fat_arch.self)
                fa.cputype = cpu_type_t(bigEndian: fa.cputype)
                if first == nil { first = fa.cputype }
                if fa.cputype == hostType { return fa.cputype }
            }
            return first
        }
    }

    // MARK: - Open Output File

    private func openOutputFile(atPath path: String, withApp appName: String) {
        let url = URL(fileURLWithPath: path)
        if appName.isEmpty { NSWorkspace.shared.open(url); return }
        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: appName) {
            NSWorkspace.shared.open([url], withApplicationAt: appURL,
                                    configuration: NSWorkspace.OpenConfiguration())
        } else {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - View Helpers

    private func makeLabel(_ text: String) -> NSTextField {
        let f = NSTextField(labelWithString: text)
        f.textColor = .secondaryLabelColor
        f.font      = .systemFont(ofSize: NSFont.systemFontSize)
        return f
    }

    private func makeSmallButton(_ title: String, action: Selector) -> NSButton {
        let b = NSButton(title: title, target: self, action: action)
        b.bezelStyle  = .rounded
        b.controlSize = .small
        b.font        = .systemFont(ofSize: NSFont.systemFontSize(for: .small))
        return b
    }
}
