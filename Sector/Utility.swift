//
//  Utility.swift
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

/// Presents an error alert to the user. Can be called from anywhere.
/// - Parameters:
///   - message: The main message text to display.
///   - informativeText: Additional descriptive text to help the user understand the error.
///   - title: Optional window title for the alert. Defaults to "Error".
public func presentErrorAlert(message: String, informativeText: String? = nil, title: String = "Error") {
    let presentBlock = {
        let alert = NSAlert()
        alert.alertStyle = .critical
        alert.messageText = title
        alert.informativeText = informativeText ?? message
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    DispatchQueue.main.async { presentBlock() }
}
/// Presents an error alert for a given HFSError using its user-facing message.
/// - Parameters:
///   - error: The HFSError to present.
///   - title: Optional window title for the alert. Defaults to "Error".
public func presentErrorAlert(for error: Error, title: String = "Error") {
    // Assuming HFSError exposes a userMessage suitable for display.
    presentErrorAlert(message: error.localizedDescription, informativeText: nil, title: title)
}

