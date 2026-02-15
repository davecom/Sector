//
//  VolumeViewController.swift
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

private final class HFSNode {
    let info: HFSFileInfo
    var children: [HFSNode]?
    
    init(info: HFSFileInfo) {
        self.info = info
    }
}

private final class FourCharacterCodeDelegate: NSObject, NSTextFieldDelegate {
    weak var okButton: NSButton?
    weak var typeField: NSTextField?
    weak var creatorField: NSTextField?
    
    private func isValid(_ text: String) -> Bool {
        text.count == 4
    }
    
    private func refreshOKState() {
        let validType = isValid(typeField?.stringValue ?? "")
        let validCreator = isValid(creatorField?.stringValue ?? "")
        okButton?.isEnabled = validType && validCreator
    }
    
    func controlTextDidChange(_ obj: Notification) {
        refreshOKState()
    }
    
    func control(_ control: NSControl,
                 textView: NSTextView,
                 shouldChangeTextIn affectedCharRange: NSRange,
                 replacementString: String?) -> Bool {
        guard let textField = control as? NSTextField else { return true }
        let current = textField.stringValue as NSString
        let next = current.replacingCharacters(in: affectedCharRange, with: replacementString ?? "")
        return next.count <= 4
    }
}

class VolumeDataViewController: NSViewController {
    
    final var volume: HFSVolume?
    private(set) var transferMode: HFSVolume.CopyMode = .auto
    
    // MARK: - IBOutlets (Hook up in Interface Builder)
    @IBOutlet weak var outlineView: OperationOutlineView!
    @IBOutlet weak var detailNameValueLabel: NSTextField!
    @IBOutlet weak var detailPathValueLabel: NSTextField!
    @IBOutlet weak var detailKindValueLabel: NSTextField!
    @IBOutlet weak var detailSizeValueLabel: NSTextField!
    @IBOutlet weak var detailDataDorkSizeValueLabel: NSTextField!
    @IBOutlet weak var detailResourceForkSizeValueLabel: NSTextField!
    @IBOutlet weak var detailCreatedValueLabel: NSTextField!
    @IBOutlet weak var detailModifiedValueLabel: NSTextField!
    @IBOutlet weak var detailTypeValueLabel: NSTextField!
    @IBOutlet weak var detailCreatorValueLabel: NSTextField!
    
    private var rootNodes: [HFSNode] = []
    private var selectedNode: HFSNode?
    private var currentInternalDragPaths: [String] = []
    private var typeCreatorDialogDelegate: FourCharacterCodeDelegate?
    
