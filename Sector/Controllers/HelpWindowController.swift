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

final class HelpWindowController: NSWindowController, NSWindowDelegate {
    private let requiresAcknowledgement: Bool
    private let helpViewController: HelpViewController
    
    init(requiresAcknowledgement: Bool, onAcknowledged: (() -> Void)? = nil) {
        self.requiresAcknowledgement = requiresAcknowledgement
        self.helpViewController = HelpViewController(
            requiresAcknowledgement: requiresAcknowledgement,
            onAcknowledged: onAcknowledged
        )
        
        let style: NSWindow.StyleMask = requiresAcknowledgement
            ? [.titled, .miniaturizable, .fullSizeContentView]
            : [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 820, height: 620),
            styleMask: style,
            backing: .buffered,
            defer: false
        )
        
        window.title = "Sector Help"
        window.contentViewController = helpViewController
        window.isReleasedWhenClosed = false
        window.center()
        window.toolbarStyle = .unified
        
        super.init(window: window)
        window.delegate = self
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        if requiresAcknowledgement && !helpViewController.hasAcknowledged {
            NSSound.beep()
            return false
        }
        return true
    }
}
