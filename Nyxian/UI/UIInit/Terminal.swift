/*
 SPDX-License-Identifier: LicenseRef-EPSL-1.1

 Copyright (C) 2025 - 2026 emexlab

 This file is part of Nyxian.

 Licensed under the emexLabs Public Source License, version 1.1
 (EPSL 1.1).

 Private use and modification are permitted under the license.
 Redistribution of source or binaries, modified or unmodified,
 requires prior written permission from emexLabs.

 External deployment is subject to the source-availability
 requirements and other conditions of the license.

 Provided "AS IS", without warranty, to the extent permitted by law.

 See LICENSE for the full license terms.
*/

/*
 Fork doctoralvarez/Nyxian — version 1.5.0
 Changelog:
  - 1.5.0 (2026-11-09): no preview pops up while Cell Outputs is open (the
    figures show there).
  - 1.4.0 (2026-11-08): a program can ask for a preview of files
    (ESC ] 7770 ; nyxian-preview ; paths BEL — Python's plt.show()): the
    sequence is taken out of the output and the files open in Quick Look.
  - 1.3.2 (2026-11-08): key bar: symbol keys have one fixed width (the paste
    key was very wide on iPhone), the fixed keys never stretch, and the bar
    has a fixed height (with self-sizing it sometimes came back with no
    height and did not show).
  - 1.3.1 (2026-11-08): the key bar's paste key marks the text as pasted
    (bracketed paste) when the program asked for it, like the system Paste.
  - 1.3.0 (2026-11-08): key bar scrolls sideways and has many more keys
    (Home/End, paste, clear, page up/down, A−/A+ font size, ^A ^E ^K ^W ^Z
    ^\\, programming symbols); hide-keyboard and a red ✕ that closes the
    window stay fixed on the right. Key bar keys go the same way as typed
    keys. Font size per window (forkApplyFontSize, forkFontSizeDefaultsKey).
  - 1.2.0 (2026-11-08): the terminal shrinks to the part of its window above
    the keyboard (and its key bar), so the line being typed stays visible and
    older output can be scrolled (forkKeyboardConstraint).
  - 1.1.0 (2026-11-07): Return key in the key bar (sends CR, like the
    keyboard's Return) as a second way to enter a line.
  - 1.0.0 (2026-11-07): Nyxian's own key bar above the keyboard (esc, tab,
    Ctrl-C, Ctrl-D, arrows and a button that hides the keyboard). SwiftTerm's
    keyboard button switched to its own key panel instead of closing the
    keyboard (ForkTerminalKeyBar).
*/

import SwiftTerm
import UIKit

@objc protocol TerminalViewDelegateObjC: AnyObject {
    @objc optional func sizeChanged(source: TerminalView, newCols: Int, newRows: Int)
    @objc optional func setTerminalTitle(source: TerminalView, title: String)
    @objc optional func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?)
    @objc optional func send(source: TerminalView, data: Data)
    @objc optional func scrolled(source: TerminalView, position: Double)
    @objc optional func requestOpenLink(source: TerminalView, link: String, params: [String: String])
    @objc optional func bell(source: TerminalView)
    @objc optional func clipboardCopy(source: TerminalView, content: Data)
    @objc optional func iTermContent(source: TerminalView, content: Data)
    @objc optional func rangeChanged(source: TerminalView, startY: Int, endY: Int)
}

@objc class TerminalViewObjC: TerminalView {
    @objc var ttyHandle: FileHandle?
    
    private var _objcDelegateAdapter: ObjCDelegateAdapter?
    @objc public weak var objcDelegate: (any TerminalViewDelegateObjC)? {
        didSet {
            if let d = objcDelegate {
                _objcDelegateAdapter = ObjCDelegateAdapter(d)
                self.terminalDelegate = _objcDelegateAdapter
            } else {
                self.delegate = nil
            }
        }
    }
    
    private class ObjCDelegateAdapter: TerminalViewDelegate {
        weak var objcDelegate: TerminalViewDelegateObjC?
        
        init(_ delegate: TerminalViewDelegateObjC) {
            self.objcDelegate = delegate
        }
        