    private static let byteFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB, .useTB]
        formatter.countStyle = .file
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
    
    private static let tableDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()
    
    private enum ColumnID {
        static let name = NSUserInterfaceItemIdentifier("name")
        static let size = NSUserInterfaceItemIdentifier("size")
        static let modified = NSUserInterfaceItemIdentifier("modified")
    }

    private func joinHFSPath(_ base: String, _ name: String) -> String {
        if base == ":" { return ":\(name)" }
        return "\(base):\(name)"
    }
    
    private func parentHFSPath(of path: String) -> String {
        if path == ":" { return ":" }
        guard let lastColon = path.lastIndex(of: ":") else { return ":" }
        if lastColon == path.startIndex { return ":" }
        return String(path[..<lastColon])
    }
    
    private func sanitizedHFSName(_ hostName: String) -> String {
        let cleaned = hostName.replacingOccurrences(of: ":", with: "-")
        return cleaned.isEmpty ? "Untitled" : cleaned
    }
    
    private func node(for item: Any?) -> HFSNode? {
        return item as? HFSNode
    }
    
    private func loadChildren(for node: HFSNode?) throws -> [HFSNode] {
        guard let volume else { return [] }
        let hfsPath = node?.info.path ?? ":"
        let items = try volume.list(directory: hfsPath).sorted { lhs, rhs in
            if lhs.isDirectory != rhs.isDirectory {
                return lhs.isDirectory && !rhs.isDirectory
            }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
        return items.map { HFSNode(info: $0) }
    }
    
    private func ensureChildrenLoaded(for node: HFSNode?) {
        do {
            if let node {
                if node.info.isDirectory, node.children == nil {
                    node.children = try loadChildren(for: node)
                }
            } else if rootNodes.isEmpty {
                rootNodes = try loadChildren(for: nil)
            }
        } catch {
            presentErrorAlert(for: error)
        }
    }
    
    private func resetTreeAndReload() {
        rootNodes = []
        ensureChildrenLoaded(for: nil)
        outlineView?.reloadData()
        updateDetailLabels(with: nil)
    }
    
    private func refreshVolumeInfoDisplay() {
        guard let split = self.parent as? NSSplitViewController else { return }
        guard split.splitViewItems.count > 0 else { return }
        if let infoVC = split.splitViewItems[0].viewController as? VolumeInfoViewController {
            infoVC.updateUI()
        }
    }
    
    private func clearNodeCache(forDirectoryPath directoryPath: String) {
        if directoryPath == ":" {
            rootNodes = []
            return
        }
        
        func clear(in nodes: [HFSNode]) -> Bool {
            for node in nodes where node.info.path == directoryPath {
                node.children = nil
                return true
            }
            for node in nodes {
                if let children = node.children, clear(in: children) {
                    return true
                }
            }
            return false
        }
        
        _ = clear(in: rootNodes)
    }
    
    private func updateDetailLabels(with node: HFSNode?) {
        guard let node else {
            detailNameValueLabel?.stringValue = "-"
            detailPathValueLabel?.stringValue = "-"
            detailKindValueLabel?.stringValue = "-"
            detailSizeValueLabel?.stringValue = "-"
            detailDataDorkSizeValueLabel?.stringValue = "-"
            detailResourceForkSizeValueLabel?.stringValue = "-"
            detailCreatedValueLabel?.stringValue = "-"
            detailModifiedValueLabel?.stringValue = "-"
            detailTypeValueLabel?.stringValue = "-"
            detailCreatorValueLabel?.stringValue = "-"
            return
        }
        
        let info = node.info
        detailNameValueLabel?.stringValue = sanitizedDisplayText(info.name)
        detailPathValueLabel?.stringValue = sanitizedDisplayText(info.path)
        detailKindValueLabel?.stringValue = info.isDirectory ? "Folder" : "File"
        detailSizeValueLabel?.stringValue = info.isDirectory ? "-" : sizeString(for: info)
        detailResourceForkSizeValueLabel?.stringValue = info.isDirectory ? "-" : Self.byteFormatter.string(fromByteCount: Int64(info.resourceForkSize))
        detailDataDorkSizeValueLabel?.stringValue = info.isDirectory ? "-" : Self.byteFormatter.string(fromByteCount: Int64(info.dataForkSize))
        detailCreatedValueLabel?.stringValue = formatDateIfMeaningful(info.created)
        detailModifiedValueLabel?.stringValue = formatDateIfMeaningful(info.modified)
        
        if info.isDirectory {
            detailTypeValueLabel?.stringValue = "-"
            detailCreatorValueLabel?.stringValue = "-"
        } else {
            let type = info.fileType.isEmpty ? "????" : info.fileType
            let creator = info.fileCreator.isEmpty ? "????" : info.fileCreator
            detailTypeValueLabel?.stringValue = type
            detailCreatorValueLabel?.stringValue = creator
        }
    }
    
    private func sizeString(for info: HFSFileInfo) -> String {
        let bytes = UInt64(max(0, info.dataForkSize + info.resourceForkSize))
        return Self.byteFormatter.string(fromByteCount: Int64(bytes))
    }
    
    private func formatDateIfMeaningful(_ date: Date) -> String {
        let calendar = Calendar(identifier: .gregorian)
        let floor = calendar.date(from: DateComponents(year: 1984, month: 1, day: 1)) ?? .distantPast
        if date < floor || date > Date.distantFuture.addingTimeInterval(-1) {
            return "-"
        }
        return Self.dateFormatter.string(from: date)
    }
    
    private func tableModifiedString(for info: HFSFileInfo) -> String {
        let calendar = Calendar(identifier: .gregorian)
        let floor = calendar.date(from: DateComponents(year: 1984, month: 1, day: 1)) ?? .distantPast
        if info.modified < floor {
            return "-"
        }
        return Self.tableDateFormatter.string(from: info.modified)
    }

    private func sanitizedDisplayText(_ text: String) -> String {
        let replaced = text
            .replacingOccurrences(of: "\r", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\t", with: " ")
        let withoutControls = replaced.components(separatedBy: CharacterSet.controlCharacters).joined(separator: " ")
        return withoutControls
            .replacingOccurrences(of: "\\s+", with: " ", options: NSString.CompareOptions.regularExpression)
            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
    }
    
    private func destinationDirectoryPathForImport() -> String {
        guard let selectedNode else { return ":" }
        if selectedNode.info.isDirectory {
            return selectedNode.info.path
        }
        return parentHFSPath(of: selectedNode.info.path)
    }
    
    private func selectedNodes(from items: [Any]) -> [HFSNode] {
        return items.compactMap { $0 as? HFSNode }
    }
    
    private func selectedNodesFromOutline() -> [HFSNode] {
        let rows = outlineView.selectedRowIndexes
        return rows.compactMap { row in
            guard row >= 0 else { return nil }
            return outlineView.item(atRow: row) as? HFSNode
        }
    }
    
    private func normalizedDeleteList(from nodes: [HFSNode]) -> [HFSNode] {
        let sorted = nodes.sorted { $0.info.path.count < $1.info.path.count }
        var keep: [HFSNode] = []
        for node in sorted {
            let isChildOfAlreadySelected = keep.contains { parent in
                node.info.path.hasPrefix(parent.info.path + ":")
            }
            if !isChildOfAlreadySelected {
                keep.append(node)
            }
        }
        return keep.sorted { $0.info.path.count > $1.info.path.count }
    }
    
    private func normalizedTopLevelPaths(_ paths: [String]) -> [String] {
        let sorted = paths.sorted { $0.count < $1.count }
        var keep: [String] = []
        for path in sorted {
            let isNested = keep.contains { parent in
                path == parent || path.hasPrefix(parent + ":")
            }
            if !isNested {
                keep.append(path)
            }
        }
        return keep
    }
    
    private func isInvalidInternalDrop(sourcePaths: [String], destinationPath: String) -> Bool {
        for sourcePath in sourcePaths {
            if destinationPath == sourcePath || destinationPath.hasPrefix(sourcePath + ":") {
                return true
            }
        }
        return false
    }
    
    private func copyOut(node: HFSNode, to hostPath: URL) throws -> URL {
        guard let volume else { throw HFSError.volumeClosed }
        if node.info.isDirectory {
            try volume.copyOutDirectory(hfsPath: node.info.path, toHostDirectory: hostPath, mode: transferMode)
            return hostPath
        } else {
            var isDirectory: ObjCBool = false
            let destinationExists = FileManager.default.fileExists(atPath: hostPath.path, isDirectory: &isDirectory)
            if destinationExists && isDirectory.boolValue {
                let beforeEntries = Set((try? FileManager.default.contentsOfDirectory(atPath: hostPath.path)) ?? [])
                try volume.copyOut(hfsPath: node.info.path, toHostPath: hostPath, mode: transferMode)
                let afterEntries = Set((try? FileManager.default.contentsOfDirectory(atPath: hostPath.path)) ?? [])
                let created = afterEntries.subtracting(beforeEntries).sorted()
                if let createdName = created.first {
                    return hostPath.appendingPathComponent(createdName, isDirectory: false)
                }
                return hostPath.appendingPathComponent(node.info.name, isDirectory: false)
            }
            try volume.copyOut(hfsPath: node.info.path, toHostPath: hostPath, mode: transferMode)
            return hostPath
        }
    }
    
    private func copyIn(hostURL: URL, toParentHFSPath parentPath: String) throws {
        guard let volume else { return }
        let hfsName = sanitizedHFSName(hostURL.lastPathComponent)
        let destinationPath = joinHFSPath(parentPath, hfsName)
        
        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: hostURL.path, isDirectory: &isDirectory)
        guard exists else { return }
        
        if let existing = try existingItem(named: hfsName, inDirectory: parentPath) {
            let shouldReplace = confirmReplace(existingName: existing.name, isDirectory: existing.isDirectory)
            guard shouldReplace else { return }
            try volume.delete(existing)
        }
        
        if isDirectory.boolValue {
            try volume.copyInDirectory(hostDirectory: hostURL, toHFSPath: destinationPath, mode: transferMode)
        } else {
            try volume.copyIn(hostPath: hostURL, toHFSPath: destinationPath, mode: transferMode)
        }
    }
    
    private func existingItem(named name: String, inDirectory directoryPath: String) throws -> HFSFileInfo? {
        guard let volume else { return nil }
        return try volume.list(directory: directoryPath).first {
            $0.name.localizedCaseInsensitiveCompare(name) == .orderedSame
        }
    }

    private func copyWithinVolume(sourcePath: String, toParentHFSPath parentPath: String) throws {
        guard let volume else { return }
        if parentHFSPath(of: sourcePath) == parentPath { return }
        
        let sourceInfo = try volume.attributes(of: sourcePath)
        let destinationName = sourceInfo.name
        let destinationPath = joinHFSPath(parentPath, destinationName)
        
        if let existing = try existingItem(named: destinationName, inDirectory: parentPath) {
            if existing.path == sourcePath { return }
            let shouldReplace = confirmReplace(existingName: existing.name, isDirectory: existing.isDirectory)
            guard shouldReplace else { return }
            try volume.delete(existing)
        }
        
        let tempBase = FileManager.default.temporaryDirectory
            .appendingPathComponent("SectorInternalCopy-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempBase, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempBase) }
        
        let tempHostPath = tempBase.appendingPathComponent(destinationName, isDirectory: sourceInfo.isDirectory)
        if sourceInfo.isDirectory {
            try volume.copyOutDirectory(hfsPath: sourcePath, toHostDirectory: tempHostPath)
            try volume.copyInDirectory(hostDirectory: tempHostPath, toHFSPath: destinationPath)
        } else {
            try volume.copyOut(hfsPath: sourcePath, toHostPath: tempBase, mode: .auto)
            let exportedURL = tempBase.appendingPathComponent(destinationName, isDirectory: false)
            try volume.copyIn(hostPath: exportedURL, toHFSPath: destinationPath, mode: .auto)
        }
    }
    
    private func confirmReplace(existingName: String, isDirectory: Bool) -> Bool {
        let kind = isDirectory ? "folder" : "file"
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Replace Existing \(kind.capitalized)?"
        alert.informativeText = "\"\(existingName)\" already exists in this location. Replacing it will permanently remove the current \(kind)."
        alert.addButton(withTitle: "Cancel")
        alert.addButton(withTitle: "Replace")
        return alert.runModal() == .alertSecondButtonReturn
    }
    
    private func confirmDelete(nodes: [HFSNode]) -> Bool {
        let count = nodes.count
        let alert = NSAlert()
        alert.alertStyle = .warning
        if count == 1, let node = nodes.first {
            let kind = node.info.isDirectory ? "folder" : "file"
            alert.messageText = "Delete \(kind.capitalized)?"
            alert.informativeText = "\"\(node.info.name)\" will be permanently deleted."
        } else {
            alert.messageText = "Delete \(count) Items?"
            alert.informativeText = "The selected files and folders will be permanently deleted."
        }
        alert.addButton(withTitle: "Cancel")
        alert.addButton(withTitle: "Delete")
        return alert.runModal() == .alertSecondButtonReturn
    }
    
    private func exportedURLsForDrag(nodes: [HFSNode]) throws -> [URL] {
        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent("SectorDrag-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        
        var urls: [URL] = []
        for node in nodes {
            if node.info.isDirectory {
                let hostURL = base.appendingPathComponent(node.info.name, isDirectory: true)
                let exportedURL = try copyOut(node: node, to: hostURL)
                urls.append(exportedURL)
            } else {
                let exportedURL = try copyOut(node: node, to: base)
                urls.append(exportedURL)
            }
        }
        return urls
    }
    
    private func promptForRename(currentName: String) -> String? {
        let alert = NSAlert()
        alert.messageText = "Rename Item"
        alert.informativeText = "Enter a new name:"
        alert.addButton(withTitle: "Rename")
        alert.addButton(withTitle: "Cancel")
        
        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
        textField.stringValue = currentName
        alert.accessoryView = textField
        
        guard alert.runModal() == .alertFirstButtonReturn else { return nil }
        let value = textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, !value.contains(":") else { return nil }
        return value
    }
    
    private func promptForTypeAndCreator(currentType: String, currentCreator: String) -> (type: String, creator: String)? {
        let alert = NSAlert()
        alert.messageText = "Set Type and Creator"
        alert.informativeText = "Enter a four-character Type and Creator code."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        
        let typeField = NSTextField(frame: NSRect(x: 0, y: 0, width: 120, height: 24))
        let creatorField = NSTextField(frame: NSRect(x: 0, y: 0, width: 120, height: 24))
        typeField.stringValue = currentType
        creatorField.stringValue = currentCreator
        
        let typeLabel = NSTextField(labelWithString: "Type:")
        let creatorLabel = NSTextField(labelWithString: "Creator:")
        typeLabel.alignment = .right
        creatorLabel.alignment = .right
        
        let grid = NSGridView(views: [
            [typeLabel, typeField],
            [creatorLabel, creatorField]
        ])
        grid.rowSpacing = 8
        grid.columnSpacing = 8
        grid.translatesAutoresizingMaskIntoConstraints = false
        grid.column(at: 0).xPlacement = .trailing
        grid.column(at: 1).xPlacement = .fill
        
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 280, height: 62))
        container.addSubview(grid)
        NSLayoutConstraint.activate([
            grid.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            grid.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            grid.topAnchor.constraint(equalTo: container.topAnchor),
            grid.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        alert.accessoryView = container
        
        let okButton = alert.buttons.first
        okButton?.isEnabled = (typeField.stringValue.count == 4 && creatorField.stringValue.count == 4)
        
        let delegate = FourCharacterCodeDelegate()
        delegate.okButton = okButton
        delegate.typeField = typeField
        delegate.creatorField = creatorField
        typeField.delegate = delegate
        creatorField.delegate = delegate
        typeCreatorDialogDelegate = delegate
        
        defer { typeCreatorDialogDelegate = nil }
        
        guard alert.runModal() == .alertFirstButtonReturn else { return nil }
        guard typeField.stringValue.count == 4, creatorField.stringValue.count == 4 else { return nil }
        return (typeField.stringValue, creatorField.stringValue)
    }

    func updateUI() {
        resetTreeAndReload()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        precondition(outlineView != nil, "VolumeDataViewController requires outlineView outlet to be connected in Storyboard.")
        
        outlineView.dataSource = self
        outlineView.delegate = self
        outlineView.target = self
        outlineView.action = #selector(handleOutlineSelectionChanged(_:))
        outlineView.actionDelegate = self
        
        outlineView.registerForDraggedTypes([.fileURL])
        outlineView.setDraggingSourceOperationMask(.copy, forLocal: false)
        outlineView.setDraggingSourceOperationMask([.move, .copy], forLocal: true)
        
        updateDetailLabels(with: nil)
        resetTreeAndReload()
    }
    
    @objc private func handleOutlineSelectionChanged(_ sender: Any?) {
        let row = outlineView.selectedRow
        if row >= 0, let node = outlineView.item(atRow: row) as? HFSNode {
            selectedNode = node
        } else {
            selectedNode = nil
        }
        updateDetailLabels(with: selectedNode)
    }
    
    @objc func exportSelectedItem(_ sender: Any?) {
        guard let selectedNode else {
            NSSound.beep()
            return
        }
        
        let panel = NSOpenPanel()
        panel.title = "Choose Destination Folder"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        
        guard panel.runModal() == .OK, let baseFolder = panel.url else { return }
        
        do {
            if selectedNode.info.isDirectory {
                let target = baseFolder.appendingPathComponent(selectedNode.info.name, isDirectory: true)
                _ = try copyOut(node: selectedNode, to: target)
            } else {
                _ = try copyOut(node: selectedNode, to: baseFolder)
            }
        } catch {
            presentErrorAlert(for: error)
        }
    }
    
    @objc func importItems(_ sender: Any?) {
        let panel = NSOpenPanel()
        panel.title = "Import Into Volume"
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.canCreateDirectories = false
        
        guard panel.runModal() == .OK else { return }
        
        let destinationPath = destinationDirectoryPathForImport()
        do {
            for url in panel.urls {
                try copyIn(hostURL: url, toParentHFSPath: destinationPath)
            }
            clearNodeCache(forDirectoryPath: destinationPath)
            outlineView.reloadData()
            refreshVolumeInfoDisplay()
        } catch {
            presentErrorAlert(for: error)
        }
    }
    
    @objc func deleteSelectedItems(_ sender: Any?) {
        let selected = normalizedDeleteList(from: selectedNodesFromOutline())
        guard !selected.isEmpty, let volume else {
            NSSound.beep()
            return
        }
        
        guard confirmDelete(nodes: selected) else { return }
        
        do {
            for node in selected {
                try volume.delete(node.info)
            }
            resetTreeAndReload()
            refreshVolumeInfoDisplay()
        } catch {
            presentErrorAlert(for: error)
        }
    }
    
    @objc func renameSelectedItem(_ sender: Any?) {
        guard let selectedNode, let volume else {
            NSSound.beep()
            return
        }
        
        guard let newName = promptForRename(currentName: selectedNode.info.name) else { return }
        
        do {
            try volume.rename(path: selectedNode.info.path, to: newName)
            clearNodeCache(forDirectoryPath: parentHFSPath(of: selectedNode.info.path))
            outlineView.reloadData()
            updateDetailLabels(with: nil)
            refreshVolumeInfoDisplay()
        } catch {
            presentErrorAlert(for: error)
        }
    }
    
    func setTransferMode(_ mode: HFSVolume.CopyMode) {
        transferMode = mode
    }
    
    @objc func changeTypeCreatorSelectedItem(_ sender: Any?) {
        guard let selectedNode, let volume else {
            NSSound.beep()
            return
        }
        guard !selectedNode.info.isDirectory else {
            NSSound.beep()
            return
        }
        
        let currentType = selectedNode.info.fileType.isEmpty ? "????" : selectedNode.info.fileType
        let currentCreator = selectedNode.info.fileCreator.isEmpty ? "????" : selectedNode.info.fileCreator
        
        guard let value = promptForTypeAndCreator(currentType: currentType, currentCreator: currentCreator) else {
            return
        }
        
        do {
            try volume.setTypeCreator(path: selectedNode.info.path, fileType: value.type, fileCreator: value.creator)
            let updated = try volume.attributes(of: selectedNode.info.path)
            let updatedNode = HFSNode(info: updated)
            self.selectedNode = updatedNode
            updateDetailLabels(with: updatedNode)
        } catch {
            presentErrorAlert(for: error)
        }
    }
    
    @objc func setBlessedFolderSelectedItem(_ sender: Any?) {
        guard let selectedNode, let volume else {
            NSSound.beep()
            return
        }
        guard selectedNode.info.isDirectory else {
            NSSound.beep()
            return
        }
        
        do {
            try volume.setBlessed(path: selectedNode.info.path)
            refreshVolumeInfoDisplay()
        } catch {
            presentErrorAlert(for: error)
        }
    }
}

extension VolumeDataViewController: NSUserInterfaceValidations {
    func validateUserInterfaceItem(_ item: NSValidatedUserInterfaceItem) -> Bool {
        if item.action == #selector(exportSelectedItem(_:)) {
            return selectedNode != nil
        }
        if item.action == #selector(importItems(_:)) {
            return volume != nil
        }
        if item.action == #selector(deleteSelectedItems(_:)) ||
            item.action == #selector(renameSelectedItem(_:)) {
            return selectedNode != nil
        }
        if item.action == #selector(changeTypeCreatorSelectedItem(_:)) {
            guard let selectedNode else { return false }
            return !selectedNode.info.isDirectory
        }
        if item.action == #selector(setBlessedFolderSelectedItem(_:)) {
            guard let selectedNode else { return false }
            return selectedNode.info.isDirectory
        }
        return true
    }
}

