//
//  ViewController.swift
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
import StoreKit


class MainViewController: NSViewController, DropViewDelegate {
    
    final let LAUNCH_COUNT_KEY = "SectorLaunchCount"
    final let LAST_REVIEWED_KEY = "SectorLastReviewedVersion"

    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        view.registerForDraggedTypes(NSFilePromiseReceiver.readableDraggedTypes.map { NSPasteboard.PasteboardType($0) })
        view.registerForDraggedTypes([NSPasteboard.PasteboardType.fileURL])
        
        maybeAskForReview()
    }
    
    private func maybeAskForReview() {
        // ask for review
        var count = UserDefaults.standard.integer(forKey: LAUNCH_COUNT_KEY)
        count += 1
        UserDefaults.standard.set(count, forKey: LAUNCH_COUNT_KEY)
        // Get the current bundle version for the app
        let infoDictionaryKey = kCFBundleVersionKey as String
        guard let currentVersion = Bundle.main.object(forInfoDictionaryKey: infoDictionaryKey) as? String
            else { fatalError("Expected to find a bundle version in the info dictionary") }

        let lastVersionPromptedForReview = UserDefaults.standard.string(forKey: LAST_REVIEWED_KEY)

        // Has the process been completed several times and the user has not already been prompted for this version?
        if (count % 10) == 0 && currentVersion != lastVersionPromptedForReview {
            let twoSecondsFromNow = DispatchTime.now() + 2.0
            DispatchQueue.main.asyncAfter(deadline: twoSecondsFromNow) {
                if #available(macOS 15.0, *) {
                    AppStore.requestReview(in: self)
                        UserDefaults.standard.set(currentVersion, forKey: self.LAST_REVIEWED_KEY)
                    
                } else { // for older macOS
                    SKStoreReviewController.requestReview()
                    UserDefaults.standard.set(currentVersion, forKey: self.LAST_REVIEWED_KEY)
                }
                    
            }
        }
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }
    
    /// Directory URL used for accepting file promises.
    private lazy var destinationURL: URL = {
        let destinationURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("Drops")
        try? FileManager.default.createDirectory(at: destinationURL, withIntermediateDirectories: true, attributes: nil)
        return destinationURL
    }()
    
    /// Queue used for reading and writing file promises.
    private lazy var workQueue: OperationQueue = {
        let providerQueue = OperationQueue()
        providerQueue.qualityOfService = .userInitiated
        return providerQueue
    }()
    
    
    
    /// Displays an error.
    private func handleError(_ error: Error) {
        OperationQueue.main.addOperation {
            if let window = self.view.window {
                self.presentError(error, modalFor: window, delegate: nil, didPresent: nil, contextInfo: nil)
            } else {
                self.presentError(error)
            }
            //self.imageCanvas.isLoading = false
        }
    }
    
    
    // MARK: - DropViewDelegate

    func draggingEntered(forDropView dropView: DropView, sender: NSDraggingInfo) -> NSDragOperation {
        return sender.draggingSourceOperationMask.intersection([.copy])
    }
    
    func performDragOperation(forDropView dropView: DropView, sender: NSDraggingInfo) -> Bool {
        let supportedClasses = [
            NSFilePromiseReceiver.self,
            NSURL.self
        ]

        let searchOptions: [NSPasteboard.ReadingOptionKey: Any] = [
            .urlReadingFileURLsOnly: true
        ]
        /// - Tag: HandleFilePromises
        sender.enumerateDraggingItems(options: [], for: nil, classes: supportedClasses, searchOptions: searchOptions) { (draggingItem, _, _) in
            switch draggingItem.item {
            case let filePromiseReceiver as NSFilePromiseReceiver:
                filePromiseReceiver.receivePromisedFiles(atDestination: self.destinationURL, options: [:],
                                                         operationQueue: self.workQueue) { (fileURL, error) in
                    if let error = error {
                        self.handleError(error)
                    } else {
                        AppDelegate.fileController.handleFile(at: fileURL)
                    }
                }
            case let fileURL as URL:
                AppDelegate.fileController.handleFile(at: fileURL)
            default: break
            }
        }
        
        return true
    }
    
    


}

