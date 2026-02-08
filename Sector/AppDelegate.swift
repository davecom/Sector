//
//  AppDelegate.swift
//  Sector
//
//  Created by David Kopec on 2/1/26.
//

import Cocoa
import UniformTypeIdentifiers
import HFSKit

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    static let fileController: FileController = FileController()
    private let disclaimerAcknowledgedKey = "SectorDisclaimerAcknowledgedV1"
    private var helpWindowController: HelpWindowController?
    private var helpWindowCloseObserver: NSObjectProtocol?
    

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        HFSKit.HFSKitSettings.verboseLoggingEnabled = false
        installVolumeOperationsMenu()
        wireDefaultHelpMenuItem()
        presentFirstLaunchHelpIfNeeded()
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

    private func installVolumeOperationsMenu() {
        guard let mainMenu = NSApp.mainMenu else { return }
        
        let volumeMenuItem = NSMenuItem(title: "Volume", action: nil, keyEquivalent: "")
        let volumeMenu = NSMenu(title: "Volume")
        volumeMenuItem.submenu = volumeMenu
        
        let copyInItem = NSMenuItem(title: "Copy In…",
                                    action: #selector(VolumeDataViewController.importItems(_:)),
                                    keyEquivalent: "i")
        copyInItem.keyEquivalentModifierMask = [.command]
        copyInItem.target = nil
        
        let copyOutItem = NSMenuItem(title: "Copy Out…",
                                     action: #selector(VolumeDataViewController.exportSelectedItem(_:)),
                                     keyEquivalent: "e")
        copyOutItem.keyEquivalentModifierMask = [.command]
        copyOutItem.target = nil
        
        let renameItem = NSMenuItem(title: "Rename…",
                                    action: #selector(VolumeDataViewController.renameSelectedItem(_:)),
                                    keyEquivalent: "r")
        renameItem.keyEquivalentModifierMask = [.command]
        renameItem.target = nil
        
        let typeCreatorItem = NSMenuItem(title: "Type/Creator…",
                                         action: #selector(VolumeDataViewController.changeTypeCreatorSelectedItem(_:)),
                                         keyEquivalent: "t")
        typeCreatorItem.keyEquivalentModifierMask = [.command, .option]
        typeCreatorItem.target = nil
        
        let deleteItem = NSMenuItem(title: "Delete",
                                    action: #selector(VolumeDataViewController.deleteSelectedItems(_:)),
                                    keyEquivalent: String(UnicodeScalar(NSDeleteCharacter)!))
        deleteItem.keyEquivalentModifierMask = []
        deleteItem.target = nil
        
        volumeMenu.addItem(copyInItem)
        volumeMenu.addItem(copyOutItem)
        volumeMenu.addItem(NSMenuItem.separator())
        volumeMenu.addItem(renameItem)
        volumeMenu.addItem(typeCreatorItem)
        volumeMenu.addItem(deleteItem)
        
        let insertIndex = mainMenu.items.firstIndex { $0.title == "Window" } ?? mainMenu.numberOfItems
        mainMenu.insertItem(volumeMenuItem, at: insertIndex)
    }
    
    private func presentFirstLaunchHelpIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: disclaimerAcknowledgedKey) else { return }
        
        DispatchQueue.main.async {
            self.showHelpWindow(requiresAcknowledgement: true, modal: true)
        }
    }
    
    @IBAction func showHelp(_ sender: Any?) {
        showHelpWindow(requiresAcknowledgement: false, modal: false)
    }
    
    private func wireDefaultHelpMenuItem() {
        guard let helpMenu = NSApp.helpMenu else { return }
        guard let appHelpItem = helpMenu.items.first(where: { $0.action == #selector(NSApplication.showHelp(_:)) }) else {
            return
        }
        appHelpItem.target = self
        appHelpItem.action = #selector(showHelp(_:))
    }
    
    private func showHelpWindow(requiresAcknowledgement: Bool, modal: Bool) {
        if let existing = helpWindowController?.window, existing.isVisible {
            existing.makeKeyAndOrderFront(self)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        let controller = HelpWindowController(
            requiresAcknowledgement: requiresAcknowledgement,
            onAcknowledged: { [weak self] in
                guard let self else { return }
                UserDefaults.standard.set(true, forKey: self.disclaimerAcknowledgedKey)
            }
        )
        helpWindowController = controller
        
        guard let window = controller.window else { return }
        
        helpWindowCloseObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            if modal {
                NSApp.stopModal()
            }
            if let observer = self?.helpWindowCloseObserver {
                NotificationCenter.default.removeObserver(observer)
                self?.helpWindowCloseObserver = nil
            }
            self?.helpWindowController = nil
        }
        
        NSApp.activate(ignoringOtherApps: true)
        controller.showWindow(self)
        
        if modal {
            NSApp.runModal(for: window)
        }
    }

}
