//
//  VolumeWindowController.swift
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
        static let transferModeItem = NSToolbarItem.Identifier("SectorToolbarTransferMode")
        static let renameItem = NSToolbarItem.Identifier("SectorToolbarRename")
        static let typeCreatorItem = NSToolbarItem.Identifier("SectorToolbarTypeCreator")
        static let deleteItem = NSToolbarItem.Identifier("SectorToolbarDelete")
    }
    
    private weak var transferModePopUpButton: NSPopUpButton?
    
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
        toolbar.displayMode = .iconAndLabel
        toolbar.allowsUserCustomization = false
        toolbar.autosavesConfiguration = false
        self.window?.toolbar = toolbar
        self.window?.toolbarStyle = .unified
    }
    
    private func volumeDataViewController() -> VolumeDataViewController? {
        guard let split = contentViewController as? NSSplitViewController else { return nil }
        guard split.splitViewItems.count > 1 else { return nil }
        return split.splitViewItems[1].viewController as? VolumeDataViewController
    }
    
    @objc private func transferModeSelectionChanged(_ sender: NSPopUpButton) {
        guard sender.indexOfSelectedItem >= 0 else { return }
        guard let selectedItem = sender.item(at: sender.indexOfSelectedItem) else { return }
        guard let rawValue = selectedItem.representedObject as? Int32 else { return }
        guard let mode = HFSVolume.CopyMode(rawValue: rawValue) else { return }
        volumeDataViewController()?.setTransferMode(mode)
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
            ToolbarIdentifiers.transferModeItem,
            ToolbarIdentifiers.renameItem,
            ToolbarIdentifiers.typeCreatorItem,
            ToolbarIdentifiers.deleteItem,
            .flexibleSpace
        ]
    }
    
    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return [
            ToolbarIdentifiers.importItem,
            ToolbarIdentifiers.exportItem,
            ToolbarIdentifiers.transferModeItem,
            ToolbarIdentifiers.renameItem,
            ToolbarIdentifiers.typeCreatorItem,
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
            
        case ToolbarIdentifiers.transferModeItem:
            let item = NSToolbarItem(itemIdentifier: itemIdentifier)
            item.label = "Mode"
            item.paletteLabel = "Transfer Mode"
            item.toolTip = "Transfer mode for Copy In/Copy Out operations"
            
            let popup = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 150, height: 28), pullsDown: false)
            let modes: [(String, HFSVolume.CopyMode)] = [
                ("Auto", .auto),
                ("Raw", .raw),
                ("MacBinary", .macBinary),
                ("BinHex", .binHex),
                ("Text", .text)
            ]
            for (title, mode) in modes {
                popup.addItem(withTitle: title)
                popup.lastItem?.representedObject = mode.rawValue
            }
            popup.target = self
            popup.action = #selector(transferModeSelectionChanged(_:))
            popup.sizeToFit()
            popup.frame.size.width = 150
            
            if let dataVC = volumeDataViewController() {
                let index = modes.firstIndex(where: { $0.1 == dataVC.transferMode }) ?? 0
                popup.selectItem(at: index)
            } else {
                popup.selectItem(at: 0)
            }
            
            transferModePopUpButton = popup
            item.view = popup
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
            
        case ToolbarIdentifiers.typeCreatorItem:
            let item = NSToolbarItem(itemIdentifier: itemIdentifier)
            item.label = "Type/Creator"
            item.paletteLabel = "Type/Creator"
            item.toolTip = "Change Type and Creator of selected file"
            item.image = NSImage(systemSymbolName: "tag", accessibilityDescription: nil)
            item.target = nil
            item.action = #selector(VolumeDataViewController.changeTypeCreatorSelectedItem(_:))
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