extension VolumeDataViewController: NSOutlineViewDataSource {
    func outlineView(_ outlineView: NSOutlineView,
                     draggingSession session: NSDraggingSession,
                     sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        if context == .withinApplication {
            return [.move, .copy]
        }
        return .copy
    }
    
    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        let node = node(for: item)
        ensureChildrenLoaded(for: node)
        return node?.children?.count ?? rootNodes.count
    }
    
    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        let node = node(for: item)
        ensureChildrenLoaded(for: node)
        return node?.children?[index] ?? rootNodes[index]
    }
    
    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        guard let node = item as? HFSNode else { return false }
        return node.info.isDirectory
    }
    
    func outlineView(_ outlineView: NSOutlineView,
                     writeItems items: [Any],
                     to pasteboard: NSPasteboard) -> Bool {
        let nodes = normalizedDeleteList(from: selectedNodes(from: items))
        guard !nodes.isEmpty else { return false }
        
        currentInternalDragPaths = normalizedTopLevelPaths(nodes.map(\.info.path))
        
        do {
            let urls = try exportedURLsForDrag(nodes: nodes)
            pasteboard.clearContents()
            return pasteboard.writeObjects(urls as [NSURL])
        } catch {
            currentInternalDragPaths = []
            presentErrorAlert(for: error)
            return false
        }
    }
    
    func outlineView(_ outlineView: NSOutlineView,
                     validateDrop info: NSDraggingInfo,
                     proposedItem item: Any?,
                     proposedChildIndex index: Int) -> NSDragOperation {
        guard let volume else { return [] }
        _ = volume
        
        let targetNode = item as? HFSNode
        if let targetNode, !targetNode.info.isDirectory {
            return []
        }
        if targetNode == nil && index == -1 {
            outlineView.setDropItem(nil, dropChildIndex: NSOutlineViewDropOnItemIndex)
        }
        
        let destinationPath = targetNode?.info.path ?? ":"
        if (info.draggingSource as AnyObject?) === outlineView, !currentInternalDragPaths.isEmpty {
            let internalPaths = currentInternalDragPaths
            if isInvalidInternalDrop(sourcePaths: internalPaths, destinationPath: destinationPath) {
                return []
            }
            let sourceMask = info.draggingSourceOperationMask
            if sourceMask.contains(.move) { return .move }
            if sourceMask.contains(.copy) { return .copy }
            return []
        }
        
        let classes: [AnyClass] = [NSURL.self]
        let options: [NSPasteboard.ReadingOptionKey: Any] = [.urlReadingFileURLsOnly: true]
        let urls = info.draggingPasteboard.readObjects(forClasses: classes, options: options) as? [URL]
        return (urls?.isEmpty == false) ? .copy : []
    }
    
    func outlineView(_ outlineView: NSOutlineView,
                     acceptDrop info: NSDraggingInfo,
                     item: Any?,
                     childIndex index: Int) -> Bool {
        let targetNode = item as? HFSNode
        let destinationPath = targetNode?.info.path ?? ":"
        
        if (info.draggingSource as AnyObject?) === outlineView, !currentInternalDragPaths.isEmpty {
            let sourcePaths = currentInternalDragPaths
            defer { currentInternalDragPaths = [] }
            guard let volume else { return false }
            if isInvalidInternalDrop(sourcePaths: sourcePaths, destinationPath: destinationPath) {
                NSSound.beep()
                return false
            }
            
            let isCopy = info.draggingSourceOperationMask.contains(.copy)
                && !info.draggingSourceOperationMask.contains(.move)
            
            do {
                if isCopy {
                    for sourcePath in sourcePaths {
                        try copyWithinVolume(sourcePath: sourcePath, toParentHFSPath: destinationPath)
                    }
                } else {
                    for sourcePath in sourcePaths {
                        if parentHFSPath(of: sourcePath) == destinationPath { continue }
                        try volume.move(path: sourcePath, toParentDirectory: destinationPath)
                    }
                }
                resetTreeAndReload()
                refreshVolumeInfoDisplay()
                return true
            } catch {
                presentErrorAlert(for: error)
                return false
            }
        }
        
        let classes: [AnyClass] = [NSURL.self]
        let options: [NSPasteboard.ReadingOptionKey: Any] = [.urlReadingFileURLsOnly: true]
        guard let urls = info.draggingPasteboard.readObjects(forClasses: classes, options: options) as? [URL],
              !urls.isEmpty else {
            return false
        }
        
        do {
            for url in urls {
                try copyIn(hostURL: url, toParentHFSPath: destinationPath)
            }
            clearNodeCache(forDirectoryPath: destinationPath)
            outlineView.reloadData()
            refreshVolumeInfoDisplay()
            return true
        } catch {
            presentErrorAlert(for: error)
            return false
        }
    }

    func outlineView(_ outlineView: NSOutlineView,
                     draggingSession session: NSDraggingSession,
                     endedAt screenPoint: NSPoint,
                     operation: NSDragOperation) {
        currentInternalDragPaths = []
    }
}

