//
//  DropView.swift
//  Sector - A HFS disk image editor
//  Copyright (C) 2026 Oak Snow Consulting LLC
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <https://www.gnu.org/licenses/>.

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
