//
//  FileController.swift
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

class FileController {
    private var volumeWindowControllers: [VolumeWindowController] = []
    
    private struct HFSPartitionChoice {
        let ordinal: Int
        let mapIndex: Int
        let name: String
    }
    
    private func openVolume(at url: URL, partitionCandidates: [Int?]) throws -> HFSVolume {
        var attempted: Set<String> = []
        var lastError: Error?
        
        for candidate in partitionCandidates {
            let key = candidate.map(String.init) ?? "nil"
            if attempted.contains(key) { continue }
            attempted.insert(key)
            
            do {
                return try HFSVolume(path: url, writable: true, partition: candidate)
            } catch {
                lastError = error
            }
        }
        
        if let lastError {
            throw lastError
        }
        throw HFSError.invalidArgument("No partition candidates available.")
    }
    
    private func promptForPartitionSelection(choices: [HFSPartitionChoice],
                                             fileName: String) -> Int? {
        let runAlert: () -> Int? = {
            let alert = NSAlert()
            alert.messageText = "Choose a Partition"
            alert.informativeText = "\"\(fileName)\" contains multiple HFS partitions. Select one to open."
            alert.addButton(withTitle: "OK")
            alert.addButton(withTitle: "Cancel")
            
            let popup = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 320, height: 24), pullsDown: false)
            for choice in choices {
                let displayName = choice.name.isEmpty ? "Untitled" : choice.name
                popup.addItem(withTitle: "HFS \(choice.ordinal) (map \(choice.mapIndex)): \(displayName)")
            }
            popup.selectItem(at: 0)
            alert.accessoryView = popup
            
            let response = alert.runModal()
            guard response == .alertFirstButtonReturn else { return nil }
            let selectedIndex = popup.indexOfSelectedItem
            guard selectedIndex >= 0 && selectedIndex < choices.count else { return nil }
            return choices[selectedIndex].ordinal
        }
        
        if Thread.isMainThread {
            return runAlert()
        }
        
        var result: Int?
        DispatchQueue.main.sync {
            result = runAlert()
        }
        return result
    }
    
    /// Updates the canvas with a given image.
    private func handleVolume(_ volume: HFSVolume, displayName: String) {
        
        let vwc: VolumeWindowController = NSStoryboard(name: "Main", bundle: nil).instantiateController(withIdentifier: "volumeWindowController") as! VolumeWindowController
        vwc.volume = volume
        vwc.displayName = displayName
        vwc.configureUI()
        vwc.showWindow(self)
        
        if let window = vwc.window {
                
            // be ready to release memory when done
            NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: window, queue: nil, using: { [unowned self, unowned vwc] (n:Notification) -> Void in
                    
                    self.volumeWindowControllers.removeAll { $0 === vwc }
                    vwc.contentViewController = nil // releases some memory
                        NotificationCenter.default.removeObserver(self, name: NSWindow.willCloseNotification, object: window)
                    }
                )
                
            volumeWindowControllers.append(vwc)
        }
    }

    /// Updates the canvas with a given image file.
    public func handleFile(at url: URL) {
        do {
            let partitionCandidates: [Int?]
            do {
                let partitions = try HFSVolume.listPartitions(path: url)
                let hfsPartitions = partitions.filter { $0.isHFS }
                let choices = hfsPartitions.enumerated().map { offset, part in
                    HFSPartitionChoice(ordinal: offset + 1, mapIndex: part.index, name: part.name)
                }
                
                if choices.count > 1 {
                    guard let selection = promptForPartitionSelection(
                        choices: choices,
                        fileName: url.lastPathComponent
                    ) else {
                        return
                    }
                    if let selectedChoice = choices.first(where: { $0.ordinal == selection }) {
                        partitionCandidates = [selectedChoice.ordinal, selectedChoice.mapIndex, nil, 0]
                    } else {
                        partitionCandidates = [selection, nil, 0]
                    }
                } else if let onlyChoice = choices.first {
                    // Some images behave differently; try both numbering schemes.
                    partitionCandidates = [onlyChoice.ordinal, onlyChoice.mapIndex, nil, 0]
                } else {
                    // No HFS partition map entries; try automatic/raw behavior.
                    partitionCandidates = [nil, 0]
                }
            } catch {
                // If partition listing fails entirely, still attempt normal open paths.
                partitionCandidates = [nil, 0, 1]
            }
            
            let volume = try openVolume(at: url, partitionCandidates: partitionCandidates)
            let displayName = url.deletingPathExtension().lastPathComponent
            OperationQueue.main.addOperation {
                self.handleVolume(volume, displayName: displayName)
            }
        } catch let error {
            print(error)
            presentErrorAlert(for: error)
        }
    }
    
}
