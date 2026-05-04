/*
    CLIController.swift

    Command-line interface controller for the otx CLI target.

    This file is in the public domain.
*/

import AppKit
import Darwin.Mach

// MARK: - Default ProcOptions Values

private let kShowLocalOffsets:           ObjCBool = true
private let kShowCode:                   ObjCBool = true
private let kDontEntabOutput:            ObjCBool = false
private let kDontShowDataSections:       ObjCBool = false
private let kDefaultChecksumAlgorithm:   UInt8 = UInt8(CHECKSUM_SHA256)
private let kShowVerboseMsgSends:        ObjCBool = true
private let kDontSeparateLogicalBlocks:  ObjCBool = false
private let kDemangleCppNames:           ObjCBool = true
private let kShowMethodReturnTypes:      ObjCBool = true
private let kShowVariableTypes:          ObjCBool = true
private let kShowReturnStatements:       ObjCBool = true

// HOST_BASIC_INFO_COUNT is a C macro not automatically bridged to Swift
private let kHostBasicInfoCount = mach_msg_type_number_t(
    MemoryLayout<host_basic_info_data_t>.size / MemoryLayout<integer_t>.size)

// MARK: - CLIController

@objc class CLIController: NSObject, ProgressReporter, ErrorReporter {

    private var oFile:         URL?
    private var archSelector:  cpu_type_t = 0
    private var fileArchMagic: UInt32     = 0
    private var exeName:       String?
    private var verify         = false
    private var showProgress   = false
    private var opts           = ProcOptions()

    // MARK: - Initialisation

