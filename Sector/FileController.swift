//
//  FileController.swift
//  Sector
//
//  Created by David Kopec on 2/1/26.
//

import Cocoa
import HFSKit

class FileController {
    private var volumeWindowControllers: [VolumeWindowController] = []
    
    /// Updates the canvas with a given image.
    private func handleVolume(_ volume: HFSVolume) {
        
        let vwc: VolumeWindowController = NSStoryboard(name: "Main", bundle: nil).instantiateController(withIdentifier: "volumeWindowController") as! VolumeWindowController
        vwc.volume = volume
        vwc.configureUI()
        vwc.showWindow(self)
        
        if let window = vwc.window {
                
            // be ready to release memory when done
            NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: window, queue: nil, using: { [unowned self, unowned vwc] (n:Notification) -> Void in
                    
                    self.volumeWindowControllers.removeAll { $0 === vwc }
                    vwc.contentViewController = nil // releases some memory
                        NotificationCenter.default.removeObserver(self, name: NSWindow.willCloseNotification, object: window)
                            //print("count after close: \(self.detailWindowControllers.count)")
                    
                    //print(ditheringWindowControllers.count)
                    }
                )
                
            volumeWindowControllers.append(vwc)
        }
    }

    /// Updates the canvas with a given image file.
    public func handleFile(at url: URL) {
        do {
            let volume = try HFSVolume(path: url, writable: true)
            OperationQueue.main.addOperation {
                self.handleVolume(volume)
            }
        } catch let error {
            print(error)
            presentErrorAlert(for: error)
        }
    }
    
}


