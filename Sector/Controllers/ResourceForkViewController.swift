//
//  ResourceForkViewController.swift
//  Sector
//
//  Created by David Kopec on 8/23/26.
//

import Cocoa
import HFSKit

class ResourceForkViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate {
    private enum ResourceColumn: String {
        case id
        case type
        case name
        case length
    }

    
    @IBOutlet weak var resourcesTableView: NSTableView!
    private var resourceDataPopover: NSPopover?
    private var keyDownMonitor: Any?
    private var displayedResources: [Resource] = []

    var resources: [Resource] = [] {
        didSet {
            displayedResources = sortedResources(resources, by: .id, ascending: true)
            if isViewLoaded {
                resourcesTableView.sortDescriptors = [NSSortDescriptor(key: ResourceColumn.id.rawValue, ascending: true)]
                resourcesTableView.reloadData()
            }
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        resourcesTableView.dataSource = self
        resourcesTableView.delegate = self
        resourcesTableView.target = self
        resourcesTableView.doubleAction = #selector(showSelectedResourceData(_:))
        resourcesTableView.tableColumns.forEach {
            $0.isEditable = false
            if let column = ResourceColumn(rawValue: $0.title.lowercased()) {
                $0.sortDescriptorPrototype = NSSortDescriptor(key: column.rawValue, ascending: true)
            }
        }
        resourcesTableView.sortDescriptors = [NSSortDescriptor(key: ResourceColumn.id.rawValue, ascending: true)]
        displayedResources = sortedResources(resources, by: .id, ascending: true)
        keyDownMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self,
                  self.resourcesTableView.window?.firstResponder === self.resourcesTableView,
                  event.charactersIgnoringModifiers == " ",
                  self.resourcesTableView.selectedRow >= 0 else {
                return event
            }

            self.showSelectedResourceData(nil)
            return nil
        }
        resourcesTableView.reloadData()
    }

    deinit {
        if let keyDownMonitor {
            NSEvent.removeMonitor(keyDownMonitor)
        }
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        displayedResources.count
    }

    func tableView(_ tableView: NSTableView,
                   viewFor tableColumn: NSTableColumn?,
                   row: Int) -> NSView?
    {
        guard let tableColumn else { return nil }

        let cell = NSTableCellView()
        let label = NSTextField(labelWithString: "")
        label.lineBreakMode = .byTruncatingTail
        label.translatesAutoresizingMaskIntoConstraints = false
        cell.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 4),
            label.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -4),
            label.centerYAnchor.constraint(equalTo: cell.centerYAnchor)
        ])
        cell.textField = label

        label.stringValue = value(for: displayedResources[row], in: tableColumn)
        return cell
    }

    func tableView(_ tableView: NSTableView,
                   sortDescriptorsDidChange oldDescriptors: [NSSortDescriptor])
    {
        guard let descriptor = tableView.sortDescriptors.first,
              let key = descriptor.key,
              let column = ResourceColumn(rawValue: key) else {
            return
        }
        displayedResources = sortedResources(resources, by: column, ascending: descriptor.ascending)
        tableView.reloadData()
    }

    @objc private func showSelectedResourceData(_ sender: Any?) {
        let row = resourcesTableView.selectedRow
        guard displayedResources.indices.contains(row) else { return }

        let popover = NSPopover()
        popover.behavior = .transient
        popover.contentSize = NSSize(width: 600, height: 400)
        popover.contentViewController = ResourceDataViewController(data: displayedResources[row].data)
        resourceDataPopover?.performClose(nil)
        resourceDataPopover = popover
        popover.show(
            relativeTo: resourcesTableView.frameOfCell(atColumn: 0, row: row),
            of: resourcesTableView,
            preferredEdge: .maxX
        )
    }

    private func value(for resource: Resource, in tableColumn: NSTableColumn) -> String {
        switch tableColumn.title.lowercased() {
        case "id":
            return String(resource.id)
        case "type":
            return resource.type
        case "name":
            return resource.name ?? ""
        case "length":
            return "\(resource.length)"
        default:
            return ""
        }
    }

    private func sortedResources(_ resources: [Resource],
                                 by column: ResourceColumn,
                                 ascending: Bool) -> [Resource]
    {
        resources.sorted { lhs, rhs in
            let result: ComparisonResult
            switch column {
            case .id:
                result = lhs.id == rhs.id ? .orderedSame : (lhs.id < rhs.id ? .orderedAscending : .orderedDescending)
            case .type:
                result = lhs.type.localizedStandardCompare(rhs.type)
            case .name:
                result = (lhs.name ?? "").localizedStandardCompare(rhs.name ?? "")
            case .length:
                result = lhs.length == rhs.length ? .orderedSame : (lhs.length < rhs.length ? .orderedAscending : .orderedDescending)
            }

            if result == .orderedSame {
                return ascending ? lhs.id < rhs.id : lhs.id > rhs.id
            }
            return ascending ? result == .orderedAscending : result == .orderedDescending
        }
    }
}

