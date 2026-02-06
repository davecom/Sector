import Cocoa

final class HelpViewController: NSViewController {
    private let requiresAcknowledgement: Bool
    private let onAcknowledged: (() -> Void)?
    
    private let scrollView = NSScrollView(frame: .zero)
    private let textView = NSTextView(frame: .zero)
    private let acknowledgementCheckbox = NSButton(checkboxWithTitle: "I have read and acknowledge the legal notice above.", target: nil, action: nil)
    private let closeButton = NSButton(title: "Close", target: nil, action: nil)
    private let continueButton = NSButton(title: "I Agree and Continue", target: nil, action: nil)
    
    private(set) var hasAcknowledged = false
    
    init(requiresAcknowledgement: Bool, onAcknowledged: (() -> Void)? = nil) {
        self.requiresAcknowledgement = requiresAcknowledgement
        self.onAcknowledged = onAcknowledged
        super.init(nibName: nil, bundle: nil)
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func loadView() {
        self.view = NSView(frame: NSRect(x: 0, y: 0, width: 820, height: 620))
        configureUI()
        loadHelpContent()
    }
    
    private func configureUI() {
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        view.addSubview(scrollView)
        
        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: 10, height: 12)
        textView.textContainer?.widthTracksTextView = true
        textView.linkTextAttributes = [.foregroundColor: NSColor.systemTeal]
        scrollView.documentView = textView
        
        acknowledgementCheckbox.translatesAutoresizingMaskIntoConstraints = false
        acknowledgementCheckbox.target = self
        acknowledgementCheckbox.action = #selector(handleAcknowledgeToggle(_:))
        acknowledgementCheckbox.state = .off
        acknowledgementCheckbox.isHidden = !requiresAcknowledgement
        acknowledgementCheckbox.font = NSFont.systemFont(ofSize: 12)
        view.addSubview(acknowledgementCheckbox)
        
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.bezelStyle = .rounded
        closeButton.keyEquivalent = "\r"
        closeButton.target = self
        closeButton.action = #selector(handleClose(_:))
        closeButton.isHidden = requiresAcknowledgement
        view.addSubview(closeButton)
        
        continueButton.translatesAutoresizingMaskIntoConstraints = false
        continueButton.bezelStyle = .rounded
        continueButton.keyEquivalent = "\r"
        continueButton.target = self
        continueButton.action = #selector(handleContinue(_:))
        continueButton.isEnabled = false
        continueButton.isHidden = !requiresAcknowledgement
        view.addSubview(continueButton)
        
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            
            acknowledgementCheckbox.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 18),
            acknowledgementCheckbox.trailingAnchor.constraint(lessThanOrEqualTo: continueButton.leadingAnchor, constant: -12),
            acknowledgementCheckbox.topAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: 10),
            
            closeButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -18),
            closeButton.topAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: 10),
            closeButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -12),
            
            continueButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -18),
            continueButton.topAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: 10),
            continueButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -12),
            
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: requiresAcknowledgement ? -52 : -48)
        ])
    }
    
    private func loadHelpContent() {
        guard let helpURL = Bundle.main.url(forResource: "HelpContent", withExtension: "html"),
              let disclaimerURL = Bundle.main.url(forResource: "LegalDisclaimer", withExtension: "txt") else {
            textView.string = "Help content could not be loaded."
            return
        }
        
        do {
            let htmlTemplate = try String(contentsOf: helpURL, encoding: .utf8)
            let disclaimer = try String(contentsOf: disclaimerURL, encoding: .utf8)
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "&", with: "&amp;")
                .replacingOccurrences(of: "<", with: "&lt;")
                .replacingOccurrences(of: ">", with: "&gt;")
            let html = htmlTemplate.replacingOccurrences(of: "{{DISCLAIMER}}", with: disclaimer)
            let data = Data(html.utf8)
            let attributed = try NSAttributedString(
                data: data,
                options: [
                    .documentType: NSAttributedString.DocumentType.html,
                    .characterEncoding: String.Encoding.utf8.rawValue
                ],
                documentAttributes: nil
            )
            textView.textStorage?.setAttributedString(applyAppStyle(to: attributed))
        } catch {
            textView.string = "Help content could not be loaded."
        }
    }
    
    private func applyAppStyle(to attributed: NSAttributedString) -> NSAttributedString {
        let styled = NSMutableAttributedString(attributedString: attributed)
        let fullRange = NSRange(location: 0, length: styled.length)
        
        styled.enumerateAttribute(.font, in: fullRange) { value, range, _ in
            let original = (value as? NSFont) ?? NSFont.systemFont(ofSize: 14)
            let traits = NSFontManager.shared.traits(of: original)
            let isBold = traits.contains(.boldFontMask)
            let pointSize = original.pointSize
            let newFont: NSFont
            
            if pointSize >= 26 {
                newFont = NSFont.systemFont(ofSize: 34, weight: .bold)
            } else if pointSize >= 20 {
                newFont = NSFont.systemFont(ofSize: 20, weight: .semibold)
            } else if pointSize <= 12.5 {
                newFont = NSFont.systemFont(ofSize: 13, weight: .regular)
            } else {
                newFont = NSFont.systemFont(ofSize: 14, weight: isBold ? .semibold : .regular)
            }
            styled.addAttribute(.font, value: newFont, range: range)
            styled.addAttribute(.foregroundColor, value: NSColor.labelColor, range: range)
        }
        
        let whole = styled.string as NSString
        whole.enumerateSubstrings(in: NSRange(location: 0, length: whole.length), options: .byParagraphs) { _, paragraphRange, _, _ in
            let paragraph = (whole.substring(with: paragraphRange) as NSString).trimmingCharacters(in: .whitespacesAndNewlines)
            let style = NSMutableParagraphStyle()
            style.lineSpacing = 3
            style.paragraphSpacing = 8
            if paragraph.hasPrefix("•") {
                style.firstLineHeadIndent = 10
                style.headIndent = 10
            }
            styled.addAttribute(.paragraphStyle, value: style, range: paragraphRange)
        }
        
        if let legalRange = styled.string.range(of: "Use of this software is at your own risk.") {
            let ns = NSRange(legalRange, in: styled.string)
            let tail = NSRange(location: ns.location, length: styled.length - ns.location)
            styled.addAttribute(.foregroundColor, value: NSColor.secondaryLabelColor, range: tail)
            styled.addAttribute(.font, value: NSFont.systemFont(ofSize: 13), range: tail)
        }
        
        return styled
    }
    
    @objc private func handleAcknowledgeToggle(_ sender: NSButton) {
        let acknowledged = sender.state == .on
        continueButton.isEnabled = acknowledged
    }
    
    @objc private func handleClose(_ sender: Any?) {
        self.view.window?.close()
    }
    
    @objc private func handleContinue(_ sender: Any?) {
        guard acknowledgementCheckbox.state == .on else {
            NSSound.beep()
            return
        }
        hasAcknowledged = true
        onAcknowledged?()
        self.view.window?.close()
    }
}
