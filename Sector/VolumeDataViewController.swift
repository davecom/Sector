//
//  VolumeViewController.swift
//  Sector
//
//  Created by David Kopec on 2/4/26.
//

import Cocoa
import HFSKit

private final class HFSNode {
    let info: HFSFileInfo
    var children: [HFSNode]?
    
    init(info: HFSFileInfo) {
        self.info = info
    }
}

private protocol OutlineActionDelegate: AnyObject {
    func outlineDeleteBackward()
}

private final class OperationOutlineView: NSOutlineView {
    weak var actionDelegate: OutlineActionDelegate?
    
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 51 || event.keyCode == 117 {
            actionDelegate?.outlineDeleteBackward()
            return
        }
        super.keyDown(with: event)
    }
}

class VolumeDataViewController: NSViewController {
    
    final var volume: HFSVolume?
    
    @IBOutlet weak var outlineView: NSOutlineView!
    @IBOutlet weak var detailNameValueLabel: NSTextField!
    @IBOutlet weak var detailPathValueLabel: NSTextField!
    @IBOutlet weak var detailKindValueLabel: NSTextField!
    @IBOutlet weak var detailSizeValueLabel: NSTextField!
    @IBOutlet weak var detailCreatedValueLabel: NSTextField!
    @IBOutlet weak var detailModifiedValueLabel: NSTextField!
    @IBOutlet weak var detailTypeCreatorValueLabel: NSTextField!
    
    private var rootNodes: [HFSNode] = []
    private var selectedNode: HFSNode?
    private var detailRowLabels: [String: NSTextField] = [:]
    private var hasConfiguredColumns = false
    
