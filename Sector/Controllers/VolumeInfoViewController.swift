//
//  VolumeInfoViewController.swift
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

class VolumeInfoViewController: NSViewController {
    
    final var volume: HFSVolume?
    
    @IBOutlet weak var totalSizeValueLabel: NSTextField!
    @IBOutlet weak var usedSizeValueLabel: NSTextField!
    @IBOutlet weak var freeSizeValueLabel: NSTextField!
    @IBOutlet weak var filesCountValueLabel: NSTextField!
    @IBOutlet weak var foldersCountValueLabel: NSTextField!
    @IBOutlet weak var allocationBlockSizeValueLabel: NSTextField!
    @IBOutlet weak var clumpSizeValueLabel: NSTextField!
    @IBOutlet weak var modifiedDateValueLabel: NSTextField!
    @IBOutlet weak var backupDateValueLabel: NSTextField!
    @IBOutlet weak var flagsValueLabel: NSTextField!
    @IBOutlet weak var blessedFolderValueLabel: NSTextField!

    private static let byteFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB, .useTB]
        formatter.countStyle = .file
        formatter.includesUnit = true
        formatter.isAdaptive = true
        return formatter
    }()

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.doesRelativeDateFormatting = true
        return formatter
    }()

    private func formatBytes(_ bytes: UInt64) -> String {
        return Self.byteFormatter.string(fromByteCount: Int64(bytes))
    }

    private func formatDate(_ date: Date) -> String {
        return Self.dateFormatter.string(from: date)
    }

    func updateUI() {
        do {
            if let volumeInfo = try volume?.volumeInfo() {
                totalSizeValueLabel.stringValue = formatBytes(volumeInfo.totalBytes)
                usedSizeValueLabel.stringValue = formatBytes(volumeInfo.usedBytes)
                freeSizeValueLabel.stringValue = formatBytes(volumeInfo.freeBytes)
                filesCountValueLabel.stringValue = "\(volumeInfo.numberOfFiles)"
                foldersCountValueLabel.stringValue = "\(volumeInfo.numberOfDirectories)"
                allocationBlockSizeValueLabel.stringValue = formatBytes(UInt64(volumeInfo.allocationBlockSize))
                clumpSizeValueLabel.stringValue = formatBytes(UInt64(volumeInfo.clumpSize))
                modifiedDateValueLabel.stringValue = formatDate(volumeInfo.modified)
                backupDateValueLabel.stringValue = formatDate(volumeInfo.backup)
                flagsValueLabel.stringValue = String(format: "0x%08X", volumeInfo.flags)
                blessedFolderValueLabel.stringValue = "\(volumeInfo.blessedFolderId)"
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