extension VolumeDataViewController: NSOutlineViewDelegate {
    func outlineView(_ outlineView: NSOutlineView,
                     viewFor tableColumn: NSTableColumn?,
                     item: Any) -> NSView? {
        guard let node = item as? HFSNode else { return nil }
        guard let columnID = tableColumn?.identifier else { return nil }
        
        if columnID == ColumnID.name {
            let identifier = NSUserInterfaceItemIdentifier("HFSNameCell")
            guard let cell = outlineView.makeView(withIdentifier: identifier, owner: self) as? NSTableCellView else {
                assertionFailure("Missing prototype cell with identifier HFSNameCell")
                return nil
            }
            
            cell.textField?.stringValue = sanitizedDisplayText(node.info.name)
            let symbolName = node.info.isDirectory ? "folder.fill" : "doc.fill"
            if let symbol = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil) {
                cell.imageView?.image = symbol
            }
            return cell
        }
        
        let identifier: NSUserInterfaceItemIdentifier
        if columnID == ColumnID.size {
            identifier = NSUserInterfaceItemIdentifier("HFSSizeCell")
        } else if columnID == ColumnID.modified {
            identifier = NSUserInterfaceItemIdentifier("HFSModifiedCell")
        } else {
            return nil
        }
        
        guard let cell = outlineView.makeView(withIdentifier: identifier, owner: self) as? NSTableCellView else {
            assertionFailure("Missing prototype cell with identifier \(identifier.rawValue)")
            return nil
        }
        
        if columnID == ColumnID.size {
            cell.textField?.stringValue = node.info.isDirectory ? "-" : sizeString(for: node.info)
        } else if columnID == ColumnID.modified {
            cell.textField?.stringValue = tableModifiedString(for: node.info)
        }
        
        return cell
    }
    
    func outlineViewItemDidExpand(_ notification: Notification) {
        guard let node = notification.userInfo?["NSObject"] as? HFSNode else { return }
        if node.info.isDirectory {
            clearNodeCache(forDirectoryPath: node.info.path)
            ensureChildrenLoaded(for: node)
        }
    }
    
    func outlineViewSelectionDidChange(_ notification: Notification) {
        handleOutlineSelectionChanged(nil)
    }
    
}

extension VolumeDataViewController: OutlineActionDelegate {
    func outlineDeleteBackward() {
        deleteSelectedItems(nil)
    }
}
