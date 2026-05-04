/*
    DropBox.swift

    A subclass of NSView that accepts file drag-and-drop, drawn as a
    modern rounded-rect drop zone with a focus-ring highlight.

    This file is in the public domain.
*/

import AppKit

// MARK: - Delegate Protocol

@objc protocol DropBoxDelegate: AnyObject {
    func dropBox(_ dropBox: DropBox, dragDidEnter sender: NSDraggingInfo) -> NSDragOperation
    @objc optional func dropBox(_ dropBox: DropBox, dragDidExit sender: NSDraggingInfo)
    func dropBox(_ dropBox: DropBox, didReceiveItem sender: NSDraggingInfo) -> Bool
}

// MARK: - DropBox

@objc class DropBox: NSView {

    @IBOutlet weak var delegate: (NSObject & DropBoxDelegate)?

    var cornerRadius: CGFloat = 10
    var borderColor: NSColor  = .separatorColor
    var fillColor:   NSColor  = .clear

    private var showHilite = false

    // MARK: - Init

    override init(frame: NSRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        registerForDraggedTypes([.fileURL])
        wantsLayer = true
    }

    // MARK: - NSDraggingDestination

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard let del = delegate else { return [] }
        let op = del.dropBox(self, dragDidEnter: sender)
        if !op.isEmpty {
            showHilite = true
            needsDisplay = true
        }
        return op
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        showHilite = false
        needsDisplay = true
        if let sender { delegate?.dropBox?(self, dragDidExit: sender) }
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        showHilite = false
        needsDisplay = true
        return delegate?.dropBox(self, didReceiveItem: sender) ?? false
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        let path = NSBezierPath(roundedRect: bounds, xRadius: cornerRadius, yRadius: cornerRadius)

        fillColor.setFill()
        path.fill()

        if showHilite {
            NSColor.keyboardFocusIndicatorColor.withAlphaComponent(0.8).setStroke()
            path.lineWidth = 3
        } else {
            borderColor.setStroke()
            path.lineWidth = 1.5
        }
        path.stroke()
    }
}
