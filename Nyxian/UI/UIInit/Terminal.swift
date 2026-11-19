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
 Fork doctoralvarez/Nyxian — version 1.8.0
 Changelog:
  - 1.8.0 (2026-11-18): ESC ] 7770 ; nyxian-wheel ; names BEL (pip found no
    iOS wheel for a package that needs compiling): Nyxian asks whether to
    build it; on yes it starts the "iOS wheels" workflow of your fork (your
    Mac if it is on, else GitHub's), and says when the wheel is ready or the
    build failed (ForkWheelBuilder; token in Settings › Toolchain).
  - 1.7.0 (2026-11-18): iPad-only layout checks now ask NXForkIsPadLayout(),
      so iPhone Duo's large inner screen gets the iPad layout too.
  - 1.6.2 (2026-11-10): more local-server lines open the browser ("listening
    at", "Local:" of Vite, "Servidor en", node servers).
  - 1.6.1 (2026-11-10): the key bar scrolls sideways when the slide starts on
    a key (UIScrollView did not cancel a touch on a button, and the keys
    cover the whole bar: on iPhone paste, clear, A−/A+… were out of reach).
  - 1.6.0 (2026-11-10): web pages from the terminal open in Nyxian's browser:
    webbrowser.open() in Python (ESC ] 7770 ; nyxian-open ; url BEL), and
    local servers when they say where they listen (Flask, Django, uvicorn…).
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
import Security

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
        self.font = UIFont.monospacedSystemFont(ofSize: (NXForkIsPadLayout()) ? 14 : 10, weight: .regular)
        
        self.ttyHandle?.readabilityHandler = { [weak self] fileHandle in
            guard let self = self else { return }
            var data = fileHandle.availableData
            guard !data.isEmpty else { return }
            /* fork: plt.show() in Python asks for a preview of its figures */
            let previews = TerminalViewObjC.forkTakePreviewRequests(from: &data)
            /* fork: webbrowser.open(), and local servers saying where they listen */
            var pages = TerminalViewObjC.forkTakeRequests(TerminalViewObjC.openStart, from: &data)
            pages.append(contentsOf: self.forkLocalServers(in: data))
            /* fork: pip found no iOS wheel for packages that need compiling */
            let wheels = TerminalViewObjC.forkTakeRequests(TerminalViewObjC.wheelStart, from: &data)
            
            DispatchQueue.main.async {
                if !data.isEmpty { self.feed(byteArray: ArraySlice<UInt8>(data)) }
                if !previews.isEmpty { self.forkShowPreview(previews) }
                if let page = pages.last { self.forkOpenPage(page) }
                if let packages = wheels.last, let root = self.window?.rootViewController {
                    _ = self.resignFirstResponder()
                    ForkWheelBuilder.offer(packages: packages, from: root)
                }
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
    
    static let openStart = Array("\u{1b}]7770;nyxian-open;".utf8)
    static let wheelStart = Array("\u{1b}]7770;nyxian-wheel;".utf8)
    
    /// Takes every ESC ] 7770 ; KIND ; text BEL of one kind out of the output; returns the texts.
    static func forkTakeRequests(_ prefix: [UInt8], from data: inout Data) -> [String] {
        var found: [String] = []
        var bytes = [UInt8](data)
        var searchFrom = 0
        while let start = forkFind(prefix, in: bytes, from: searchFrom) {
            guard let end = bytes[(start + prefix.count)...].firstIndex(of: 0x07) else { break }
            if let text = String(bytes: bytes[(start + prefix.count)..<end], encoding: .utf8) { found.append(text) }
            bytes.removeSubrange(start...end)
            searchFrom = start
        }
        if !found.isEmpty { data = Data(bytes) }
        return found
    }
    
    /* fork: "Running on http://127.0.0.1:5000" (Flask), "Starting development server at http://127.0.0.1:8000/"
       (Django), "Uvicorn running on http://127.0.0.1:8000"… — opened once per address */
    private static let serverRegex = try! NSRegularExpression(pattern: #"(?i)(?:running (?:on|at)|server (?:at|on|running)|listening (?:on|at)|serving (?:http )?on|available on|started (?:on|at)|servidor (?:en|at)|local:)[^\n]*?(https?://(?:127\.0\.0\.1|localhost|0\.0\.0\.0|\[::1?\])(?::\d+)?[^\s'"]*)"#)
    private var forkOpenedServers = Set<String>()
    
    private func forkLocalServers(in data: Data) -> [String] {
        guard data.count < 65536, let text = String(data: data, encoding: .utf8), text.contains("http") else { return [] }
        let ns = text as NSString
        var pages: [String] = []
        for match in Self.serverRegex.matches(in: text, range: NSRange(location: 0, length: ns.length)) {
            var url = ns.substring(with: match.range(at: 1))
            url = url.replacingOccurrences(of: "0.0.0.0", with: "127.0.0.1").replacingOccurrences(of: "[::]", with: "127.0.0.1")
            /* ANSI colour codes some servers print right after the address */
            if let escape = url.firstIndex(of: "\u{1b}") { url = String(url[..<escape]) }
            while let last = url.last, ".,;)".contains(last) { url.removeLast() }
            if !forkOpenedServers.contains(url) {
                forkOpenedServers.insert(url)
                pages.append(url)
            }
        }
        return pages
    }
    
    func forkOpenPage(_ address: String) {
        guard let url = URL(string: address), let root = window?.rootViewController else { return }
        _ = resignFirstResponder()
        ForkBrowserViewController.present(url, from: root)
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

/// A slide that starts on a key scrolls the bar (a plain UIScrollView leaves a touch on a button to it).
final class ForkKeyBarScrollView: UIScrollView {
    override func touchesShouldCancel(in view: UIView) -> Bool { true }
}

final class ForkTerminalKeyBar: UIInputView {
    private weak var terminal: TerminalViewObjC?
    
    private enum Key {
        case bytes([UInt8])
        case action(() -> Void)
    }
    
    init(terminal: TerminalViewObjC) {
        self.terminal = terminal
        let height: CGFloat = !NXForkIsPadLayout() ? 40 : 48
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
        let scroll = ForkKeyBarScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.canCancelContentTouches = true
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
        CGSize(width: UIView.noIntrinsicMetric, height: !NXForkIsPadLayout() ? 40 : 48)
    }
    
    private func send(_ bytes: [UInt8]) {
        UIDevice.current.playInputClick()
        terminal?.forkSendKeys(Data(bytes))
    }
    
    private func makeKey(title: String?, symbol: String?, tint: UIColor = .label, action: @escaping () -> Void) -> UIButton {
        let phone = !NXForkIsPadLayout()
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

// MARK: - fork: build an iOS wheel pip could not find

/// pip (nyxian_pip) found no iOS wheel for a package that has to be compiled.
/// After you approve, the "iOS wheels" workflow of your fork builds it (your
/// Mac if it is online, else GitHub's) and puts it where Nyxian's pip looks;
/// Nyxian says when it is ready. Needs a GitHub token (Settings › Toolchain ›
/// iOS Wheels): a fine-grained token on doctoralvarez/Nyxian with
/// "Actions: Read and write". It is kept in the Keychain, never given to Python.
enum ForkWheelBuilder {
    static let repository = "doctoralvarez/Nyxian"
    static let branch = "mejoras-editor-ipad"
    static let workflow = "ios-wheels.yml"
    private static let service = "com.nyxian.fork.github"
    private static let account = "ios-wheels"

    // MARK: token (Keychain)

    static var token: String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data, let text = String(data: data, encoding: .utf8), !text.isEmpty else { return nil }
        return text
    }

    @discardableResult
    static func saveToken(_ text: String?) -> Bool {
        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(base as CFDictionary)
        guard let text = text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return true }
        var add = base
        add[kSecValueData as String] = Data(text.utf8)
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        return SecItemAdd(add as CFDictionary, nil) == errSecSuccess
    }

    // MARK: asking

    private static func top(_ root: UIViewController) -> UIViewController {
        var top = root
        while let shown = top.presentedViewController, !shown.isBeingDismissed { top = shown }
        return top
    }

    private static func tell(_ title: String, _ message: String, from root: UIViewController) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        top(root).present(alert, animated: true)
    }

    /// Asks whether to build `packages` (names separated by spaces)
    static func offer(packages: String, from root: UIViewController) {
        let names = packages.split(separator: " ").map(String.init).filter { !$0.isEmpty }
        guard !names.isEmpty else { return }
        let list = names.joined(separator: ", ")
        guard token != nil else {
            tell("No iOS wheel for \(list)",
                 "It needs compiling, which this device cannot do. To have your Mac (or GitHub's) build it, add a GitHub token in Settings › Toolchain › iOS Wheels, then run pip install again.",
                 from: root)
            return
        }
        let alert = UIAlertController(
            title: "Build an iOS wheel?",
            message: "There is no iOS wheel for \(list), and it has to be compiled.\n\nBuild it on your Mac (or on GitHub's Mac if yours is off)? It usually takes 10–40 minutes. Nyxian tells you when it is ready; then run pip install \(names.joined(separator: " ")) again.",
            preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Build", style: .default) { _ in
            start(names: names, from: root)
        })
        top(root).present(alert, animated: true)
    }

    // MARK: GitHub

    private static func makeRequest(_ path: String, method: String = "GET", body: [String: Any]? = nil) -> URLRequest? {
        guard let token, let url = URL(string: "https://api.github.com/repos/\(repository)/actions/\(path)") else { return nil }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        if let body {
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        request.timeoutInterval = 30
        return request
    }

    private static func start(names: [String], from root: UIViewController) {
        let sent = Date()
        let body: [String: Any] = ["ref": branch, "inputs": ["packages": names.joined(separator: " ")]]
        guard let request = makeRequest("workflows/\(workflow)/dispatches", method: "POST", body: body) else { return }
        URLSession.shared.dataTask(with: request) { data, response, error in
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            DispatchQueue.main.async {
                if status == 204 {
                    NXAlertDiagnosticPresenter.notifyUser(with: .note, withMessage: "Building the iOS wheel for \(names.joined(separator: ", "))…", withDelay: 0.0)
                    follow(names: names, since: sent)
                } else {
                    var reason = error?.localizedDescription ?? "GitHub answered \(status)"
                    if status == 401 { reason = "The token is not valid (or expired)." }
                    if status == 403 || status == 404 { reason = "The token cannot start workflows: it needs \"Actions: Read and write\" on \(repository)." }
                    if let data, let text = String(data: data, encoding: .utf8), status >= 400, text.count < 300 { reason += "\n\n" + text }
                    tell("Could not start the build", reason, from: root)
                }
            }
        }.resume()
    }

    /// Watches the run that started and says how it ended (up to 3 hours)
    private static func follow(names: [String], since: Date) {
        Task.detached {
            let list = names.joined(separator: ", ")
            var runID: Int?
            let formatter = ISO8601DateFormatter()
            for _ in 0..<180 {
                try? await Task.sleep(nanoseconds: 60 * 1_000_000_000)
                if runID == nil {
                    guard let request = makeRequest("workflows/\(workflow)/runs?event=workflow_dispatch&per_page=5"),
                          let answer = try? await URLSession.shared.data(for: request),
                          let json = try? JSONSerialization.jsonObject(with: answer.0) as? [String: Any],
                          let runs = json["workflow_runs"] as? [[String: Any]] else { continue }
                    runID = runs.first(where: {
                        guard let created = $0["created_at"] as? String, let date = formatter.date(from: created) else { return false }
                        return date >= since.addingTimeInterval(-30)
                    })?["id"] as? Int
                    continue
                }
                guard let runID, let request = makeRequest("runs/\(runID)"),
                      let answer = try? await URLSession.shared.data(for: request),
                      let run = try? JSONSerialization.jsonObject(with: answer.0) as? [String: Any],
                      (run["status"] as? String) == "completed" else { continue }
                let ok = (run["conclusion"] as? String) == "success"
                await MainActor.run {
                    let message = ok
                        ? "iOS wheel ready: run pip install \(names.joined(separator: " ")) again"
                        : "The iOS wheel build for \(list) did not finish (it may not build for iOS yet)"
                    NXAlertDiagnosticPresenter.notifyUser(with: ok ? .note : .warning, withMessage: message, withDelay: 0.0)
                }
                return
            }
        }
    }
}

