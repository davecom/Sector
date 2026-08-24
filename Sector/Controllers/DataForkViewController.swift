//
//  DataForkViewController.swift
//  Sector
//
//  Created by David Kopec on 8/23/26.
//

import Cocoa

class DataForkViewController: NSViewController {
    private static let maximumPreviewSize = 1_000_000

    @IBOutlet weak var dataSizeLabel: NSTextField!
    @IBOutlet weak var dataView: NSTextView!
    
    enum ViewType: Int {
        case macRoman = 0
        case hex = 1
        case unicode = 2
    }
    
    var viewType: ViewType = .macRoman {
        didSet { updateUI() }
    }
    
    var data: Data? {
        didSet {
            if isViewLoaded {
                updateUI()
            }
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        dataView.isEditable = false
        dataView.isSelectable = true
        updateUI()
    }

    private func updateUI() {
        dataSizeLabel.stringValue = "\(data?.count ?? 0) bytes"
        guard let data else {
            dataView.string = ""
            return
        }
        guard data.count <= Self.maximumPreviewSize else {
            dataView.string = "Too Long to Display..."
            return
        }

        switch viewType {
        case .hex:
            dataView.font = .monospacedSystemFont(ofSize: 10, weight: .regular)
            dataView.string = data.hexDump
        case .macRoman:
            dataView.font = .systemFont(ofSize: 10, weight: .regular)
            if let string = String(data: data, encoding: .macOSRoman) {
                dataView.string = string
            } else {
                dataView.string = ""
            }
        case .unicode:
            dataView.font = .systemFont(ofSize: 10, weight: .regular)
            if let string = String(data: data, encoding: .utf8) {
                dataView.string = string
            } else {
                dataView.string = ""
            }
        }
    }
    
    @objc @IBAction func changeViewType(_ sender: Any) {
        if let segmented = sender as? NSSegmentedControl {
            if let newType = ViewType(rawValue: segmented.selectedSegment) {
                viewType = newType
            }
        } else if let menuItem = sender as? NSMenuItem {
            // Use the menu item's tag to map to ViewType raw values
            if let newType = ViewType(rawValue: menuItem.tag) {
                viewType = newType
            }
        } else if let popUP = sender as? NSPopUpButton {
            if let newType = ViewType(rawValue: popUP.indexOfSelectedItem) {
                viewType = newType
            }
        }
    }
    
}
