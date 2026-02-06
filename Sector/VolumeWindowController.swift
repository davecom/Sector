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
    var displayName: String?
    private let defaultContentSize = NSSize(width: 940, height: 640)
    private let minimumContentSize = NSSize(width: 820, height: 520)
    
    private enum ToolbarIdentifiers {
        static let toolbar = NSToolbar.Identifier("SectorVolumeToolbar")
        static let importItem = NSToolbarItem.Identifier("SectorToolbarImport")
        static let exportItem = NSToolbarItem.Identifier("SectorToolbarExport")
        static let renameItem = NSToolbarItem.Identifier("SectorToolbarRename")
        static let deleteItem = NSToolbarItem.Identifier("SectorToolbarDelete")
    }
    
    func configureUI() {
        if let title = displayName, !title.isEmpty {
            window?.title = title
        }
        
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
        applyInitialWindowSizing()
        if let title = displayName, !title.isEmpty {
            self.window?.title = title
        }
        configureToolbar()
    }
    
    private func applyInitialWindowSizing() {
        guard let window else { return }
        window.contentMinSize = minimumContentSize
        
        let current = window.contentRect(forFrameRect: window.frame).size
        if current.width < defaultContentSize.width || current.height < defaultContentSize.height {
            window.setContentSize(defaultContentSize)
            window.center()
        }
    }
    
    private func configureToolbar() {
        let toolbar = NSToolbar(identifier: ToolbarIdentifiers.toolbar)
        toolbar.delegate = self
        toolbar.displayMode = .iconOnly
        toolbar.allowsUserCustomization = false
        toolbar.autosavesConfiguration = false
        self.window?.toolbar = toolbar
        self.window?.toolbarStyle = .unified
    }
    
    
}

extension VolumeWindowController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        self.volume?.close()
    }
}

extension VolumeWindowController: NSToolbarDelegate {
    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return [
            ToolbarIdentifiers.importItem,
            ToolbarIdentifiers.exportItem,
            ToolbarIdentifiers.renameItem,
            ToolbarIdentifiers.deleteItem,
            .flexibleSpace
        ]
    }
    
    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return [
            ToolbarIdentifiers.importItem,
            ToolbarIdentifiers.exportItem,
            ToolbarIdentifiers.renameItem,
            ToolbarIdentifiers.deleteItem,
            .flexibleSpace
        ]
    }
    
    func toolbar(_ toolbar: NSToolbar,
                 itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
                 willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        switch itemIdentifier {
        case ToolbarIdentifiers.importItem:
            let item = NSToolbarItem(itemIdentifier: itemIdentifier)
            item.label = "Import"
            item.paletteLabel = "Import"
            item.toolTip = "Import files or folders into the volume"
            item.image = NSImage(systemSymbolName: "plus", accessibilityDescription: nil)
            item.target = nil
            item.action = #selector(VolumeDataViewController.importItems(_:))
            return item
            
        case ToolbarIdentifiers.exportItem:
            let item = NSToolbarItem(itemIdentifier: itemIdentifier)
            item.label = "Export"
            item.paletteLabel = "Export"
            item.toolTip = "Export selected file or folder"
            item.image = NSImage(systemSymbolName: "square.and.arrow.down", accessibilityDescription: nil)
            item.target = nil
            item.action = #selector(VolumeDataViewController.exportSelectedItem(_:))
            return item
        
        case ToolbarIdentifiers.renameItem:
            let item = NSToolbarItem(itemIdentifier: itemIdentifier)
            item.label = "Rename"
            item.paletteLabel = "Rename"
            item.toolTip = "Rename selected file or folder"
            item.image = NSImage(systemSymbolName: "pencil", accessibilityDescription: nil)
            item.target = nil
            item.action = #selector(VolumeDataViewController.renameSelectedItem(_:))
            return item
            
        case ToolbarIdentifiers.deleteItem:
            let item = NSToolbarItem(itemIdentifier: itemIdentifier)
            item.label = "Delete"
            item.paletteLabel = "Delete"
            item.toolTip = "Delete selected file or folder"
            item.image = NSImage(systemSymbolName: "trash", accessibilityDescription: nil)
            item.target = nil
            item.action = #selector(VolumeDataViewController.deleteSelectedItems(_:))
            return item
            
        default:
            return nil
        }
    }
}
