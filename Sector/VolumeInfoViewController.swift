//
//  VolumeInfoViewController.swift
//  Sector
//
//  Created by David Kopec on 2/4/26.
//

import Cocoa
import HFSKit

class VolumeInfoViewController: NSViewController {
    
    final var volume: HFSVolume?
    
    @IBOutlet weak var volumeNameLabel: NSTextField!

    func updateUI() {
        do {
            if let volumeInfo = try volume?.volumeInfo() {
                volumeNameLabel.stringValue = volumeInfo.name
            } else {
                presentErrorAlert(message: "Couldn't get volume reference to get info.")
            }
        } catch {
            print(error)
            presentError(error)
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
}
