//
//  AppDelegate.swift
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
    
    func applicationWillFinishLaunching(_ notification: Notification) {
        registerBundledFonts()
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }
    
    func application(_ sender: NSApplication, openFile filename: String) -> Bool {
        AppDelegate.fileController.handleFile(at: URL(fileURLWithPath: filename))
        return true
    }
    
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            AppDelegate.fileController.handleFile(at: url)
        }
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
    
    private func registerBundledFonts() {
        guard let fontURL = Bundle.main.url(forResource: "ChicagoFLF", withExtension: "ttf") else {
            print("Font not found in bundle: ChicagoFLF.ttf")
            return
        }

        var error: Unmanaged<CFError>?
        let ok = CTFontManagerRegisterFontsForURL(fontURL as CFURL, .process, &error)

        if !ok {
            let nsError = (error?.takeRetainedValue()) as Error?
            print("Font registration failed: \(nsError?.localizedDescription ?? "unknown error")")
        }

        // Sanity check
        if let font = NSFont(name: "ChicagoFLF", size: 36) {
            print("Loaded font: \(font.fontName)")
        } else {
            print("NSFont lookup failed for ChicagoFLF")
        }
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
    
    @IBAction func newDocument(_ sender: AnyObject) {
        let savePanel = NSSavePanel()
        savePanel.canCreateDirectories = true
        savePanel.nameFieldStringValue = "Untitled.img"
        savePanel.isExtensionHidden = false
        if let imgType = UTType(filenameExtension: "img") {
            savePanel.allowedContentTypes = [imgType]
        }
        
        let options = NewImageOptionsController()
        savePanel.accessoryView = options.containerView
        
        guard savePanel.runModal() == .OK, let baseURL = savePanel.url else { return }
        let targetURL: URL
        if baseURL.pathExtension.lowercased() == "img" {
            targetURL = baseURL
        } else {
            targetURL = baseURL.appendingPathExtension("img")
        }
        
        guard options.isValid else {
            presentErrorAlert(message: "Please choose a valid size and a volume name up to 27 characters.")
            return
        }
        
        do {
            try HFSVolume.createBlank(path: targetURL, size: options.selectedSizeBytes, volumeName: options.volumeName)
            AppDelegate.fileController.handleFile(at: targetURL)
        } catch {
            presentErrorAlert(for: error)
        }
    }
    
    @IBAction func runHFSCK(_ sender: AnyObject) {
        let panel = NSOpenPanel()
        panel.title = "Choose HFS Disk Image to Check"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        panel.prompt = "Choose"
        
        guard panel.runModal() == .OK, let imageURL = panel.url else { return }
        
        let warning = NSAlert()
        warning.alertStyle = .warning
        warning.messageText = "Run HFS Check and Repair?"
        warning.informativeText = "This operation may modify and potentially damage the disk image. Continue only if you have a backup."
        warning.addButton(withTitle: "Cancel")
        warning.addButton(withTitle: "Run HFS Check")
        guard warning.runModal() == .alertSecondButtonReturn else { return }
        
        do {
            let output = try runHFSCheck(on: imageURL)
            presentHFSCheckResults(output, for: imageURL)
        } catch {
            presentErrorAlert(for: error)
        }
    }
    
    // Create an email to support
    @IBAction func emailSupport(sender: NSMenuItem) {
        let emailURL: URL = URL(string: "mailto:sector@oaksnow.com")!
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
        
        let setBlessedFolderItem = NSMenuItem(title: "Set Blessed Folder",
                                              action: #selector(VolumeDataViewController.setBlessedFolderSelectedItem(_:)),
                                              keyEquivalent: "")
        setBlessedFolderItem.target = nil
        
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
        volumeMenu.addItem(setBlessedFolderItem)
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
    
    private func presentHFSCheckResults(_ output: String, for imageURL: URL) {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "HFS Check Results"
        alert.informativeText = imageURL.lastPathComponent
        alert.addButton(withTitle: "OK")
        
        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 700, height: 420))
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .bezelBorder
        
        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 700, height: 420))
        textView.isEditable = false
        textView.isSelectable = true
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = true
        textView.autoresizingMask = [.width, .height]
        textView.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.string = output.isEmpty ? "(No output)" : output
        
        scrollView.documentView = textView
        alert.accessoryView = scrollView
        alert.runModal()
    }

}