        func sizeChanged(source: TerminalView, newCols: Int, newRows: Int) {
            objcDelegate?.sizeChanged?(source: source, newCols: newCols, newRows: newRows)
        }
        func setTerminalTitle(source: TerminalView, title: String) {
            objcDelegate?.setTerminalTitle?(source: source, title: title)
        }
        func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {
            objcDelegate?.hostCurrentDirectoryUpdate?(source: source, directory: directory)
        }
        func send(source: TerminalView, data: ArraySlice<UInt8>) {
            objcDelegate?.send?(source: source, data: Data(data))
        }
        func scrolled(source: TerminalView, position: Double) {
            objcDelegate?.scrolled?(source: source, position: position)
        }
        func requestOpenLink(source: TerminalView, link: String, params: [String: String]) {
            objcDelegate?.requestOpenLink?(source: source, link: link, params: params)
        }
        func bell(source: TerminalView) {
            objcDelegate?.bell?(source: source)
        }
        func clipboardCopy(source: TerminalView, content: Data) {
            objcDelegate?.clipboardCopy?(source: source, content: content)
        }
        func iTermContent(source: TerminalView, content: ArraySlice<UInt8>) {
            objcDelegate?.iTermContent?(source: source, content: Data(content))
        }
        func rangeChanged(source: TerminalView, startY: Int, endY: Int) {
            objcDelegate?.rangeChanged?(source: source, startY: startY, endY: endY)
        }
    }
    
    @objc public init (
        frame: CGRect,
        masterFD: Int32
    ){
        self.ttyHandle = FileHandle(fileDescriptor: masterFD, closeOnDealloc: false)
        
        super.init(frame: frame)
        
        self.isOpaque = false;
        self.backgroundColor = LDETheme.currentTheme?.backgroundColor ?? .secondarySystemBackground
        self.nativeForegroundColor = LDETheme.currentTheme?.textColor ?? gibDynamicColor(light: .label, dark: self.nativeForegroundColor)
        self.caretTextColor = LDETheme.currentTheme?.textColor ?? gibDynamicColor(light: .label, dark: self.nativeForegroundColor)
        self.font = UIFont.monospacedSystemFont(ofSize: (UIDevice.current.userInterfaceIdiom == .pad) ? 14 : 10, weight: .regular)
        
        self.ttyHandle?.readabilityHandler = { [weak self] fileHandle in
            guard let self = self else { return }
            var data = fileHandle.availableData
            guard !data.isEmpty else { return }
            /* fork: plt.show() in Python asks for a preview of its figures */
            let previews = TerminalViewObjC.forkTakePreviewRequests(from: &data)
            
            DispatchQueue.main.async {
                if !data.isEmpty { self.feed(byteArray: ArraySlice<UInt8>(data)) }
                if !previews.isEmpty { self.forkShowPreview(previews) }
            }
        }
        
        /* fork: a key bar whose keyboard button closes the keyboard */
        self.inputAccessoryView = ForkTerminalKeyBar(terminal: self)
        
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (self: Self, previousTraitCollection: UITraitCollection) in
            guard self.traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) else { return }
            
