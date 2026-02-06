//
//  DropView.swift
//  Sector
//
//  Created by David Kopec on 2/1/26.
//

import Cocoa

/// Delegate for handling dragging events.
@objc protocol DropViewDelegate: AnyObject {
    func draggingEntered(forDropView dropView: DropView, sender: NSDraggingInfo) -> NSDragOperation
    func performDragOperation(forDropView dropView: DropView, sender: NSDraggingInfo) -> Bool
}

class DropView: NSView {
    
    @IBOutlet weak var dropBox: NSBox!
    @IBOutlet weak var progressIndicator: NSProgressIndicator!
    
    @IBOutlet weak var dropImageLabel: NSTextField!
    
    @IBOutlet weak var delegate: DropViewDelegate?
    
    var isHighlighted: Bool = false{
        didSet {
            dropBox.borderColor = isHighlighted ? NSColor.green : NSColor.tertiaryLabelColor
            dropBox.borderWidth = isHighlighted ? 5.0 : 1.0
            dropImageLabel.textColor = isHighlighted ? NSColor.green : NSColor.labelColor
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        // Drawing code here.
    }
    
    // MARK: - NSDraggingDestination
    
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        var result: NSDragOperation = []
        if let delegate = delegate {
            result = delegate.draggingEntered(forDropView: self, sender: sender)
            isHighlighted = (result != [])
        }
        return result
    }
        
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        return delegate?.performDragOperation(forDropView: self, sender: sender) ?? true
    }
    
    override func draggingExited(_ sender: NSDraggingInfo?) {
        isHighlighted = false
    }
    
    override func draggingEnded(_ sender: NSDraggingInfo) {
        isHighlighted = false
    }
    
    
}
