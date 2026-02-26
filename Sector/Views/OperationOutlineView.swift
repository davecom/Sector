//
//  OperationOutlineView.swift
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

public protocol OutlineActionDelegate: AnyObject {
    func outlineDeleteBackward()
}

public class OperationOutlineView: NSOutlineView {
    weak var actionDelegate: OutlineActionDelegate?
    
    public override func keyDown(with event: NSEvent) {
        if event.keyCode == 51 || event.keyCode == 117 {
            actionDelegate?.outlineDeleteBackward()
            return
        }
        super.keyDown(with: event)
    }
    
    public override func menu(for event: NSEvent) -> NSMenu? {
        // Convert the click location into our coordinate system
        let pointInView = convert(event.locationInWindow, from: nil)
        let row = self.row(at: pointInView)

        // If the click wasn't on a valid row, no context menu
        guard row >= 0 else {
            return nil
        }

        // Sync selection to the row that was right-clicked
        if !isRowSelected(row) {
            selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
            // This will fire outlineViewSelectionDidChange in your VC,
            // which should update `selectedNode`, so your
            // validateUserInterfaceItem(_:) logic works.
        }

        // Use whatever menu is configured (IB “Menu” outlet or programmatically)
        // and let the responder chain handle validation via your VC.
        return super.menu(for: event)
    }
}
