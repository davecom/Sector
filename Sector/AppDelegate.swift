//
//  AppDelegate.swift
//  Sector
//
//  Created by David Kopec on 2/1/26.
//

import Cocoa
import UniformTypeIdentifiers

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    static let fileController: FileController = FileController()
    

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
        
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }
    
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            AppDelegate.fileController.handleFile(at: url)
        }
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
    
    @IBAction func openDocument(_ sender: AnyObject) {
        let op: NSOpenPanel = NSOpenPanel()
        op.canChooseFiles = true
        op.canChooseDirectories = false
        op.allowsMultipleSelection = true
        op.begin { (mr: NSApplication.ModalResponse) in
            if mr == NSApplication.ModalResponse.OK {
                for url in op.urls {
                    AppDelegate.fileController.handleFile(at: url)
                }
            }
        }
    }
    
    // Create an email to support
    @IBAction func emailSupport(sender: NSMenuItem) {
        let emailURL: URL = URL(string: "mailto:retrodither@oaksnow.com")!
        NSWorkspace.shared.open(emailURL)
    }
    
    // Start a Tweet to me
    @IBAction func tweetSupport(sender: NSMenuItem) {
        let tweetURL: URL = URL(string: "https://twitter.com/intent/tweet?text=%40davekopec")!
        NSWorkspace.shared.open(tweetURL)
    }


}