private final class ResourceDataViewController: NSViewController {
    private static let maximumPreviewSize = 1_000_000

    private enum ViewType: Int {
        case macRoman
        case hex
        case unicode
    }

    private let data: Data
    private let viewTypePopUpButton = NSPopUpButton(frame: .zero, pullsDown: false)
    private let copyButton = NSButton(title: "Copy", target: nil, action: nil)
    private let textView = NSTextView()
    private var viewType: ViewType = .macRoman {
        didSet { updateTextView() }
    }

    init(data: Data) {
        self.data = data
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        let contentView = NSView(frame: NSRect(x: 0, y: 0, width: 600, height: 400))
        contentView.translatesAutoresizingMaskIntoConstraints = false

        viewTypePopUpButton.addItems(withTitles: ["MacRoman", "Hex", "Unicode"])
        viewTypePopUpButton.selectItem(at: ViewType.macRoman.rawValue)
        viewTypePopUpButton.target = self
        viewTypePopUpButton.action = #selector(changeViewType(_:))
        viewTypePopUpButton.translatesAutoresizingMaskIntoConstraints = false

        copyButton.target = self
        copyButton.action = #selector(copyDisplayedText(_:))
        copyButton.bezelStyle = .rounded
        copyButton.translatesAutoresizingMaskIntoConstraints = false

        textView.isEditable = false
        textView.isSelectable = true
        textView.selectedTextAttributes = [
            .backgroundColor: NSColor.selectedTextBackgroundColor,
            .foregroundColor: NSColor.selectedTextColor
        ]
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = true
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = false
        textView.frame = NSRect(x: 0, y: 0, width: 576, height: 340)

        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .bezelBorder
        scrollView.documentView = textView
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(viewTypePopUpButton)
        contentView.addSubview(copyButton)
        contentView.addSubview(scrollView)
        NSLayoutConstraint.activate([
            viewTypePopUpButton.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            viewTypePopUpButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            copyButton.trailingAnchor.constraint(equalTo: viewTypePopUpButton.leadingAnchor, constant: -8),
            copyButton.centerYAnchor.constraint(equalTo: viewTypePopUpButton.centerYAnchor),
            scrollView.topAnchor.constraint(equalTo: viewTypePopUpButton.bottomAnchor, constant: 8),
            scrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            scrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            scrollView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12)
        ])
        view = contentView
        updateTextView()
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        view.window?.makeFirstResponder(textView)
    }

    @objc private func changeViewType(_ sender: NSPopUpButton) {
        guard let viewType = ViewType(rawValue: sender.indexOfSelectedItem) else { return }
        self.viewType = viewType
    }

    @objc private func copyDisplayedText(_ sender: Any?) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(textView.string, forType: .string)
    }

    private func updateTextView() {
        guard data.count <= Self.maximumPreviewSize else {
            textView.font = .systemFont(ofSize: 10, weight: .regular)
            textView.string = "Too Long to Display..."
            return
        }

        switch viewType {
        case .hex:
            textView.font = .monospacedSystemFont(ofSize: 10, weight: .regular)
            textView.string = data.hexDump
        case .macRoman:
            textView.font = .systemFont(ofSize: 10, weight: .regular)
            textView.string = String(data: data, encoding: .macOSRoman) ?? ""
        case .unicode:
            textView.font = .systemFont(ofSize: 10, weight: .regular)
            textView.string = String(data: data, encoding: .utf8) ?? ""
        }
    }
}