    convenience init?(args argv: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>!,
                      count argc: Int32) {
        guard argc >= 2 else {
            CLIController.printUsage()
            return nil
        }
        self.init()

        // Detect host CPU type.
        var hostInfo = host_basic_info_data_t()
        var count    = kHostBasicInfoCount
        withUnsafeMutablePointer(to: &hostInfo) { ptr in
            _ = ptr.withMemoryRebound(to: integer_t.self, capacity: Int(kHostBasicInfoCount)) {
                host_info(mach_host_self(), HOST_BASIC_INFO, $0, &count)
            }
        }
        archSelector = hostInfo.cpu_type

        // Set default options.
        opts.localOffsets          = kShowLocalOffsets
        opts.showCode              = kShowCode
        opts.entabOutput           = kDontEntabOutput
        opts.dataSections          = kDontShowDataSections
        opts.checksumAlgorithm     = kDefaultChecksumAlgorithm
        opts.verboseMsgSends       = kShowVerboseMsgSends
        opts.separateLogicalBlocks = kDontSeparateLogicalBlocks
        opts.demangleCppNames      = kDemangleCppNames
        opts.returnTypes           = kShowMethodReturnTypes
        opts.variableTypes         = kShowVariableTypes
        opts.returnStatements      = kShowReturnStatements

        // Parse arguments.
        var filePath: String?

        var i = 1
        while i < Int(argc) {
            let arg = String(cString: argv[i]!)
            if arg.hasPrefix("-") {
                if arg == "-" {
                    CLIController.printUsage()
                    return nil
                }

                if arg == "-arch" {
                    i += 1
                    guard i < Int(argc) else {
                        fputs("otx: -arch requires an argument\n", stderr)
                        return nil
                    }
                    let archStr = String(cString: argv[i]!)
                    switch archStr {
                    case "x86_64":        archSelector = CPU_TYPE_X86_64
                    case "arm64":         archSelector = CPU_TYPE_ARM64
                    default:
                        fputs("otx: unknown architecture: \"\(archStr)\"\n", stderr)
                        CLIController.printUsage()
                        return nil
                    }
                } else if arg == "-debug" {
                    opts.debugMode = true
                } else {
                    // Single-character flags
                    for ch in arg.dropFirst() {
                        switch ch {
                        case "l": opts.localOffsets          = ObjCBool(!opts.localOffsets.boolValue)
                        case "C": opts.showCode              = ObjCBool(!opts.showCode.boolValue)
                        case "e": opts.entabOutput           = ObjCBool(!opts.entabOutput.boolValue)
                        case "d": opts.dataSections          = ObjCBool(!opts.dataSections.boolValue)
                        case "c": opts.checksumAlgorithm     = opts.checksumAlgorithm != 0 ? 0 : kDefaultChecksumAlgorithm
                        case "m": opts.verboseMsgSends       = ObjCBool(!opts.verboseMsgSends.boolValue)
                        case "b": opts.separateLogicalBlocks = ObjCBool(!opts.separateLogicalBlocks.boolValue)
                        case "n": opts.demangleCppNames      = ObjCBool(!opts.demangleCppNames.boolValue)
                        case "r": opts.returnTypes           = ObjCBool(!opts.returnTypes.boolValue)
                        case "R": opts.returnStatements      = ObjCBool(!opts.returnStatements.boolValue)
                        case "v": opts.variableTypes         = ObjCBool(!opts.variableTypes.boolValue)
                        case "p": showProgress               = true
                        case "o": verify                     = true
                        default:
                            fputs("otx: unknown argument: '\(ch)'\n", stderr)
                            CLIController.printUsage()
                            return nil
                        }
                    }
                }
            } else {
                filePath = arg
            }
            i += 1
        }

        guard let path = filePath else {
            fputs("You must specify an executable file to process.\n", stderr)
            return nil
        }

        guard FileManager.default.fileExists(atPath: path) else {
            fputs("otx: No file found at \(path).\n", stderr)
            return nil
        }

        let url = URL(fileURLWithPath: path)
        if NSWorkspace.shared.isFilePackage(atPath: path) {
            newPackageFile(url)
        } else {
            newOFile(url, needsPath: true)
        }

        guard oFile != nil else {
            fputs("otx: Invalid file.\n", stderr)
            return nil
        }

        // Check for Mach-O magic and detect architecture.
        guard let fh = try? FileHandle(forReadingFrom: oFile!) else {
            fputs("otx: Unable to open \(url.lastPathComponent).\n", stderr)
            return nil
        }
        // Read enough bytes for magic + cputype (needed to distinguish x86_64 from arm64).
        let headerSize = MemoryLayout<UInt32>.size * 2
        let data = fh.readData(ofLength: headerSize)
        fh.closeFile()
        guard data.count >= MemoryLayout<UInt32>.size else {
            fputs("otx: Unable to read from \(url.lastPathComponent).\n", stderr)
            return nil
        }

        let magic: UInt32 = data.withUnsafeBytes { $0.load(as: UInt32.self) }
        fileArchMagic = magic

        switch magic {
        case MH_MAGIC_64:
            // Read cputype to distinguish x86_64 from arm64.
            if data.count >= headerSize {
                let cpuType: cpu_type_t = data.withUnsafeBytes {
                    $0.load(fromByteOffset: MemoryLayout<UInt32>.size, as: cpu_type_t.self)
                }
                archSelector = cpuType
            } else {
                archSelector = CPU_TYPE_X86_64
            }
        case FAT_MAGIC, FAT_CIGAM:
            break  // leave archSelector as detected from host
        default:
            fputs("otx: \(url.lastPathComponent) is not a supported Mach-O file.\n", stderr)
            return nil
        }
    }

    // MARK: - File Helpers

    private func newPackageFile(_ url: URL) {
        guard let bundle = Bundle(path: url.path),
              let exePath = bundle.executablePath else {
            fputs("otx: unable to get executable from bundle: \(url.path)\n", stderr)
            return
        }
        newOFile(URL(fileURLWithPath: exePath), needsPath: false)
    }

    private func newOFile(_ url: URL, needsPath: Bool) {
        oFile    = url
        exeName  = url.lastPathComponent
    }

    // MARK: - Processing

