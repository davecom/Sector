//
//  NewImageOptionsController.swift
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

final class NewImageOptionsController: NSObject, NSTextFieldDelegate {
    static let minBytes: UInt64 = 800 * 1024
    static let maxBytes: UInt64 = 2 * 1024 * 1024 * 1024
    static let defaultBytes: UInt64 = 8 * 1024 * 1024
    static let maxVolumeNameLength = 27
    
    let containerView: NSView
    let sizeSlider: NSSlider
    let sizeValueLabel: NSTextField
    let volumeNameField: NSTextField
    
    override init() {
        sizeSlider = NSSlider(value: Double(Self.defaultBytes),
                              minValue: Double(Self.minBytes),
                              maxValue: Double(Self.maxBytes),
                              target: nil,
                              action: nil)
        sizeSlider.isContinuous = true
        
        sizeValueLabel = NSTextField(labelWithString: "")
        sizeValueLabel.alignment = .left
        
        volumeNameField = NSTextField(string: "Untitled")
        
        let sizeLabel = NSTextField(labelWithString: "Image Size:")
        sizeLabel.alignment = .right
        sizeLabel.setContentHuggingPriority(.required, for: .horizontal)
        sizeLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        let volumeLabel = NSTextField(labelWithString: "Volume Name:")
        volumeLabel.alignment = .right
        volumeLabel.setContentHuggingPriority(.required, for: .horizontal)
        volumeLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        let sizeRow = NSStackView(views: [sizeLabel, sizeSlider])
        sizeRow.orientation = .horizontal
        sizeRow.alignment = .firstBaseline
        sizeRow.spacing = 10

        let sliderIndent = NSView(frame: .zero)
        sliderIndent.translatesAutoresizingMaskIntoConstraints = false
        sliderIndent.setContentHuggingPriority(.required, for: .horizontal)
        sliderIndent.setContentCompressionResistancePriority(.required, for: .horizontal)
        
        let valueRow = NSStackView(views: [sliderIndent, sizeValueLabel])
        valueRow.orientation = .horizontal
        valueRow.alignment = .firstBaseline
        valueRow.spacing = 10

        let volumeRow = NSStackView(views: [volumeLabel, volumeNameField])
        volumeRow.orientation = .horizontal
        volumeRow.alignment = .firstBaseline
        volumeRow.spacing = 10

        let root = NSStackView(views: [sizeRow, valueRow, volumeRow])
        root.orientation = .vertical
        root.alignment = .leading
        root.spacing = 12
        root.translatesAutoresizingMaskIntoConstraints = false
        root.edgeInsets = NSEdgeInsets(top: 10, left: 12, bottom: 10, right: 12)

        containerView = NSView(frame: NSRect(x: 0, y: 0, width: 430, height: 130))
        containerView.addSubview(root)

        sizeSlider.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        sizeSlider.setContentHuggingPriority(.defaultLow, for: .horizontal)
        sizeValueLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        volumeNameField.setContentCompressionResistancePriority(.required, for: .horizontal)

        NSLayoutConstraint.activate([
            root.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            root.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            root.topAnchor.constraint(equalTo: containerView.topAnchor),
            root.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),

            sizeLabel.widthAnchor.constraint(equalToConstant: 130),
            volumeLabel.widthAnchor.constraint(equalTo: sizeLabel.widthAnchor),
            sliderIndent.widthAnchor.constraint(equalTo: sizeLabel.widthAnchor),

            sizeSlider.widthAnchor.constraint(equalToConstant: 260),
            volumeNameField.widthAnchor.constraint(equalToConstant: 260),
            containerView.widthAnchor.constraint(greaterThanOrEqualToConstant: 420)
        ])
        
        super.init()
        
        sizeSlider.target = self
        sizeSlider.action = #selector(sizeChanged(_:))
        volumeNameField.delegate = self
        updateSizeLabel()
    }
    
    var selectedSizeBytes: UInt64 {
        UInt64(sizeSlider.doubleValue.rounded())
    }
    
    var volumeName: String {
        volumeNameField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    var isValid: Bool {
        let size = selectedSizeBytes
        return size >= Self.minBytes
            && size <= Self.maxBytes
            && !volumeName.isEmpty
            && volumeName.count <= Self.maxVolumeNameLength
    }
    
    @objc private func sizeChanged(_ sender: NSSlider) {
        updateSizeLabel()
    }
    
    private func updateSizeLabel() {
        let sizeString = Self.binarySizeString(selectedSizeBytes)
        let minString = Self.binarySizeString(Self.minBytes)
        let maxString = Self.binarySizeString(Self.maxBytes)
        sizeValueLabel.stringValue = "\(sizeString)  (min \(minString), max \(maxString))"
    }
    
    private static func binarySizeString(_ bytes: UInt64) -> String {
        let kib: Double = 1024
        let mib: Double = 1024 * 1024
        let gib: Double = 1024 * 1024 * 1024
        let value = Double(bytes)
        
        if value >= gib {
            return String(format: "%.2f GiB", value / gib)
        }
        if value >= mib {
            return String(format: "%.1f MiB", value / mib)
        }
        return String(format: "%.0f KiB", value / kib)
    }
    
    func control(_ control: NSControl,
                 textView: NSTextView,
                 shouldChangeTextIn affectedCharRange: NSRange,
                 replacementString: String?) -> Bool {
        guard control === volumeNameField else { return true }
        let current = volumeNameField.stringValue as NSString
        let replacement = replacementString ?? ""
        let next = current.replacingCharacters(in: affectedCharRange, with: replacement)
        return next.count <= Self.maxVolumeNameLength
    }
    
    func controlTextDidChange(_ obj: Notification) {
        guard let field = obj.object as? NSTextField, field === volumeNameField else { return }
        if field.stringValue.count > Self.maxVolumeNameLength {
            field.stringValue = String(field.stringValue.prefix(Self.maxVolumeNameLength))
        }
    }
}
