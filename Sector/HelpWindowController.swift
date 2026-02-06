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