            if self.isFirstResponder {
                _ = self.resignFirstResponder()
                _ = self.becomeFirstResponder()
            }
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func willMove(toWindow newWindow: UIWindow?) {
        super.willMove(toWindow: newWindow)
        if(newWindow == nil) {
            NotificationCenter.default.removeObserver(self)
        } else {
            NotificationCenter.default.addObserver(self, selector: #selector(handleThemeChange(_:)), name: Notification.Name("uiColorChangeNotif"), object: nil)
            /* fork: keep the terminal above the keyboard */
            NotificationCenter.default.addObserver(self, selector: #selector(forkKeyboardChanged(_:)), name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(forkKeyboardChanged(_:)), name: UIResponder.keyboardWillHideNotification, object: nil)
        }
        handleThemeChange(nil)
    }
    
    // MARK: fork — previews asked for by the program (Python's plt.show())
    
    private static let previewStart = Array("\u{1b}]7770;nyxian-preview;".utf8)
    
    /// Takes ESC ] 7770 ; nyxian-preview ; path|path BEL out of the output and returns the paths.
    static func forkTakePreviewRequests(from data: inout Data) -> [String] {
        var paths: [String] = []
        var bytes = [UInt8](data)
        var searchFrom = 0
        while let start = forkFind(previewStart, in: bytes, from: searchFrom) {
            guard let end = bytes[(start + previewStart.count)...].firstIndex(of: 0x07) else { break }
            if let text = String(bytes: bytes[(start + previewStart.count)..<end], encoding: .utf8) {
                paths.append(contentsOf: text.split(separator: "|").map(String.init))
            }
            bytes.removeSubrange(start...end)
            searchFrom = start
        }
        if !paths.isEmpty { data = Data(bytes) }
        return paths
    }
    
    private static func forkFind(_ needle: [UInt8], in haystack: [UInt8], from: Int) -> Int? {
        guard haystack.count >= needle.count, from <= haystack.count - needle.count else { return nil }
        var index = from
        while index <= haystack.count - needle.count {
            if haystack[index] == needle[0], Array(haystack[index..<(index + needle.count)]) == needle { return index }
            index += 1
        }
        return nil
    }
    
    func forkShowPreview(_ paths: [String]) {
        let urls = paths.map { URL(fileURLWithPath: $0) }.filter { FileManager.default.fileExists(atPath: $0.path) }
        guard !urls.isEmpty, let root = window?.rootViewController else { return }
        /* fork: Cell Outputs is open — the figures show there, under their cell */
        if ForkPython.cellOutputsVisible { return }
        _ = resignFirstResponder()
        ForkQuickLook.present(urls, from: root)
    }
    
    // MARK: fork — key bar actions
    
    /// Closes the terminal's window (set by NXWindowSessionTerminal).
    @objc var forkCloseWindow: (() -> Void)?
    /// UserDefaults key the font size is saved to when changed with A−/A+ (nil: not saved).
    @objc var forkFontSizeDefaultsKey: String?
    
    @objc func forkApplyFontSize(_ size: CGFloat) {
        let clamped = min(72, max(6, size))
        self.font = UIFont.monospacedSystemFont(ofSize: clamped, weight: .regular)
    }
    
    func forkChangeFontSize(by delta: CGFloat) {
        let size = min(72, max(6, font.pointSize + delta))
        forkApplyFontSize(size)
        if let key = forkFontSizeDefaultsKey {
            UserDefaults.standard.set(Int(size), forKey: key)
        }
    }
    
    /// Keys from the key bar go the same way as typed ones (so a key closes a finished window).
    func forkSendKeys(_ data: Data) {
        if let delegate = objcDelegate {
            delegate.send?(source: self, data: data)
        } else {
            ttyHandle?.write(data)
        }
    }
    
    func forkPasteFromClipboard() {
        guard let text = UIPasteboard.general.string, !text.isEmpty else { return }
        if getTerminal().bracketedPasteMode {
            /* the program asked for pastes marked (Python's console, bash): send the text whole */
            var data = Data([0x1b, 0x5b, 0x32, 0x30, 0x30, 0x7e])
            data.append(Data(text.utf8))
            data.append(Data([0x1b, 0x5b, 0x32, 0x30, 0x31, 0x7e]))
            forkSendKeys(data)
        } else {
            let normalized = text.replacingOccurrences(of: "\r\n", with: "\r").replacingOccurrences(of: "\n", with: "\r")
            forkSendKeys(Data(normalized.utf8))
        }
    }
    
    func forkScrollPage(up: Bool) {
        let maxOffset = max(0, contentSize.height - bounds.height)
        let step = max(bounds.height - font.lineHeight * 2, font.lineHeight)
        let target = up ? max(0, contentOffset.y - step) : min(maxOffset, contentOffset.y + step)
        setContentOffset(CGPoint(x: contentOffset.x, y: target), animated: true)
    }
    
    func forkCloseWindowAction() {
        _ = resignFirstResponder()
        forkCloseWindow?()
    }
    
    // MARK: fork — keyboard avoidance
    
    /// Bottom constraint of the terminal in its window (set by NXWindowSessionTerminal).
    @objc var forkKeyboardConstraint: NSLayoutConstraint?
    private var forkKeyboardFrame: CGRect = .null
    
    @objc private func forkKeyboardChanged(_ notification: Notification) {
        if notification.name == UIResponder.keyboardWillHideNotification {
            forkKeyboardFrame = .null
        } else if let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
            forkKeyboardFrame = frame
        }
        forkUpdateKeyboardInset()
    }
    
    /// How much of the terminal's window the keyboard covers, from the bottom.
    private func forkKeyboardOverlap() -> CGFloat {
        guard let container = superview, let window = container.window, !forkKeyboardFrame.isNull else { return 0 }
        let keyboard = container.convert(forkKeyboardFrame, from: window.screen.coordinateSpace)
        let visible = container.bounds
        guard keyboard.intersects(visible), keyboard.maxY >= visible.maxY - 1 else { return 0 }  // floating keyboard: leave as is
        return max(0, min(visible.height - 60, visible.maxY - keyboard.minY))
    }
    
    private func forkUpdateKeyboardInset() {
        guard let constraint = forkKeyboardConstraint else { return }
        let target = -forkKeyboardOverlap()
        guard abs(constraint.constant - target) > 0.5 else { return }
        constraint.constant = target
        UIView.performWithoutAnimation {
            superview?.layoutIfNeeded()
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        /* the window can be moved or resized while the keyboard is up */
        if forkKeyboardConstraint != nil {
            DispatchQueue.main.async { [weak self] in self?.forkUpdateKeyboardInset() }
        }
    }
    
    @objc func handleThemeChange(_ notification: Notification?) {
        self.backgroundColor = LDETheme.currentTheme?.backgroundColor ?? .secondarySystemBackground
        self.nativeForegroundColor = LDETheme.currentTheme?.textColor ?? gibDynamicColor(light: .label, dark: self.nativeForegroundColor)
        self.caretTextColor = LDETheme.currentTheme?.textColor ?? gibDynamicColor(light: .label, dark: self.nativeForegroundColor)
    }
}

// MARK: - Fork: key bar above the keyboard

final class ForkTerminalKeyBar: UIInputView {
    private weak var terminal: TerminalViewObjC?
    
    private enum Key {
        case bytes([UInt8])
        case action(() -> Void)
    }
    
    init(terminal: TerminalViewObjC) {
        self.terminal = terminal
        let height: CGFloat = UIDevice.current.userInterfaceIdiom == .phone ? 40 : 48
        super.init(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: height), inputViewStyle: .keyboard)
        /* fixed height from the frame: with self-sizing the bar could come back with no height */
        allowsSelfSizing = false
        autoresizingMask = [.flexibleWidth]
        
        let esc: UInt8 = 0x1b
        let groups: [[(String?, String?, Key)]] = [
            [
                ("esc", nil, .bytes([esc])),
                (nil, "arrow.right.to.line.compact", .bytes([0x09])),
                (nil, "return", .bytes([0x0d])),
                ("^C", nil, .bytes([0x03])),
                ("^D", nil, .bytes([0x04]))
            ],
            [
                (nil, "arrow.left", .bytes([esc, 0x5b, 0x44])),
                (nil, "arrow.down", .bytes([esc, 0x5b, 0x42])),
                (nil, "arrow.up", .bytes([esc, 0x5b, 0x41])),
                (nil, "arrow.right", .bytes([esc, 0x5b, 0x43])),
                ("home", nil, .bytes([esc, 0x5b, 0x48])),
                ("end", nil, .bytes([esc, 0x5b, 0x46]))
            ],
            [
                (nil, "doc.on.clipboard", .action { [weak terminal] in terminal?.forkPasteFromClipboard() }),
                ("clear", nil, .bytes([0x0c])),
                (nil, "chevron.up.2", .action { [weak terminal] in terminal?.forkScrollPage(up: true) }),
                (nil, "chevron.down.2", .action { [weak terminal] in terminal?.forkScrollPage(up: false) }),
                (nil, "textformat.size.smaller", .action { [weak terminal] in terminal?.forkChangeFontSize(by: -2) }),
                (nil, "textformat.size.larger", .action { [weak terminal] in terminal?.forkChangeFontSize(by: 2) })
            ],
            [
                ("^A", nil, .bytes([0x01])),
                ("^E", nil, .bytes([0x05])),
                ("^K", nil, .bytes([0x0b])),
                ("^W", nil, .bytes([0x17])),
                ("^Z", nil, .bytes([0x1a])),
                ("^\\", nil, .bytes([0x1c]))
            ],
            "( ) [ ] { } < > = + - * / \\ | _ : ; ' \" # ~ ` ! ? @ $ % & ^ .".split(separator: " ").map { symbol -> (String?, String?, Key) in
                (String(symbol), nil, .bytes(Array(String(symbol).utf8)))
            }
        ]
        
        /* scrollable keys */
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 6
        stack.alignment = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        for (number, group) in groups.enumerated() {
            if number > 0 {
                let gap = UIView()
                gap.translatesAutoresizingMaskIntoConstraints = false
                gap.widthAnchor.constraint(equalToConstant: 6).isActive = true
                stack.addArrangedSubview(gap)
            }
            for (title, symbol, key) in group {
                stack.addArrangedSubview(makeKey(title: title, symbol: symbol) { [weak self] in
                    switch key {
                    case .bytes(let bytes): self?.send(bytes)
                    case .action(let action):
                        UIDevice.current.playInputClick()
                        action()
                    }
                })
            }
        }
        let scroll = UIScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.showsHorizontalScrollIndicator = false
        scroll.alwaysBounceHorizontal = true
        scroll.delaysContentTouches = false
        scroll.addSubview(stack)
        
        /* always visible: hide the keyboard, close the window */
        let fixed = UIStackView(arrangedSubviews: [
            makeKey(title: nil, symbol: "keyboard.chevron.compact.down") { [weak self] in
                _ = self?.terminal?.resignFirstResponder()
            },
            makeKey(title: nil, symbol: "xmark", tint: .systemRed) { [weak self] in
                self?.terminal?.forkCloseWindowAction()
            }
        ])
        fixed.axis = .horizontal
        fixed.spacing = 6
        fixed.translatesAutoresizingMaskIntoConstraints = false
        /* never wider than its two keys: the scrolling part takes the rest */
        fixed.setContentHuggingPriority(.required, for: .horizontal)
        fixed.setContentCompressionResistancePriority(.required, for: .horizontal)
        stack.distribution = .fill
        
        addSubview(scroll)
        addSubview(fixed)
        let stackHeight = stack.heightAnchor.constraint(equalTo: scroll.frameLayoutGuide.heightAnchor, constant: -10)
        stackHeight.priority = .defaultHigh   /* no conflict while the bar is being laid out with height 0 */
        NSLayoutConstraint.activate([
            scroll.leadingAnchor.constraint(equalTo: safeAreaLayoutGuide.leadingAnchor),
            scroll.topAnchor.constraint(equalTo: topAnchor),
            scroll.bottomAnchor.constraint(equalTo: bottomAnchor),
            scroll.trailingAnchor.constraint(equalTo: fixed.leadingAnchor, constant: -6),
            fixed.trailingAnchor.constraint(equalTo: safeAreaLayoutGuide.trailingAnchor, constant: -6),
            fixed.topAnchor.constraint(equalTo: topAnchor, constant: 5),
            fixed.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -5),
            stack.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor, constant: 6),
            stack.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor, constant: -6),
            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 5),
            stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -5),
            stackHeight
        ])
    }
    
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: UIDevice.current.userInterfaceIdiom == .phone ? 40 : 48)
    }
    
    private func send(_ bytes: [UInt8]) {
        UIDevice.current.playInputClick()
        terminal?.forkSendKeys(Data(bytes))
    }
    
    private func makeKey(title: String?, symbol: String?, tint: UIColor = .label, action: @escaping () -> Void) -> UIButton {
        let phone = UIDevice.current.userInterfaceIdiom == .phone
        var configuration = UIButton.Configuration.gray()
        configuration.cornerStyle = .medium
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 2, leading: phone ? 6 : 8, bottom: 2, trailing: phone ? 6 : 8)
        configuration.imagePlacement = .leading
        configuration.titleLineBreakMode = .byClipping
        if let title {
            configuration.attributedTitle = AttributedString(title, attributes: AttributeContainer([.font: UIFont.monospacedSystemFont(ofSize: 15, weight: .semibold)]))
        }
        if let symbol {
            /* scaled to fit: some symbols (doc.on.clipboard) are wide at their natural size */
            let image = UIImage(systemName: symbol, withConfiguration: UIImage.SymbolConfiguration(pointSize: phone ? 13 : 14, weight: .semibold))
            configuration.image = image
            configuration.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(scale: .small)
        }
        configuration.baseForegroundColor = tint
        let button = UIButton(configuration: configuration, primaryAction: UIAction { _ in action() })
        button.translatesAutoresizingMaskIntoConstraints = false
        let minimum: CGFloat = phone ? 34 : 44
        button.widthAnchor.constraint(greaterThanOrEqualToConstant: minimum).isActive = true
        if title == nil {
            /* symbol keys all the same width */
            let width = button.widthAnchor.constraint(equalToConstant: minimum + (phone ? 4 : 0))
            width.priority = .required
            width.isActive = true
        }
        button.setContentHuggingPriority(.required, for: .horizontal)
        return button
    }
}
