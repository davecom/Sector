//
//  Utility.swift
//  Sector
//
//  Created by Assistant on 2/4/26.
//

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