    private static let byteFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB, .useTB]
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
            detailCreatedValueLabel?.stringValue = "-"
            detailModifiedValueLabel?.stringValue = "-"
            detailTypeCreatorValueLabel?.stringValue = "-"
            return
        }
        
        let info = node.info
        detailNameValueLabel?.stringValue = info.name
        detailPathValueLabel?.stringValue = info.path
        detailKindValueLabel?.stringValue = info.isDirectory ? "Folder" : "File"
        detailSizeValueLabel?.stringValue = info.isDirectory ? "-" : sizeString(for: info)
        detailCreatedValueLabel?.stringValue = formatDateIfMeaningful(info.created)
        detailModifiedValueLabel?.stringValue = formatDateIfMeaningful(info.modified)
        
        if info.isDirectory {
            detailTypeCreatorValueLabel?.stringValue = "-"
        } else {
            let type = info.fileType.isEmpty ? "????" : info.fileType
            let creator = info.fileCreator.isEmpty ? "????" : info.fileCreator
            detailTypeCreatorValueLabel?.stringValue = "\(type) / \(creator)"
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
    
    private func configureOutlineColumns() {
        guard let outlineView else { return }
        guard !hasConfiguredColumns else { return }
        
        outlineView.autosaveTableColumns = false
        outlineView.outlineTableColumn = nil
        for existing in outlineView.tableColumns {
            outlineView.removeTableColumn(existing)
        }
        outlineView.columnAutoresizingStyle = .noColumnAutoresizing
        
        let name = NSTableColumn(identifier: ColumnID.name)
        name.title = "Name"
        name.minWidth = 320
        name.width = 500
        
        let size = NSTableColumn(identifier: ColumnID.size)
        size.title = "Size"
        size.minWidth = 90
        size.width = 120
        
        let modified = NSTableColumn(identifier: ColumnID.modified)
        modified.title = "Modified"
        modified.minWidth = 160
        modified.width = 190
        
        outlineView.addTableColumn(name)
        outlineView.addTableColumn(size)
        outlineView.addTableColumn(modified)
        outlineView.outlineTableColumn = name
        hasConfiguredColumns = true
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
    
    private func copyOut(node: HFSNode, to hostPath: URL) throws {
        guard let volume else { return }
        if node.info.isDirectory {
            try volume.copyOutDirectory(hfsPath: node.info.path, toHostDirectory: hostPath)
        } else {
            try volume.copyOut(hfsPath: node.info.path, toHostPath: hostPath)
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
            try volume.copyInDirectory(hostDirectory: hostURL, toHFSPath: destinationPath)
        } else {
            try volume.copyIn(hostPath: hostURL, toHFSPath: destinationPath)
        }
    }
    
    private func existingItem(named name: String, inDirectory directoryPath: String) throws -> HFSFileInfo? {
        guard let volume else { return nil }
        return try volume.list(directory: directoryPath).first {
            $0.name.localizedCaseInsensitiveCompare(name) == .orderedSame
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
            let hostURL = base.appendingPathComponent(node.info.name, isDirectory: node.info.isDirectory)
            try copyOut(node: node, to: hostURL)
            urls.append(hostURL)
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

    func updateUI() {
        resetTreeAndReload()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        if outlineView == nil {
            configureProgrammaticUI()
        }
        
        outlineView?.dataSource = self
        outlineView?.delegate = self
        outlineView?.target = self
        outlineView?.action = #selector(handleOutlineSelectionChanged(_:))
        configureOutlineColumns()
        
        outlineView?.registerForDraggedTypes([.fileURL])
        outlineView?.setDraggingSourceOperationMask(.copy, forLocal: false)
        outlineView?.setDraggingSourceOperationMask([], forLocal: true)
        
        updateDetailLabels(with: nil)
        resetTreeAndReload()
    }
    
    private func configureProgrammaticUI() {
        let container = NSView(frame: view.bounds)
        container.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(container)
        
        NSLayoutConstraint.activate([
            container.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            container.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            container.topAnchor.constraint(equalTo: view.topAnchor),
            container.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        let scroll = NSScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.borderType = .bezelBorder
        scroll.hasVerticalScroller = true
        
        let outline = OperationOutlineView()
        outline.headerView = NSTableHeaderView()
        outline.usesAlternatingRowBackgroundColors = false
        outline.allowsMultipleSelection = true
        outline.rowHeight = 20
        outline.actionDelegate = self
        
        scroll.documentView = outline
        container.addSubview(scroll)
        self.outlineView = outline
        (outlineView as? OperationOutlineView)?.actionDelegate = self
        
        let detailStack = NSStackView()
        detailStack.translatesAutoresizingMaskIntoConstraints = false
        detailStack.orientation = .vertical
        detailStack.alignment = .leading
        detailStack.spacing = 4
        container.addSubview(detailStack)
        
        func addDetailRow(key: String, title: String) -> NSTextField {
            let row = NSStackView()
            row.orientation = .horizontal
            row.alignment = .firstBaseline
            row.spacing = 6
            
            let titleLabel = NSTextField(labelWithString: "\(title):")
            titleLabel.textColor = .secondaryLabelColor
            titleLabel.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
            titleLabel.setContentHuggingPriority(.required, for: .horizontal)
            
            let valueLabel = NSTextField(labelWithString: "-")
            valueLabel.lineBreakMode = .byTruncatingMiddle
            valueLabel.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
            
            row.addArrangedSubview(titleLabel)
            row.addArrangedSubview(valueLabel)
            detailStack.addArrangedSubview(row)
            detailRowLabels[key] = valueLabel
            return valueLabel
        }
        
        detailNameValueLabel = addDetailRow(key: "name", title: "Name")
        detailPathValueLabel = addDetailRow(key: "path", title: "Path")
        detailKindValueLabel = addDetailRow(key: "kind", title: "Kind")
        detailSizeValueLabel = addDetailRow(key: "size", title: "Size")
        detailCreatedValueLabel = addDetailRow(key: "created", title: "Created")
        detailModifiedValueLabel = addDetailRow(key: "modified", title: "Modified")
        detailTypeCreatorValueLabel = addDetailRow(key: "typecreator", title: "Type/Creator")
        
        NSLayoutConstraint.activate([
            scroll.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            scroll.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
            scroll.topAnchor.constraint(equalTo: container.topAnchor, constant: 12),
            scroll.bottomAnchor.constraint(equalTo: detailStack.topAnchor, constant: -10),
            
            detailStack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            detailStack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
            detailStack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -10),
            
            detailStack.heightAnchor.constraint(greaterThanOrEqualToConstant: 92)
        ])
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
            let target = baseFolder.appendingPathComponent(selectedNode.info.name, isDirectory: selectedNode.info.isDirectory)
            try copyOut(node: selectedNode, to: target)
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
        return true
    }
}

extension VolumeDataViewController: NSOutlineViewDataSource {
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
        let nodes = selectedNodes(from: items)
        guard !nodes.isEmpty else { return false }
        
        do {
            let urls = try exportedURLsForDrag(nodes: nodes)
            pasteboard.clearContents()
            return pasteboard.writeObjects(urls as [NSURL])
        } catch {
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
}

extension VolumeDataViewController: NSOutlineViewDelegate {
    func outlineView(_ outlineView: NSOutlineView,
                     viewFor tableColumn: NSTableColumn?,
                     item: Any) -> NSView? {
        guard let node = item as? HFSNode else { return nil }
        guard let columnID = tableColumn?.identifier else { return nil }
        
        if columnID == ColumnID.name {
            let identifier = NSUserInterfaceItemIdentifier("HFSNameCell")
            let cell = outlineView.makeView(withIdentifier: identifier, owner: self) as? NSTableCellView ?? {
                let cell = NSTableCellView()
                cell.identifier = identifier
                
                let imageView = NSImageView()
                imageView.translatesAutoresizingMaskIntoConstraints = false
                imageView.imageScaling = .scaleProportionallyDown
                cell.imageView = imageView
                cell.addSubview(imageView)
                
                let textField = NSTextField(labelWithString: "")
                textField.translatesAutoresizingMaskIntoConstraints = false
                textField.lineBreakMode = .byTruncatingTail
                textField.isEditable = false
                textField.isBordered = false
                textField.drawsBackground = false
                cell.textField = textField
                cell.addSubview(textField)
                
                NSLayoutConstraint.activate([
                    imageView.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 4),
                    imageView.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
                    imageView.widthAnchor.constraint(equalToConstant: 16),
                    imageView.heightAnchor.constraint(equalToConstant: 16),
                    textField.leadingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: 6),
                    textField.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -4),
                    textField.centerYAnchor.constraint(equalTo: cell.centerYAnchor)
                ])
                
                return cell
            }()
            
            cell.textField?.stringValue = node.info.name
            let symbolName = node.info.isDirectory ? "folder.fill" : "doc.fill"
            if let symbol = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil) {
                cell.imageView?.image = symbol
            }
            return cell
        }
        
        let identifier = NSUserInterfaceItemIdentifier("HFSTextCell-\(columnID.rawValue)")
        let cell = outlineView.makeView(withIdentifier: identifier, owner: self) as? NSTableCellView ?? {
            let cell = NSTableCellView()
            cell.identifier = identifier
            let textField = NSTextField(labelWithString: "")
            textField.translatesAutoresizingMaskIntoConstraints = false
            textField.lineBreakMode = .byTruncatingTail
            textField.isEditable = false
            textField.isBordered = false
            textField.drawsBackground = false
            cell.textField = textField
            cell.addSubview(textField)
            
            NSLayoutConstraint.activate([
                textField.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 6),
                textField.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -6),
                textField.centerYAnchor.constraint(equalTo: cell.centerYAnchor)
            ])
            return cell
        }()
        
        if columnID == ColumnID.size {
            cell.textField?.alignment = .right
            cell.textField?.stringValue = node.info.isDirectory ? "-" : sizeString(for: node.info)
        } else if columnID == ColumnID.modified {
            cell.textField?.alignment = .left
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