    @objc func processFile() {
        guard let oFile = oFile else {
            fputs("otx: tried to process nil object file.\n", stderr)
            return
        }

        if verify { verifyNops(); return }

        guard checkOtool(oFile.path) else {
            fputs("otx: otool was not found. Please install Xcode command-line tools.\n", stderr)
            return
        }

        guard let procClass = processorClass() else { return }

        let progDict: [AnyHashable: Any] = [
            PRIndeterminateKey: true,
            PRDescriptionKey: "Loading executable",
        ]
        reportProgress(progDict)

        if let p64 = procClass as? Exe64Processor.Type {
            guard let proc = p64.init(url: oFile, controller: self, options: &opts) else {
                fputs("otx: unable to create processor.\n", stderr)
                return
            }
            guard proc.processExe(nil) else {
                fputs("otx: possible permission error\n", stderr)
                return
            }
            if opts.debugMode.boolValue { proc.printSummary() }
        }
    }

    private func verifyNops() {
        guard archSelector == CPU_TYPE_X86_64, let oFile = oFile else {
            print("Deobfuscation is only available for x86_64 binaries.")
            return
        }

        var emptyOpts = ProcOptions()
        guard let proc = X8664Processor(url: oFile, controller: self, options: &emptyOpts) else {
            fputs("otx: unable to create processor.\n", stderr)
            return
        }

        var foundList: UnsafeMutablePointer<UnsafeMutablePointer<UInt8>?>? = nil
        var foundCount: UInt32 = 0

        if proc.verifyNops(&foundList, numFound: &foundCount) {
            print("otx found \(foundCount) broken nop's. Would you like to save a copy with fixed nop's? (y/n)")
            if let line = readLine(), line.lowercased().hasPrefix("y") {
                var theNops = NopList(list: foundList, count: foundCount)
                let fixedPath = oFile.path + "_fixed"
                if proc.fixNops(&theNops, toPath: fixedPath) == nil {
                    fputs("otx: unable to fix nops\n", stderr)
                }
                if let list = theNops.list { free(list) }
            }
        } else {
            print("The executable is healthy.")
        }
    }

    private func processorClass() -> AnyClass? {
        switch archSelector {
        case CPU_TYPE_X86_64:    return X8664Processor.self
        case CPU_TYPE_ARM64:     return ARM64Processor.self
        default:
            fputs("otx: unsupported architecture: \(archSelector)\n", stderr)
            return nil
        }
    }

    // MARK: - Usage

    private static func printUsage() {
        fputs(
            "Usage: otx [-bcdelmnoprv] [-arch <arch type>] <object file>\n"
            + "\t-b             separate logical blocks\n"
            + "\t-c             don't show sha256 checksum\n"
            + "\t-C             don't show binary code\n"
            + "\t-d             show data sections\n"
            + "\t-e             don't entab output\n"
            + "\t-l             don't show local offsets\n"
            + "\t-m             don't show verbose objc_msgSend\n"
            + "\t-n             don't demangle C++ symbol names\n"
            + "\t-o             only check the executable for obfuscation\n"
            + "\t-p             display progress\n"
            + "\t-r             don't show Obj-C method return types\n"
            + "\t-v             don't show Obj-C member variable types\n"
            + "\t-arch archVal  specify architecture in a universal binary\n"
            + "\t               allowed values: x86_64, arm64\n",
            stderr)
    }

    // MARK: - ProgressReporter

    func reportProgress(_ inDict: [AnyHashable: Any]!) {
        guard showProgress, let dict = inDict else { return }

        if (dict[PRNewLineKey] as? NSNumber)?.boolValue == true {
            fputs("\n", stderr)
        }
        if let desc = dict[PRDescriptionKey] as? String {
            fputs(desc, stderr)
        }
        if dict[PRValueKey] != nil {
            fputs(".", stderr)
        }
        if (dict[PRCompleteKey] as? NSNumber)?.boolValue == true {
            fputs("\n", stderr)
        }
    }

    // MARK: - ErrorReporter

    func reportError(_ inMessageText: String!, suggestion inInformativeText: String!) {
        fputs("otx: \(inMessageText ?? "")\n     \(inInformativeText ?? "")\n", stderr)
    }
}
