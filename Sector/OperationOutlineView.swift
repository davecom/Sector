//
//  OperationOutlineView.swift
//  Sector
//
//  Created by David Kopec on 2/7/26.
//

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
}
