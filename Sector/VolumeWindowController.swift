//
//  VolumeWindowController.swift
//  Sector
//
//  Created by David Kopec on 2/4/26.
//

import Cocoa
import HFSKit

class VolumeWindowController: NSWindowController {
    
    final var volume: HFSVolume?
    
    func configureUI() {
        if let splitViewcontroller = self.contentViewController as? NSSplitViewController {
            if let volumeInfoViewController = splitViewcontroller.splitViewItems[0].viewController as? VolumeInfoViewController {
                volumeInfoViewController.volume = volume
                volumeInfoViewController.updateUI()
            }
            if let volumeDataViewController = splitViewcontroller.splitViewItems[1].viewController as? VolumeDataViewController {
                volumeDataViewController.volume = volume
                volumeDataViewController.updateUI()
            }
        }
    }

    override func windowDidLoad() {
        super.windowDidLoad()
        
        self.window?.delegate = self
    
        // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
        
    }
    
    
}

extension VolumeWindowController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        self.volume?.close()
    }
}
