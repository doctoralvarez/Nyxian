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
 Fork doctoralvarez/Nyxian — version 1.6.0
 Changelog:
  - 1.6.0 (2026-11-07): Fix-its — ⌥⌘↩ (or the wrench button) applies the
    compiler's fix for the caret's line, ⌃⌥⌘F applies every fix in the file;
    the file is re-checked first so positions match the current text.
  - 1.5.0 (2026-11-07): parameter help bubble while typing a call (after "("
    and ","; ⌃⇧Space shows it, Esc hides it) with the current argument in
    bold; documentation of the selected suggestion under the list.
  - 1.4.0 (2026-11-07): ⌃I Format Document (clang-format for C/ObjC/C++,
    brace re-indentation for Swift); ⌃⌘E Rename Symbol across the project
    (open tabs edited in place and undoable, closed files written);
    LiveEditorRegistry; completion can be turned off in Customization.
  - 1.3.0 (2026-11-07): phase 2 — Swift files ask the Swift compiler for
    completions (types, members after ".", argument labels); "font()" is
    inserted with the caret inside the parentheses. While the compiler is
    busy, keystrokes fall back to word suggestions.
  - 1.2.0 (2026-11-07): code completion while typing. Phase 0 suggests words
    from this file, the project and the language (all files); phase 1 asks
    Clang for real completions in C, Objective-C and C++ files (also after
    "." and "->"). Tab/Return accept, ↑/↓ choose, Esc dismisses, or tap.
    EditorCompletionController / CompletionPopupView at the end of the file.
  - 1.1.0 (2026-11-07): ⌥⌘↑ / ⌥⌘↓ move the current or selected lines.
  - 1.0.0 (2026-11-06): Find & Replace (UIFindInteraction) with ⌘F, ⌥⌘F,
    ⌘G, ⇧⌘G and a toolbar button; editor shortcuts ⌘/ toggle comment,
    ⌘] / ⌘[ shift lines, ⌘D duplicate line, ⌘L go to line.
*/

import UIKit
import Runestone
import TreeSitter
import TreeSitterC
import TreeSitterObjc
import TreeSitterXML
import TreeSitterCPP
import TreeSitterSwift
import GameController
import MobileDevelopmentKit

func booleanDefaults(key: String, defaultValue: Bool) -> Bool {
    if UserDefaults.standard.object(forKey: key) == nil {
        return defaultValue
    }
    return UserDefaults.standard.bool(forKey: key)
}

// MARK: - OnDissapear Container
class CodeEditorViewController: UIViewController, NXDocumentDelegate {
    private(set) var document: NXDocument?
    private(set) var file: MDKFile
    private(set) var textView: TextView
    private(set) var project: NXProject?
    private(set) var languageServer: NXLanguageServer?
    private(set) var coordinator: CodeEditorCoordinator?
    private(set) var database: DebugDatabase?
    private(set) var location: MDKSourceLocation?
    private(set) var floatingToolbar: UIToolbar?
    private(set) var floatingToolbarBottomConstraint: NSLayoutConstraint?
    
    private(set) var undoButton: UIButton?
    private(set) var redoButton: UIButton?
    
    private(set) var autoindent: Bool = false
    
    /* fork: suggestions while typing */
    private(set) var completion: EditorCompletionController?
    /* fork: parameter help bubble */
    private(set) var signatureHelp: SignatureHelpController?
    
    let isReadOnly: Bool
    
    init?(project: NXProject?,
          url: URL,
          line: CFIndex? = nil,
          column: CFIndex? = nil,
          isReadOnly: Bool = false) {
        guard let file = MDKFile(url: url) else {
            return nil
        }
        self.file = file
        self.textView = TextView()
        
        self.project = project
        
        if let line = line,
           let column = column {
            self.location = MDKSourceLocationMake(line, column)
        }
        self.isReadOnly = isReadOnly ? isReadOnly : !FileManager.default.isWritableFile(atPath: url.path)
        
        // Only allow C files to typecheck for now
        // Cuz swift is not supported yet by synpush
        // because its still a long journey till
        // swift gets all of those nice little features.
        if self.file.isClang || self.file.isSwift {
            self.languageServer = NXLanguageServer(self.file.fileURL.path)
            
            if let project = project {
                self.database = DebugDatabase.getDatabase(ofPath: project.cacheURL.appendingPathComponent("debug.json").path)
            }
        }
        
        super.init(nibName: nil, bundle: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(changedProjectSettings(_:)), name: Notification.Name("NXProjectSettingsChanged"), object: nil)
    }

    @objc func changedProjectSettings(_ notification: Notification) {
        self.languageServer?.releaseMemory()
        self.coordinator?.textViewDidChange(self.textView)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if #unavailable(iOS 26.0) {
            self.navigationController?.navigationBar.compactAppearance = currentNavigationBarAppearance
            self.navigationController?.navigationBar.scrollEdgeAppearance = currentNavigationBarAppearance
        }
        
        NXDocumentManager.shared().open(URL(fileURLWithPath: self.file.fileURL.path)) { [weak self] doc in
            guard let doc = doc else {
                if UIDevice.current.userInterfaceIdiom != .pad {
                    self?.dismiss(animated: true)
                } else {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: {
                        NotificationCenter.default.post(name: Notification.Name("FileListAct"), object: ["close", self?.file.fileURL.path ?? ""])
                    })
                }
                return
            }
            doc.delegate = self
            self?.document = doc
            
            DispatchQueue.main.async {
                self?.textView.text = doc.text
            }
        }
        
        self.title = self.file.fileURL.lastPathComponent
        
        if !NXApplicationState.fileListRequiresToSendRequests,
           !self.isReadOnly {
            let saveButton: UIBarButtonItem = UIBarButtonItem()
            saveButton.tintColor = .label
            saveButton.title = "Save"
            saveButton.target = self
            saveButton.action = #selector(saveText)
            self.navigationItem.setRightBarButton(saveButton, animated: true)
        }
        
        if !NXApplicationState.fileListRequiresToSendRequests {
            let closeButton: UIBarButtonItem = UIBarButtonItem()
            closeButton.tintColor = .label
            closeButton.title = "Close"
            closeButton.target = self
            closeButton.action = #selector(closeEditor)
            self.navigationItem.setLeftBarButton(closeButton, animated: true)
        }
        
        let theme: LDETheme = LDETheme.currentTheme ?? LDEThemeReader.shared.currentlySelectedTheme()
            
        self.view.backgroundColor = .systemBackground
        self.textView.backgroundColor = theme.backgroundColor
        self.textView.theme = theme
            
        self.navigationController?.navigationBar.prefersLargeTitles = false
        self.navigationController?.navigationBar.standardAppearance = currentNavigationBarAppearance
        self.navigationController?.navigationBar.scrollEdgeAppearance = currentNavigationBarAppearance
        
        self.textView.showLineNumbers = booleanDefaults(key: "LDEShowLineNumbers", defaultValue: true)
        self.textView.showSpaces = booleanDefaults(key: "LDEShowSpaces", defaultValue: true)
        self.textView.isLineWrappingEnabled = booleanDefaults(key: "LDEWrapLines", defaultValue: true)
        self.textView.showLineBreaks = booleanDefaults(key: "LDEShowLineBreaks", defaultValue: true)
        self.textView.indentStrategy = .tab(length: 4)
        
        if self.languageServer != nil || self.file.type == .swift {
            self.autoindent = booleanDefaults(key: "LDEAutoindent", defaultValue: true)
        }
        
        self.textView.characterPairTrailingComponentDeletionMode = .immediatelyFollowingLeadingComponent
        
        self.textView.lineSelectionDisplayType = .line
        
        self.textView.showsHorizontalScrollIndicator = false;
        if #available(iOS 17.4, *) {
            self.textView.bouncesHorizontally = false
        }
        
        self.textView.lineHeightMultiplier = 1.3
        self.textView.keyboardType = .asciiCapable
        self.textView.smartQuotesType = .no
        self.textView.smartDashesType = .no
        self.textView.smartInsertDeleteType = .no
        self.textView.autocorrectionType = .no
        self.textView.autocapitalizationType = .none
        
        if #available(iOS 27.0, *) {
            self.textView.textContainerInset = UIEdgeInsets(top: 2, left: 2, bottom: 2, right: 0)
        } else {
            if #available(iOS 26.0, *),
               UIDevice.current.userInterfaceIdiom == .pad {
                self.textView.textContainerInset = UIEdgeInsets(top: 20, left: 2, bottom: 20, right: 0)
                self.textView.gutterLeadingPadding = 10
            } else {
                self.textView.textContainerInset = UIEdgeInsets(top: 2, left: 2, bottom: 2, right: 0)
            }
        }
        self.textView.isEditable = !self.isReadOnly

        /* fork: system find navigator (find & replace) provided by Runestone */
        self.textView.isFindInteractionEnabled = true

        func loadLanguage(language: UnsafePointer<TSLanguage>, highlightsURL: [URL]) {
            func combinedQuery(fromFilesAt fileURLs: [URL]) -> TreeSitterLanguage.Query? {
                let rawQuery = fileURLs.compactMap { try? String(contentsOf: $0) }.joined(separator: "\n")
                if !rawQuery.isEmpty {
                    return TreeSitterLanguage.Query(string: rawQuery)
                } else {
                    return nil
                }
            }
            
            let language = TreeSitterLanguage(language, highlightsQuery: combinedQuery(fromFilesAt: highlightsURL))
            let languageMode = TreeSitterLanguageMode(language: language)
            
            self.textView.setLanguageMode(languageMode)
        }
        
        switch self.file.fileURL.pathExtension {
        case "m","h":
            loadLanguage(language: tree_sitter_objc(), highlightsURL: [
                URL(fileURLWithPath: "\(Bundle.main.bundlePath)/TreeSitterC_TreeSitterC.bundle/queries/highlights.scm"),
                URL(fileURLWithPath: "\(Bundle.main.bundlePath)/Shared/ObjCFix/highlights.scm")
            ])
            break
        case "c":
            loadLanguage(language: tree_sitter_c(), highlightsURL: [
                URL(fileURLWithPath: "\(Bundle.main.bundlePath)/TreeSitterC_TreeSitterC.bundle/queries/highlights.scm")
            ])
            break
        case "hpp","cpp":
            loadLanguage(language: tree_sitter_cpp(), highlightsURL: [
                URL(fileURLWithPath: "\(Bundle.main.bundlePath)/TreeSitterC_TreeSitterC.bundle/queries/highlights.scm"),
                URL(fileURLWithPath: "\(Bundle.main.bundlePath)/TreeSitterCPP_TreeSitterCPP.bundle/queries/highlights.scm")
            ])
            break
        case "xml","plist":
            loadLanguage(language: tree_sitter_xml(), highlightsURL: [
                URL(fileURLWithPath: "\(Bundle.main.bundlePath)/TreeSitterXML_TreeSitterXML.bundle/xml/highlights.scm")
            ])
            break
        case "swift":
            loadLanguage(language: tree_sitter_swift(), highlightsURL: [
                URL(fileURLWithPath: "\(Bundle.main.bundlePath)/TreeSitterSwift_TreeSitterSwift.bundle/queries/highlights.scm")
            ])
        default:
            break
        }
            
        self.textView.translatesAutoresizingMaskIntoConstraints = false
        self.textView.contentInsetAdjustmentBehavior = .always
        self.view.addSubview(textView)
        
        NSLayoutConstraint.activate([
            textView.topAnchor.constraint(equalTo: view.topAnchor),
            textView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            textView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            textView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        
        if UIDevice.current.userInterfaceIdiom == .phone {
            self.setupToolbar(textView: self.textView)
        } else if #unavailable(iOS 26.0) {
            if GCKeyboard.coalesced == nil {
                self.setupToolbar(textView: self.textView)
            }
        }
        
        self.coordinator = CodeEditorCoordinator(parent: self)
        self.textView.editorDelegate = self.coordinator
        
        /* fork: code completion and parameter help */
        self.completion = EditorCompletionController(editor: self)
        self.signatureHelp = SignatureHelpController(editor: self)
        /* fork: project-wide edits (rename) reach this tab through the registry */
        LiveEditorRegistry.register(self)
        
        self.goto(location: self.location)
    }
    
    func documentRequestsText(_ document: NXDocument!) -> String! {
        guard let project = self.project,
              let database = self.database,
              let _ = self.languageServer,
              let coordinator = self.coordinator else { return self.textView.text }
        
        database.setFileDebug(ofPath: self.file.fileURL.path, synItems: coordinator.diag)
        database.saveDatabase(toPath: project.cacheURL.appendingPathComponent("debug.json").path)
        
        return self.textView.text
    }
    
    func goto(location: MDKSourceLocation?) {
        let line = location?.line
        let column = location?.column
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            guard let line = line, line > 0 else { return }
            let column = column.map { $0 > 0 ? $0 - 1 : 0 } ?? 0

            let lines = self.textView.text.components(separatedBy: .newlines)
            guard Int(line) <= lines.count else { return }

            let lineText = lines[Int(line - 1)]
            let clampedColumn = min(Int(column), lineText.count)
            let offset = lines.prefix(Int(line - 1)).reduce(0) { $0 + $1.count + 1 } + clampedColumn

            guard let rect = self.textView.rectForLine(Int(line)) else { return }

            guard let start = self.textView.position(from: self.textView.beginningOfDocument, offset: offset) else { return }
            self.textView.selectedTextRange = self.textView.textRange(from: start, to: start)
            self.textView.becomeFirstResponder()

            let visibleRect = CGRect(
                x: self.textView.contentOffset.x,
                y: self.textView.contentOffset.y,
                width: self.textView.bounds.width,
                height: self.textView.bounds.height
            )

            guard !visibleRect.contains(rect) else {
                self.flashLine(rect: rect)
                return
            }

            let targetOffsetY = rect.origin.y - self.textView.textContainerInset.top
            let maxOffsetY = max(self.textView.contentSize.height - self.textView.bounds.height, 0)
            let clampedOffsetY = max(min(targetOffsetY, maxOffsetY), 0)

            self.textView.contentOffset = CGPoint(x: 0, y: clampedOffsetY)
            self.flashLine(rect: rect)
        }
    }

    private func flashLine(rect: CGRect) {
        let fullWidthRect = CGRect(x: 0, y: rect.origin.y, width: textView.bounds.width, height: rect.height)

        let path = UIBezierPath(roundedRect: fullWidthRect.insetBy(dx: 4, dy: 1), cornerRadius: 4)

        let flashLayer = CAShapeLayer()
        flashLayer.path = path.cgPath
        flashLayer.fillColor = UIColor.systemYellow.withAlphaComponent(0.45).cgColor
        flashLayer.strokeColor = UIColor.systemYellow.cgColor
        flashLayer.lineWidth = 1.5
        flashLayer.opacity = 0.0

        textView.layer.addSublayer(flashLayer)

        let pulse = CAKeyframeAnimation(keyPath: "opacity")
        pulse.values = [0.0, 1.0, 1.0, 0.0]
        pulse.keyTimes = [0, 0.1, 0.6, 1.0]
        pulse.duration = 1.4
        pulse.timingFunctions = [
            CAMediaTimingFunction(name: .easeIn),
            CAMediaTimingFunction(name: .linear),
            CAMediaTimingFunction(name: .easeOut)
        ]

        CATransaction.begin()
        CATransaction.setCompletionBlock {
            flashLayer.removeFromSuperlayer()
        }
        flashLayer.add(pulse, forKey: "flashPulse")
        CATransaction.commit()
    }
    
    func setupToolbar(textView: TextView) {
        let theme: LDETheme = LDEThemeReader.shared.currentlySelectedTheme()
        
        func spawnSeparator() -> UIBarButtonItem {
            let separator = UIBarButtonItem(barButtonSystemItem: .fixedSpace, target: nil, action: nil)
            separator.width = 5
            return separator
        }
        
        func getAdditionalButtons(buttons: [String]) -> [UIBarButtonItem] {
            var array: [UIBarButtonItem] = [spawnSeparator()]
            for button in buttons {
                array.append(contentsOf: [
                    UIBarButtonItem(customView: SymbolButton(symbolName: button, width: 25.0) {
                        textView.replace(textView.selectedTextRange!, withText: button)
                    }),
                    spawnSeparator()])
            }
            return array;
        }
        
        let tabBarButton = UIBarButtonItem(customView: SymbolButton(symbolName: "arrow.right.to.line", width: 35.0) {
            guard let selectedRange = textView.selectedTextRange else { return }
            
            if let selectedText = textView.text(in: selectedRange), !selectedText.isEmpty {
                let lines = selectedText.components(separatedBy: .newlines)
                let indentedText = lines
                    .map { "\t" + $0 }
                    .joined(separator: "\n")
                
                let startPosition = selectedRange.start
                
                textView.replace(selectedRange, withText: indentedText)
                
                if let newEnd = textView.position(from: startPosition, offset: indentedText.count) {
                    textView.selectedTextRange = textView.textRange(from: startPosition, to: newEnd)
                }
            } else {
                textView.replace(selectedRange, withText: "\t")
            }
        } longActionHandler: {
            guard let selectedRange = textView.selectedTextRange else { return }
            
            if let selectedText = textView.text(in: selectedRange), !selectedText.isEmpty {
                let lines = selectedText.components(separatedBy: .newlines)
                let unindentedText = lines
                    .map { line in
                        if line.hasPrefix("\t") {
                            return String(line.dropFirst())
                        }
                        return line
                    }
                    .joined(separator: "\n")
                
                let startPosition = selectedRange.start
                
                textView.replace(selectedRange, withText: unindentedText)
                
                if let newEnd = textView.position(from: startPosition, offset: unindentedText.count) {
                    textView.selectedTextRange = textView.textRange(from: startPosition, to: newEnd)
                }
            } else {
                if let previousPosition = textView.position(from: selectedRange.start, offset: -1),
                   let rangeToCheck = textView.textRange(from: previousPosition, to: selectedRange.start),
                   let textToCheck = textView.text(in: rangeToCheck),
                   textToCheck == "\t" {
                    textView.replace(rangeToCheck, withText: "")
                }
            }
        })
        
        let hideBarButton = UIBarButtonItem(customView: SymbolButton(symbolName: "keyboard.chevron.compact.down", width: 35.0) {
            textView.resignFirstResponder()
        })
        
        var items: [UIBarButtonItem] = [
            tabBarButton,
            UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        ]
        
        let undoButton = SymbolButton(symbolName: "arrow.uturn.left", width: 35.0) {
            textView.undoManager?.undo()
        }
        
        let redoButton = SymbolButton(symbolName: "arrow.uturn.right", width: 35.0) {
            textView.undoManager?.redo()
        }
        
        self.redoButton = redoButton
        self.undoButton = undoButton
        
        if #unavailable(iOS 26.0) {
            items.append(contentsOf: getAdditionalButtons(buttons: ["{","}","[","]",";"]))
            items.append(UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil))
            items.append(UIBarButtonItem(customView: undoButton))
            items.append(spawnSeparator())
            items.append(UIBarButtonItem(customView: redoButton))
        }
        
        items.append(UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil))
        
        if #unavailable(iOS 26.0) {
            items.append(spawnSeparator())
        } else {
            let undoRedoContainer = UIStackView()
            undoRedoContainer.axis = .horizontal
            undoRedoContainer.spacing = 8
            undoRedoContainer.alignment = .center
            undoRedoContainer.translatesAutoresizingMaskIntoConstraints = false

            NSLayoutConstraint.activate([
                undoRedoContainer.heightAnchor.constraint(equalToConstant: 35)
            ])

            let separator = UIView()
            separator.translatesAutoresizingMaskIntoConstraints = false
            separator.backgroundColor = UIColor.separator.withAlphaComponent(0.5)
            separator.layer.cornerRadius = 0.5
            NSLayoutConstraint.activate([
                separator.widthAnchor.constraint(equalToConstant: 1),
                separator.heightAnchor.constraint(equalToConstant: 20)
            ])

            undoRedoContainer.addArrangedSubview(undoButton)
            undoRedoContainer.addArrangedSubview(separator)
            undoRedoContainer.addArrangedSubview(redoButton)

            items.append(UIBarButtonItem(customView: undoRedoContainer))
            items.append(spawnSeparator())
        }
        
        /* fork: apply the compiler's fix on the caret's line */
        let fixBarButton = UIBarButtonItem(customView: SymbolButton(symbolName: "wrench.adjustable", width: 35.0) { [weak self] in
            self?.fixIssueOnCurrentLine()
        })
        items.append(fixBarButton)
        items.append(spawnSeparator())
        
        /* fork: find & replace for touch users (no hardware keyboard) */
        let findBarButton = UIBarButtonItem(customView: SymbolButton(symbolName: "magnifyingglass", width: 35.0) { [weak self] in
            self?.showFindAndReplace()
        })
        items.append(findBarButton)
        items.append(spawnSeparator())

        items.append(hideBarButton)

        if #available(iOS 26.0, *) {
            textView.inputAccessoryView = nil
            let toolbar = UIToolbar()
            toolbar.translatesAutoresizingMaskIntoConstraints = false
            let appearance = UIToolbarAppearance()
            appearance.configureWithTransparentBackground()
            toolbar.standardAppearance = appearance
            toolbar.scrollEdgeAppearance = appearance
            
            toolbar.items = items
            toolbar.isHidden = true
            
            view.addSubview(toolbar)
            
            let bottomConstraint = toolbar.bottomAnchor.constraint(equalTo: view.bottomAnchor)
            NSLayoutConstraint.activate([
                toolbar.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 8),
                toolbar.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -8),
                toolbar.heightAnchor.constraint(equalToConstant: 50),
                bottomConstraint
            ])
            
            self.floatingToolbar = toolbar
            self.floatingToolbarBottomConstraint = bottomConstraint
        } else {
            let toolbar = UIToolbar()
            toolbar.sizeToFit()
            
            let appearance = UIToolbarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = theme.gutterBackgroundColor
            toolbar.standardAppearance = appearance
            toolbar.scrollEdgeAppearance = appearance
            
            toolbar.items = items
            textView.inputAccessoryView = toolbar
        }
        
        self.updateUndoRedoButtons()
    }

    @objc private func updateUndoRedoButtons() {
        guard let undoManager = textView.undoManager else { return }
        
        undoButton?.isEnabled = undoManager.canUndo
        redoButton?.isEnabled = undoManager.canRedo
        undoButton?.imageView?.alpha = undoManager.canUndo ? 1.0 : 0.5
        redoButton?.imageView?.alpha = undoManager.canRedo ? 1.0 : 0.5
    }

    @objc func keyboardWillShow(notification: NSNotification) {
        guard let userInfo = notification.userInfo,
              let keyboardFrame = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
              let duration = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double else { return }
        
        let keyboardInView = view.convert(keyboardFrame, from: nil)
        let overlap = max(0, view.bounds.maxY - keyboardInView.minY)

        let bottomInset: CGFloat

        if #available(iOS 26.0, *),
           let floatingToolbar = self.floatingToolbar {
            bottomInset = overlap + floatingToolbar.frame.height + 10
            floatingToolbar.isHidden = false
            floatingToolbarBottomConstraint?.constant = -(keyboardFrame.height + 8)
            UIView.animate(withDuration: duration) { self.view.layoutIfNeeded() }
        } else {
            bottomInset = overlap
        }
        
        textView.contentInset.bottom = bottomInset
        textView.verticalScrollIndicatorInsets.bottom = bottomInset
    }

    @objc func keyboardWillHide(notification: NSNotification) {
        guard let userInfo = notification.userInfo,
              let duration = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double else {
            textView.contentInset = .zero
            textView.scrollIndicatorInsets = .zero
            return
        }

        textView.contentInset = .zero
        textView.verticalScrollIndicatorInsets = .zero

        if #available(iOS 26.0, *), let floatingToolbar = self.floatingToolbar {
            UIView.animate(withDuration: duration) {
                self.floatingToolbarBottomConstraint?.constant = 100
                self.view.layoutIfNeeded()
            }
        }
    }
    
    @objc func saveText() {
        if !self.isReadOnly {
            defer {
                self.document?.autosave()
            }
            
            showSaveAnimation()
            
            guard let project = self.project,
                  let database = self.database,
                  let _ = self.languageServer,
                  let coordinator = self.coordinator else { return }
            
            database.setFileDebug(ofPath: self.file.fileURL.path, synItems: coordinator.diag)
            database.saveDatabase(toPath: project.cacheURL.appendingPathComponent("debug.json").path)
        }
    }
    
    private func showSaveAnimation() {
        if UIDevice.current.userInterfaceIdiom == .pad {
            let layer = view.layer
            
            let originalColor = layer.borderColor ?? UIColor.clear.cgColor
            
            let flashColor = UIColor.label.cgColor
            
            let animation = CABasicAnimation(keyPath: "borderColor")
            animation.fromValue = flashColor
            animation.toValue = originalColor
            animation.duration = 0.35
            animation.timingFunction = CAMediaTimingFunction(name: .easeOut)
            
            layer.borderColor = originalColor
            layer.add(animation, forKey: "saveFlash")
        }
    }
    
    @objc func closeEditor() {
        NotificationCenter.default.post(name: Notification.Name("CodeEditorDismissed"), object: nil)
        self.dismiss(animated: true)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(updateUndoRedoButtons), name: .NSUndoManagerDidUndoChange, object: textView.undoManager)
        NotificationCenter.default.addObserver(self, selector: #selector(updateUndoRedoButtons), name: .NSUndoManagerDidRedoChange, object: textView.undoManager)
        NotificationCenter.default.addObserver(self, selector: #selector(updateUndoRedoButtons), name: .NSUndoManagerDidCloseUndoGroup, object: textView.undoManager)
        
        if UIDevice.current.userInterfaceIdiom == .pad {
            NotificationCenter.default.addObserver(self, selector: #selector(hardwareKeyboardDidConnect), name: .GCKeyboardDidConnect, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(hardwareKeyboardDidDisconnect), name: .GCKeyboardDidDisconnect, object: nil)
        }
        
        if UIDevice.current.userInterfaceIdiom == .pad {
            self.coordinator?.textViewDidChange(self.textView)
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        self.completion?.hide()
        self.signatureHelp?.hide()
        self.document?.autosave()
        self.coordinator?.debounce?.invalidate()
        self.languageServer?.releaseMemory()
        super.viewWillDisappear(animated)
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func hardwareKeyboardDidConnect(_ notification: Notification) {
        textView.resignFirstResponder()
        if #unavailable(iOS 26.0) {
            textView.inputAccessoryView = nil
            textView.reloadInputViews()
        }
    }
        
    @objc private func hardwareKeyboardDidDisconnect(_ notification: Notification) {
        textView.resignFirstResponder()
        if #unavailable(iOS 26.0) {
            setupToolbar(textView: textView)
            textView.reloadInputViews()
        }
    }
    
    override var keyCommands: [UIKeyCommand]? {
        func command(_ title: String,
                     _ action: Selector,
                     _ input: String,
                     _ flags: UIKeyModifierFlags = .command) -> UIKeyCommand {
            let keyCommand = UIKeyCommand(title: title, action: action, input: input, modifierFlags: flags)
            keyCommand.wantsPriorityOverSystemBehavior = true
            return keyCommand
        }

        /* fork: while suggestions are shown, these keys drive the list */
        if self.completion?.isVisible == true {
            return [
                command("Accept Suggestion", #selector(completionAccept), "\t", []),
                command("Accept Suggestion", #selector(completionAccept), "\r", []),
                command("Dismiss Suggestions", #selector(completionDismiss), UIKeyCommand.inputEscape, []),
                command("Previous Suggestion", #selector(completionMoveUp), UIKeyCommand.inputUpArrow, []),
                command("Next Suggestion", #selector(completionMoveDown), UIKeyCommand.inputDownArrow, []),
                UIKeyCommand(title: "Save File",
                             action: #selector(saveText),
                             input: "S",
                             modifierFlags: .command)
            ]
        }
        
        var commands: [UIKeyCommand] = [
            UIKeyCommand(title: "Save File",
                         action: #selector(saveText),
                         input: "S",
                         modifierFlags: .command),
            /* fork: find / navigation */
            command("Find", #selector(showFind), "f"),
            command("Find Next", #selector(findNextMatch), "g"),
            command("Find Previous", #selector(findPreviousMatch), "g", [.command, .shift]),
            command("Go to Line", #selector(promptGoToLine), "l")
        ]

        if !self.isReadOnly {
            /* fork: editing */
            commands.append(contentsOf: [
                command("Find and Replace", #selector(showFindAndReplace), "f", [.command, .alternate]),
                command("Shift Right", #selector(indentLines), "]"),
                command("Shift Left", #selector(outdentLines), "["),
                command("Duplicate Line", #selector(duplicateLines), "d"),
                command("Move Line Up", #selector(moveLinesUp), UIKeyCommand.inputUpArrow, [.command, .alternate]),
                command("Move Line Down", #selector(moveLinesDown), UIKeyCommand.inputDownArrow, [.command, .alternate]),
                command("Rename Symbol", #selector(promptRenameSymbol), "e", [.command, .control]),
                command("Show Signature", #selector(signatureHelpShow), " ", [.control, .shift]),
                command("Fix Issue", #selector(fixIssueOnCurrentLine), "\r", [.command, .alternate]),
                command("Fix All Issues", #selector(fixAllIssues), "f", [.command, .alternate, .control])
            ])
            if self.file.isClang || self.file.isSwift {
                commands.append(command("Format Document", #selector(formatDocument), "i", [.control]))
            }
            /* fork: Esc closes the parameter help (the suggestion list, when open, takes Esc first) */
            if self.signatureHelp?.isVisible == true {
                commands.append(command("Dismiss Parameter Help", #selector(signatureHelpDismiss), UIKeyCommand.inputEscape, []))
            }
            if self.lineCommentPrefix != nil {
                commands.append(command("Toggle Comment", #selector(toggleComment), "/"))
            }
        }

        return commands
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        /* pwerform hardware keyboard check */
        if GCKeyboard.coalesced != nil {
            self.textView.becomeFirstResponder()
        }
    }
    
    @objc func jumpToDefinition() {
        guard let server = languageServer else { return }
        guard let selectedRange = textView.selectedTextRange else { return }
        
        DispatchQueue.global(qos: .userInitiated).async {
            let flags: [String] = (self.isReadOnly ? NXProjectConfig.sdkCompilerFlags() : self.project?.projectConfig.compilerFlags)!
            server.reparseFile(self.textView.text, withArgs: flags)
            
            DispatchQueue.main.async {
                let cursorPosition = selectedRange.start
                let offset = self.textView.offset(from: self.textView.beginningOfDocument, to: cursorPosition)
                
                let text = self.textView.text
                let (line, column) = self.offsetToLineColumn(text: text, offset: offset)
                
                DispatchQueue.global(qos: .userInitiated).async {
                    guard let def = server.getDefinitionAt(MDKSourceLocationMake(line, column)) else {
                        DispatchQueue.main.async {
                            self.showNoDefinitionFound()
                        }
                        return
                    }
                    
                    DispatchQueue.main.async {
                        self.openDefinition(def)
                    }
                }
            }
        }
    }
    
    private func offsetToLineColumn(text: String, offset: Int) -> (line: Int, column: Int) {
        var currentOffset = 0
        var line = 1
        var column = 1
        
        for (i, char) in text.enumerated() {
            if i == offset { break }
            if char == "\n" {
                line += 1
                column = 1
            } else {
                column += 1
            }
            currentOffset += 1
        }
        
        return (line, column)
    }
    
    private func openDefinition(_ def: MDKFileSourceLocation) {
        /* check if definition is in the same file */
        if def.fileURL == self.file.fileURL {
            self.goto(location: def.location)
            return
        }
        
        /* check if file actually exists (could be a sdk header) */
        let fileExists = FileManager.default.fileExists(atPath: def.fileURL.path)
        
        if !fileExists {
            showNoDefinitionFound()
            return
        }
        
        /* open in a new read-only editor if its a system header, writable if its in the project */
        let isInsideProject: Bool
        if let project = self.project {
            isInsideProject = def.fileURL.path.hasPrefix(project.url.path)
        } else {
            isInsideProject = false
        }
        
        if UIDevice.current.userInterfaceIdiom != .pad {
            guard let destEditor = CodeEditorViewController(project: isInsideProject ? self.project : nil, url: def.fileURL, line: def.location.line, column: def.location.column, isReadOnly: !isInsideProject) else {
                return
            }
            let destEditorNav = UINavigationController(rootViewController: destEditor)
            destEditorNav.modalPresentationStyle = .pageSheet
            self.present(destEditorNav, animated: true);
        } else {
            NotificationCenter.default.post(name: Notification.Name("FileListAct"), object: ["open",def.fileURL.path,"\(def.location.line)","\(def.location.column)", isInsideProject ? "0" : "1"])
        }
    }
    
    private func showNoDefinitionFound() {
        let alert = UIAlertController(
            title: "No Definition Found",
            message: "Could not find a definition for the symbol at the cursor.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        self.present(alert, animated: true)
    }
    
    override func buildMenu(with builder: any UIMenuBuilder) {
        super.buildMenu(with: builder)
        
        guard self.languageServer != nil else {
            return
        }
        
        let myAction = UIAction(title: "Jump To Definition", image: UIImage(systemName: "cursorarrow")) { _ in
            self.jumpToDefinition()
        }

        builder.insertChild(UIMenu(options: .displayInline, children: [myAction]), atEndOfMenu: .standardEdit)
    }
    
    deinit {
        NXDocumentManager.shared().close(URL(fileURLWithPath: self.file.fileURL.path), completion: nil)
    }
}

// MARK: - Fork: find & replace and line editing commands
extension CodeEditorViewController {

    /// Line comment token for the current file type, or nil when the language has none we support.
    var lineCommentPrefix: String? {
        switch self.file.fileURL.pathExtension.lowercased() {
        case "c", "h", "m", "mm", "cpp", "hpp", "cc", "cxx", "swift":
            return "//"
        default:
            return nil
        }
    }

    // MARK: Find

    @objc func showFind() {
        self.presentFindNavigator(showingReplace: false)
    }

    @objc func showFindAndReplace() {
        self.presentFindNavigator(showingReplace: !self.isReadOnly)
    }

    @objc func findNextMatch() {
        self.textView.findInteraction?.findNext()
    }

    @objc func findPreviousMatch() {
        self.textView.findInteraction?.findPrevious()
    }

    private func presentFindNavigator(showingReplace: Bool) {
        if !self.textView.isFirstResponder {
            self.textView.becomeFirstResponder()
        }
        self.textView.findInteraction?.presentFindNavigator(showingReplace: showingReplace)
    }

    // MARK: Go to line

    @objc func promptGoToLine() {
        let alert = UIAlertController(title: "Go to Line", message: nil, preferredStyle: .alert)
        alert.addTextField { textField in
            textField.keyboardType = .numberPad
            textField.placeholder = "Line number"
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Go", style: .default) { [weak self, weak alert] _ in
            guard let self = self,
                  let text = alert?.textFields?.first?.text,
                  let line = Int(text.trimmingCharacters(in: .whitespaces)),
                  line > 0 else { return }
            self.goto(location: MDKSourceLocationMake(line, 1))
        })
        self.present(alert, animated: true)
    }

    // MARK: Line operations

    /// Programmatic edits must not be rewritten by the autoindent hook (e.g. a line that becomes just "}").
    private func replaceBypassingAutoindent(_ range: NSRange, with text: String) {
        let wasAutoIndenting = self.coordinator?.isAutoIndenting ?? false
        self.coordinator?.isAutoIndenting = true
        self.textView.replace(range, withText: text)
        self.coordinator?.isAutoIndenting = wasAutoIndenting
    }

    /// UTF-16 range covering every complete line touched by the selection (including the trailing newline, if any).
    private func selectedLinesRange() -> NSRange {
        let text = self.textView.text as NSString
        var selection = self.textView.selectedRange

        /* a selection that ends right after a newline should not pull in the following line */
        if selection.length > 0,
           selection.location + selection.length <= text.length,
           text.character(at: selection.location + selection.length - 1) == 0x0A {
            selection.length -= 1
        }

        return text.lineRange(for: selection)
    }

    /// Replaces the selected lines with the result of `transform` as a single undoable edit.
    private func transformSelectedLines(_ transform: ([String]) -> [String]) {
        guard !self.isReadOnly else { return }

        let text = self.textView.text as NSString
        let originalSelection = self.textView.selectedRange
        let range = self.selectedLinesRange()

        var block = text.substring(with: range)
        var trailingNewline = ""
        if block.hasSuffix("\n") {
            block.removeLast()
            trailingNewline = "\n"
        }

        let newBlock = transform(block.components(separatedBy: "\n")).joined(separator: "\n")
        guard newBlock != block else { return }

        self.replaceBypassingAutoindent(range, with: newBlock + trailingNewline)

        let newBlockLength = (newBlock as NSString).length
        if originalSelection.length == 0 {
            /* keep the caret on the same line, shifted by the change in length */
            let delta = newBlockLength - (block as NSString).length
            let caret = min(max(range.location, originalSelection.location + delta), range.location + newBlockLength)
            self.textView.selectedRange = NSRange(location: caret, length: 0)
        } else {
            self.textView.selectedRange = NSRange(location: range.location, length: newBlockLength)
        }
    }

    @objc func toggleComment() {
        guard let prefix = self.lineCommentPrefix else { return }

        self.transformSelectedLines { lines in
            let codeLines = lines.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            guard !codeLines.isEmpty else { return lines }

            let allCommented = codeLines.allSatisfy {
                $0.trimmingCharacters(in: .whitespaces).hasPrefix(prefix)
            }

            if allCommented {
                /* uncomment: remove the first prefix and one following space */
                return lines.map { line in
                    guard let prefixRange = line.range(of: prefix) else { return line }
                    var result = line
                    var end = prefixRange.upperBound
                    if end < result.endIndex, result[end] == " " {
                        end = result.index(after: end)
                    }
                    result.removeSubrange(prefixRange.lowerBound..<end)
                    return result
                }
            }

            /* comment: insert the prefix at the block's minimum indentation (Xcode style) */
            let indent = codeLines
                .map { $0.prefix(while: { $0 == " " || $0 == "\t" }).count }
                .min() ?? 0

            return lines.map { line in
                if line.trimmingCharacters(in: .whitespaces).isEmpty { return line }
                let index = line.index(line.startIndex, offsetBy: indent)
                return String(line[..<index]) + prefix + " " + String(line[index...])
            }
        }
    }

    @objc func indentLines() {
        self.transformSelectedLines { lines in
            lines.map { $0.isEmpty ? $0 : "\t" + $0 }
        }
    }

    @objc func outdentLines() {
        self.transformSelectedLines { lines in
            lines.map { line in
                if line.hasPrefix("\t") {
                    return String(line.dropFirst())
                }
                let leadingSpaces = line.prefix(while: { $0 == " " }).count
                return String(line.dropFirst(min(leadingSpaces, 4)))
            }
        }
    }

    @objc func moveLinesUp() {
        self.moveSelectedLines(up: true)
    }
    
    @objc func moveLinesDown() {
        self.moveSelectedLines(up: false)
    }
    
    /// Swaps the selected lines with the line above or below, keeping the selection on the moved text.
    private func moveSelectedLines(up: Bool) {
        guard !self.isReadOnly else { return }
        
        let text = self.textView.text as NSString
        let selection = self.textView.selectedRange
        let block = self.selectedLinesRange()
        let offsetInBlock = selection.location - block.location
        var blockText = text.substring(with: block)
        
        if up {
            guard block.location > 0 else { return }
            let previous = text.lineRange(for: NSRange(location: block.location - 1, length: 0))
            var previousText = text.substring(with: previous)
            
            /* the last line of a file has no newline: move the separator with it */
            if !blockText.hasSuffix("\n") {
                blockText += "\n"
                if previousText.hasSuffix("\n") { previousText.removeLast() }
            }
            
            let combined = NSRange(location: previous.location, length: block.location + block.length - previous.location)
            self.replaceBypassingAutoindent(combined, with: blockText + previousText)
            self.textView.selectedRange = NSRange(location: previous.location + offsetInBlock, length: selection.length)
        } else {
            let blockEnd = block.location + block.length
            guard blockEnd < text.length else { return }
            let next = text.lineRange(for: NSRange(location: blockEnd, length: 0))
            var nextText = text.substring(with: next)
            
            if !nextText.hasSuffix("\n") {
                nextText += "\n"
                if blockText.hasSuffix("\n") { blockText.removeLast() }
            }
            
            let combined = NSRange(location: block.location, length: next.location + next.length - block.location)
            self.replaceBypassingAutoindent(combined, with: nextText + blockText)
            self.textView.selectedRange = NSRange(location: block.location + (nextText as NSString).length + offsetInBlock, length: selection.length)
        }
    }
    
    @objc func duplicateLines() {
        guard !self.isReadOnly else { return }

        let text = self.textView.text as NSString
        let selection = self.textView.selectedRange
        let range = self.selectedLinesRange()
        let block = text.substring(with: range)
        let insertionPoint = NSRange(location: range.location + range.length, length: 0)

        /* the last line of a file has no trailing newline, so add one before the copy */
        let insertion = block.hasSuffix("\n") ? block : "\n" + block
        self.replaceBypassingAutoindent(insertionPoint, with: insertion)

        let shift = (insertion as NSString).length
        self.textView.selectedRange = NSRange(location: selection.location + shift, length: selection.length)
    }
}

// MARK: - Fork: code completion (phase 0: words, phase 1: Clang)

struct EditorCompletionItem {
    /// What replaces the typed prefix.
    let text: String
    /// Caret position inside `text` after inserting it (UTF-16); nil puts it at the end.
    var cursorOffset: Int? = nil
    /// What the list shows (a full signature for Clang results).
    let display: String
    /// Secondary text: a result type or where the word came from.
    let detail: String?
    let symbolName: String
    /// One-line documentation shown under the list for the selected row.
    var doc: String? = nil
}

/// The floating suggestion list shown under (or above) the caret.
final class CompletionPopupView: UIView, UITableViewDataSource, UITableViewDelegate {
    static let rowHeight: CGFloat = 32
    static let maximumVisibleRows = 7
    
    static let docHeight: CGFloat = 46
    
    var onPick: ((EditorCompletionItem) -> Void)?
    private(set) var selectedIndex = 0
    private let tableView = UITableView(frame: .zero, style: .plain)
    /* fork: documentation of the selected suggestion */
    private let docLabel = UILabel()
    private var docHeightConstraint: NSLayoutConstraint?
    
    /// True when some suggestion carries documentation, so the footer is shown.
    var hasDocs: Bool { items.contains { $0.doc != nil } }
    
    var items: [EditorCompletionItem] = [] {
        didSet {
            selectedIndex = 0
            tableView.reloadData()
            if !items.isEmpty {
                tableView.scrollToRow(at: IndexPath(row: 0, section: 0), at: .top, animated: false)
            }
            docHeightConstraint?.constant = hasDocs ? CompletionPopupView.docHeight : 0
            updateDoc()
        }
    }
    
    private func updateDoc() {
        docLabel.text = selectedItem?.doc ?? ""
    }
    
    var selectedItem: EditorCompletionItem? {
        items.indices.contains(selectedIndex) ? items[selectedIndex] : nil
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .secondarySystemBackground
        layer.cornerRadius = 10
        layer.borderWidth = 0.5
        layer.borderColor = UIColor.separator.cgColor
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.25
        layer.shadowRadius = 10
        layer.shadowOffset = CGSize(width: 0, height: 4)
        
        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = CompletionPopupView.rowHeight
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.layer.cornerRadius = 10
        tableView.clipsToBounds = true
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "completion")
        tableView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(tableView)
        
        docLabel.font = UIFont.systemFont(ofSize: 12)
        docLabel.textColor = .secondaryLabel
        docLabel.numberOfLines = 2
        docLabel.lineBreakMode = .byTruncatingTail
        docLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(docLabel)
        
        let docHeight = docLabel.heightAnchor.constraint(equalToConstant: 0)
        docHeightConstraint = docHeight
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: topAnchor),
            tableView.bottomAnchor.constraint(equalTo: docLabel.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: trailingAnchor),
            docLabel.bottomAnchor.constraint(equalTo: bottomAnchor),
            docLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            docLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            docHeight
        ])
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func moveSelection(by delta: Int) {
        guard items.count > 1 else { return }
        let previous = selectedIndex
        selectedIndex = (selectedIndex + delta + items.count) % items.count
        tableView.reloadRows(at: [IndexPath(row: previous, section: 0), IndexPath(row: selectedIndex, section: 0)], with: .none)
        tableView.scrollToRow(at: IndexPath(row: selectedIndex, section: 0), at: .none, animated: false)
        updateDoc()
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        items.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "completion", for: indexPath)
        let item = items[indexPath.row]
        var content = cell.defaultContentConfiguration()
        content.text = item.display
        content.textProperties.font = UIFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        content.textProperties.numberOfLines = 1
        content.textProperties.lineBreakMode = .byTruncatingTail
        content.secondaryText = item.detail
        content.secondaryTextProperties.font = UIFont.systemFont(ofSize: 11)
        content.secondaryTextProperties.color = .secondaryLabel
        content.secondaryTextProperties.numberOfLines = 1
        content.prefersSideBySideTextAndSecondaryText = true
        content.image = UIImage(systemName: item.symbolName)
        content.imageProperties.maximumSize = CGSize(width: 16, height: 16)
        content.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 2, leading: 10, bottom: 2, trailing: 10)
        cell.contentConfiguration = content
        cell.backgroundColor = indexPath.row == selectedIndex ? UIColor.tintColor.withAlphaComponent(0.25) : .clear
        cell.selectionStyle = .none
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard items.indices.contains(indexPath.row) else { return }
        onPick?(items[indexPath.row])
    }
}

/// Decides what to suggest while typing and inserts the chosen suggestion.
final class EditorCompletionController {
    /// Settings > Customization > "Code Completion".
    static var isEnabled: Bool { booleanDefaults(key: "LDECodeCompletion", defaultValue: true) }
    
    private weak var editor: CodeEditorViewController?
    private let popup = CompletionPopupView()
    private var projectWords: [String: Int] = [:]
    private var generation = 0
    private var isInserting = false
    private var replacementRange: NSRange?
    /// The compiler can take a moment (Swift above all); meanwhile keystrokes use word suggestions.
    private var engineBusy = false
    
    var isVisible: Bool { popup.superview != nil && !popup.isHidden }
    
    init(editor: CodeEditorViewController) {
        self.editor = editor
        popup.isHidden = true
        popup.onPick = { [weak self] item in self?.accept(item) }
        buildProjectIndex()
    }
    
    // MARK: triggers
    
    func textDidChange() {
        guard !isInserting, EditorCompletionController.isEnabled, let editor = editor, !editor.isReadOnly else {
            if !isInserting { hide() }
            return
        }
        
        let textView = editor.textView
        let selection = textView.selectedRange
        guard selection.length == 0 else { hide(); return }
        
        let text = textView.text
        let ns = text as NSString
        let caret = min(selection.location, ns.length)
        var start = caret
        while start > 0, EditorCompletionController.isIdentifierUnit(ns.character(at: start - 1)) {
            start -= 1
        }
        let prefix = ns.substring(with: NSRange(location: start, length: caret - start))
        
        /* the compilers know the members after "." (and "->" in C) even before anything is typed */
        let isClang = editor.file.isClang
        let afterMemberAccess = start > 0 && (editor.file.isSwift || isClang) && (
            ns.character(at: start - 1) == 0x2E /* . */ ||
            (isClang && start > 1 && ns.character(at: start - 1) == 0x3E /* > */ && ns.character(at: start - 2) == 0x2D /* - */)
        )
        
        if let first = prefix.unicodeScalars.first, CharacterSet.decimalDigits.contains(first) {
            hide()
            return
        }
        guard prefix.utf16.count >= 2 || afterMemberAccess else {
            hide()
            return
        }
        
        generation += 1
        let currentGeneration = generation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            guard let self = self, currentGeneration == self.generation else { return }
            self.compute(text: text, prefixStart: start, caret: caret, prefix: prefix, generation: currentGeneration)
        }
    }
    
    func selectionDidChange() {
        guard !isInserting, isVisible, let editor = editor, let range = replacementRange else { return }
        let selection = editor.textView.selectedRange
        /* keep the list while the caret stays at the end of the word being completed */
        if selection.length != 0 || selection.location < range.location || selection.location > range.location + range.length + 1 {
            hide()
        }
    }
    
    func hide() {
        generation += 1
        replacementRange = nil
        popup.isHidden = true
    }
    
    // MARK: keyboard
    
    func moveSelection(by delta: Int) {
        popup.moveSelection(by: delta)
    }
    
    func acceptSelected() {
        if let item = popup.selectedItem {
            accept(item)
        } else {
            hide()
        }
    }
    
    // MARK: computing suggestions
    
    private func compute(text: String, prefixStart: Int, caret: Int, prefix: String, generation currentGeneration: Int) {
        guard let editor = editor else { return }
        let wantsEngine = (editor.file.isClang || editor.file.isSwift) && !engineBusy
        let server = wantsEngine ? editor.languageServer : nil
        if server != nil { engineBusy = true }
        let words = projectWords
        let keywords = editor.file.isSwift ? EditorCompletionController.swiftWords : EditorCompletionController.cWords
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            var items: [EditorCompletionItem] = []
            
            /* phase 1 (Clang: C, Objective-C, C++) and phase 2 (Swift): the compiler's own completion */
            var usedEngine = false
            if let server = server {
                usedEngine = true
                let position = EditorCompletionController.lineAndUTF8Column(text, utf16Offset: prefixStart)
                if let raw = server.completions(line: position.line, utf8Column: position.column, content: text) {
                    items = EditorCompletionController.rankEngine(raw, prefix: prefix)
                }
            }
            
            /* phase 0: words from this file, the project and the language */
            if items.isEmpty, !prefix.isEmpty {
                items = EditorCompletionController.rankWords(prefix: prefix, projectWords: words, currentText: text, keywords: keywords)
            }
            
            DispatchQueue.main.async {
                if usedEngine { self?.engineBusy = false }
                guard let self = self, currentGeneration == self.generation, let editor = self.editor else { return }
                guard editor.textView.selectedRange.location == caret, editor.textView.selectedRange.length == 0 else { return }
                guard !items.isEmpty else {
                    self.hide()
                    return
                }
                self.replacementRange = NSRange(location: prefixStart, length: caret - prefixStart)
                self.show(items)
            }
        }
    }
    
    private func show(_ items: [EditorCompletionItem]) {
        guard let editor = editor else { return }
        let textView = editor.textView
        if popup.superview == nil {
            editor.view.addSubview(popup)
        }
        
        guard let end = textView.selectedTextRange?.end else {
            hide()
            return
        }
        let caretRect = textView.convert(textView.caretRect(for: end), to: editor.view)
        let bounds = editor.view.bounds
        let width = min(380, bounds.width - 16)
        let docsHeight: CGFloat = items.contains { $0.doc != nil } ? CompletionPopupView.docHeight : 0
        let height = CompletionPopupView.rowHeight * CGFloat(min(items.count, CompletionPopupView.maximumVisibleRows)) + docsHeight
        let x = min(max(8, caretRect.minX - 28), bounds.width - width - 8)
        let bottomLimit = bounds.height - textView.contentInset.bottom - 4
        var y = caretRect.maxY + 4
        if y + height > bottomLimit {
            y = caretRect.minY - height - 4
        }
        y = max(editor.view.safeAreaInsets.top + 4, y)
        
        /* size the list first, so scrolling it to the top happens with a real frame */
        popup.frame = CGRect(x: x, y: y, width: width, height: height)
        popup.layoutIfNeeded()
        popup.items = items
        popup.isHidden = false
        editor.view.bringSubviewToFront(popup)
    }
    
    private func accept(_ item: EditorCompletionItem) {
        guard let editor = editor, let start = replacementRange?.location else {
            hide()
            return
        }
        /* the word may have grown since the list was computed: replace up to the caret */
        let caret = editor.textView.selectedRange.location
        let length = (editor.textView.text as NSString).length
        guard caret >= start, caret <= length else {
            hide()
            return
        }
        let range = NSRange(location: start, length: caret - start)
        
        isInserting = true
        editor.insertCompletion(item.text, replacing: range, caretOffset: item.cursorOffset)
        isInserting = false
        hide()
    }
    
    // MARK: ranking
    
    private static func rankEngine(_ raw: [[String: Any]], prefix: String) -> [EditorCompletionItem] {
        let lowerPrefix = prefix.lowercased()
        var seen = Set<String>()
        var scored: [(item: EditorCompletionItem, exactCase: Bool, priority: Int)] = []
        
        for entry in raw {
            guard let text = entry["text"] as? String, !text.isEmpty else { continue }
            if !prefix.isEmpty {
                guard text.lowercased().hasPrefix(lowerPrefix), text != prefix else { continue }
            }
            let display = (entry["display"] as? String) ?? text
            guard seen.insert(display).inserted else { continue }
            let kind = (entry["kind"] as? NSNumber)?.intValue ?? 0
            let priority = (entry["priority"] as? NSNumber)?.intValue ?? 100
            let symbol: String = {
                switch kind {
                case 1: return "textformat"
                case 2: return "number"
                case 3: return "curlybraces"
                case 10: return "t.square"
                case 11: return "f.square"
                case 12: return "v.square"
                default: return "cube"
                }
            }()
            /* Swift results bring their own insertion text, e.g. "font()" with the caret inside */
            let insert = (entry["insert"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? text
            let cursor = (entry["cursor"] as? NSNumber)?.intValue
            let doc = (entry["doc"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            let item = EditorCompletionItem(text: insert, cursorOffset: cursor, display: display, detail: entry["type"] as? String, symbolName: symbol, doc: (doc?.isEmpty ?? true) ? nil : doc)
            scored.append((item, text.hasPrefix(prefix), priority))
        }
        
        return scored
            .sorted { lhs, rhs in
                if lhs.exactCase != rhs.exactCase { return lhs.exactCase }
                if lhs.priority != rhs.priority { return lhs.priority < rhs.priority }
                return lhs.item.text.count < rhs.item.text.count
            }
            .prefix(200)
            .map { $0.item }
    }
    
    private static let wordRegex = try? NSRegularExpression(pattern: "[A-Za-z_][A-Za-z0-9_]{2,}")
    
    private static func words(in text: String) -> [String: Int] {
        guard let regex = wordRegex else { return [:] }
        var counts: [String: Int] = [:]
        let ns = text as NSString
        regex.enumerateMatches(in: text, range: NSRange(location: 0, length: ns.length)) { match, _, _ in
            guard let match = match else { return }
            counts[ns.substring(with: match.range), default: 0] += 1
        }
        return counts
    }
    
    private static func rankWords(prefix: String, projectWords: [String: Int], currentText: String, keywords: [String]) -> [EditorCompletionItem] {
        let lowerPrefix = prefix.lowercased()
        var candidates: [String: (count: Int, source: String)] = [:]
        
        for keyword in keywords where keyword.lowercased().hasPrefix(lowerPrefix) {
            candidates[keyword] = (1, "keyword")
        }
        for (word, count) in projectWords where word.lowercased().hasPrefix(lowerPrefix) {
            candidates[word] = (count + (candidates[word]?.count ?? 0), "project")
        }
        /* words of the file being edited, without the partial word under the caret */
        var current = words(in: currentText)
        if let count = current[prefix] {
            if count <= 1 { current.removeValue(forKey: prefix) } else { current[prefix] = count - 1 }
        }
        for (word, count) in current where word.lowercased().hasPrefix(lowerPrefix) {
            candidates[word] = (count * 3 + (candidates[word]?.count ?? 0), "this file")
        }
        candidates.removeValue(forKey: prefix)
        
        return candidates
            .sorted { lhs, rhs in
                let lhsExact = lhs.key.hasPrefix(prefix)
                let rhsExact = rhs.key.hasPrefix(prefix)
                if lhsExact != rhsExact { return lhsExact }
                if lhs.value.count != rhs.value.count { return lhs.value.count > rhs.value.count }
                return lhs.key.count < rhs.key.count
            }
            .prefix(50)
            .map { word, info in
                EditorCompletionItem(
                    text: word,
                    display: word,
                    detail: info.source,
                    symbolName: info.source == "keyword" ? "textformat" : "character.cursor.ibeam"
                )
            }
    }
    
    private func buildProjectIndex() {
        guard let editor = editor, let project = editor.project else { return }
        let root: URL = project.url
        let isSwift = editor.file.isSwift
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let sourceExtensions: Set<String> = isSwift ? ["swift"] : ["c", "h", "m", "mm", "cpp", "cc", "cxx", "hpp", "hh"]
            var counts: [String: Int] = [:]
            var budget = 8 * 1024 * 1024
            for url in ProjectFileIndex.files(in: root) where sourceExtensions.contains(url.pathExtension.lowercased()) {
                guard budget > 0, let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
                budget -= text.utf8.count
                for (word, count) in EditorCompletionController.words(in: text) {
                    counts[word, default: 0] += count
                }
            }
            DispatchQueue.main.async {
                self?.projectWords = counts
            }
        }
    }
    
    // MARK: helpers
    
    private static func isIdentifierUnit(_ unit: unichar) -> Bool {
        (unit >= 0x30 && unit <= 0x39) || (unit >= 0x41 && unit <= 0x5A) || (unit >= 0x61 && unit <= 0x7A) || unit == 0x5F
    }
    
    /// 1-based line and UTF-8 byte column, as Clang expects them.
    private static func lineAndUTF8Column(_ text: String, utf16Offset: Int) -> (line: Int, column: Int) {
        let ns = text as NSString
        let before = ns.substring(to: min(utf16Offset, ns.length))
        var line = 1
        var bytesSinceNewline = 0
        for byte in before.utf8 {
            if byte == 0x0A {
                line += 1
                bytesSinceNewline = 0
            } else {
                bytesSinceNewline += 1
            }
        }
        return (line, bytesSinceNewline + 1)
    }
    
    // MARK: vocabularies
    
    static let swiftWords: [String] = [
        "associatedtype", "async", "await", "break", "case", "catch", "class", "continue", "default", "defer",
        "deinit", "didSet", "else", "enum", "extension", "fallthrough", "false", "fileprivate", "final", "func",
        "guard", "import", "init", "inout", "internal", "lazy", "let", "mutating", "nil", "nonisolated",
        "override", "private", "protocol", "public", "repeat", "rethrows", "return", "self", "Self", "some",
        "static", "struct", "subscript", "super", "switch", "throw", "throws", "true", "typealias", "where",
        "while", "willSet", "weak", "unowned", "convenience", "required", "optional", "indirect", "consuming",
        "Int", "Double", "Float", "Bool", "String", "Character", "Array", "Dictionary", "Set", "Optional",
        "Result", "Error", "Date", "Data", "URL", "UUID", "CGFloat", "CGPoint", "CGSize", "CGRect",
        "DispatchQueue", "Task", "MainActor", "FileManager", "UserDefaults", "JSONEncoder", "JSONDecoder",
        "Codable", "Identifiable", "Hashable", "Equatable", "Comparable", "ObservableObject", "Observable",
        "App", "Scene", "WindowGroup", "View", "ViewModifier", "State", "Binding", "StateObject", "ObservedObject",
        "EnvironmentObject", "Environment", "Published", "AppStorage", "FocusState", "Namespace",
        "VStack", "HStack", "ZStack", "LazyVStack", "LazyHStack", "LazyVGrid", "LazyHGrid", "GridItem", "Grid", "GridRow",
        "Text", "Label", "Image", "Button", "Toggle", "Picker", "Slider", "Stepper", "TextField", "SecureField",
        "TextEditor", "DatePicker", "ColorPicker", "Menu", "Link", "ShareLink", "ProgressView", "Gauge",
        "List", "ForEach", "Section", "Form", "ScrollView", "ScrollViewReader", "GeometryReader", "Spacer", "Divider",
        "NavigationStack", "NavigationSplitView", "NavigationLink", "NavigationPath", "TabView", "Group", "GroupBox",
        "DisclosureGroup", "Color", "LinearGradient", "RadialGradient", "Circle", "Rectangle", "RoundedRectangle",
        "Capsule", "Ellipse", "Path", "Canvas", "Chart", "LineMark", "BarMark", "PointMark", "AreaMark", "RuleMark",
        "padding", "frame", "font", "fontWeight", "foregroundStyle", "foregroundColor", "background", "overlay",
        "cornerRadius", "clipShape", "shadow", "opacity", "offset", "rotationEffect", "scaleEffect",
        "onAppear", "onDisappear", "onChange", "onTapGesture", "onSubmit", "task", "sheet", "fullScreenCover",
        "alert", "confirmationDialog", "popover", "toolbar", "ToolbarItem", "navigationTitle", "navigationBarTitleDisplayMode",
        "listStyle", "pickerStyle", "buttonStyle", "textFieldStyle", "disabled", "animation", "withAnimation",
        "transition", "matchedGeometryEffect", "keyboardType", "textInputAutocapitalization", "autocorrectionDisabled",
        "fileImporter", "fileExporter", "presentationDetents", "searchable", "refreshable", "swipeActions", "contextMenu"
    ]
    
    static let cWords: [String] = [
        "auto", "break", "case", "char", "const", "continue", "default", "do", "double", "else", "enum", "extern",
        "float", "for", "goto", "if", "inline", "int", "long", "register", "restrict", "return", "short", "signed",
        "sizeof", "static", "struct", "switch", "typedef", "union", "unsigned", "void", "volatile", "while",
        "bool", "true", "false", "NULL", "nullptr", "class", "namespace", "template", "typename", "public",
        "private", "protected", "virtual", "override", "const_cast", "static_cast", "dynamic_cast", "reinterpret_cast",
        "@interface", "@implementation", "@end", "@property", "@synthesize", "@protocol", "@selector", "@class",
        "nonatomic", "atomic", "strong", "weak", "copy", "assign", "readonly", "readwrite", "nullable", "nonnull",
        "self", "super", "nil", "YES", "NO", "instancetype", "NSObject", "NSString", "NSArray", "NSDictionary",
        "NSNumber", "NSData", "NSURL", "NSError", "NSLog", "UIView", "UIViewController", "UIColor", "UIImage",
        "dispatch_async", "dispatch_get_main_queue", "printf", "malloc", "free", "memcpy", "strlen"
    ]
}

extension CodeEditorViewController {
    /// Replaces the typed prefix with a completion as one undoable edit and puts the caret after it.
    func insertCompletion(_ text: String, replacing range: NSRange, caretOffset: Int? = nil) {
        let wasAutoIndenting = self.coordinator?.isAutoIndenting ?? false
        self.coordinator?.isAutoIndenting = true
        self.textView.replace(range, withText: text)
        self.coordinator?.isAutoIndenting = wasAutoIndenting
        let length = (text as NSString).length
        let caret = min(max(caretOffset ?? length, 0), length)
        self.textView.selectedRange = NSRange(location: range.location + caret, length: 0)
    }
    
    @objc func completionMoveUp() {
        self.completion?.moveSelection(by: -1)
    }
    
    @objc func completionMoveDown() {
        self.completion?.moveSelection(by: 1)
    }
    
    @objc func completionAccept() {
        self.completion?.acceptSelected()
    }
    
    @objc func completionDismiss() {
        self.completion?.hide()
    }
}

// MARK: - Fork: live editor registry (so project-wide edits reach open tabs)

enum LiveEditorRegistry {
    private static let editors = NSHashTable<CodeEditorViewController>.weakObjects()
    
    static func register(_ editor: CodeEditorViewController) {
        editors.add(editor)
    }
    
    /// The open, writable editor showing `path`, if any.
    static func editor(forPath path: String) -> CodeEditorViewController? {
        let wanted = URL(fileURLWithPath: path).resolvingSymlinksInPath().standardizedFileURL.path
        return editors.allObjects.first {
            !$0.isReadOnly && $0.file.fileURL.resolvingSymlinksInPath().standardizedFileURL.path == wanted
        }
    }
}

// MARK: - Fork: format document and rename symbol

/// Re-indents Swift code by brace depth (tabs), Xcode style: `case` lines align with their `switch`.
enum SwiftReindenter {
    static func reindent(_ text: String) -> String {
        var depth = 0
        var inBlockComment = false
        var inMultilineString = false
        var output: [String] = []
        
        for rawLine in text.components(separatedBy: "\n") {
            let trimmed = rawLine.trimmingCharacters(in: .whitespaces)
            
            /* multi-line string literals keep their exact text */
            if inMultilineString {
                output.append(rawLine)
                if trimmed.components(separatedBy: "\"\"\"").count - 1 > 0 {
                    inMultilineString = false
                }
                continue
            }
            if trimmed.isEmpty {
                output.append("")
                continue
            }
            
            var lineDepth = depth
            if !inBlockComment {
                var leadingClosers = 0
                for character in trimmed {
                    if character == "}" || character == ")" || character == "]" { leadingClosers += 1 } else { break }
                }
                lineDepth = max(depth - leadingClosers, 0)
                if trimmed.hasPrefix("case ") || trimmed.hasPrefix("default:") || trimmed.hasPrefix("@unknown default") {
                    lineDepth = max(lineDepth - 1, 0)
                }
            }
            
            let commentPad = (inBlockComment && trimmed.hasPrefix("*")) ? " " : ""
            output.append(String(repeating: "\t", count: lineDepth) + commentPad + trimmed)
            
            let scanned = scan(trimmed, depth: depth, inBlockComment: inBlockComment)
            depth = scanned.depth
            inBlockComment = scanned.inBlockComment
            inMultilineString = scanned.opensMultilineString
        }
        return output.joined(separator: "\n")
    }
    
    /// Follows brackets outside strings and comments.
    private static func scan(_ line: String, depth startDepth: Int, inBlockComment startInComment: Bool) -> (depth: Int, inBlockComment: Bool, opensMultilineString: Bool) {
        let characters = Array(line)
        var depth = startDepth
        var inBlockComment = startInComment
        var inString = false
        var index = 0
        
        while index < characters.count {
            let character = characters[index]
            let next: Character? = index + 1 < characters.count ? characters[index + 1] : nil
            
            if inBlockComment {
                if character == "*" && next == "/" { inBlockComment = false; index += 2; continue }
                index += 1
                continue
            }
            if inString {
                if character == "\\" { index += 2; continue }
                if character == "\"" { inString = false }
                index += 1
                continue
            }
            if character == "/" && next == "/" { break }
            if character == "/" && next == "*" { inBlockComment = true; index += 2; continue }
            if character == "\"" {
                /* a line that opens """ without closing it starts a multi-line string */
                if index + 2 < characters.count && characters[index + 1] == "\"" && characters[index + 2] == "\"" {
                    let rest = String(characters[(index + 3)...])
                    if !rest.contains("\"\"\"") {
                        return (max(depth, 0), inBlockComment, true)
                    }
                    if let range = rest.range(of: "\"\"\"") {
                        index += 3 + rest.distance(from: rest.startIndex, to: range.upperBound)
                        continue
                    }
                }
                inString = true
                index += 1
                continue
            }
            switch character {
            case "{", "(", "[": depth += 1
            case "}", ")", "]": depth = max(depth - 1, 0)
            default: break
            }
            index += 1
        }
        return (depth, inBlockComment, false)
    }
}

extension CodeEditorViewController {
    /// Replaces the whole text as one undoable edit, keeping the caret near where it was.
    func replaceWholeText(_ newText: String) {
        let oldText = self.textView.text
        guard newText != oldText else { return }
        let caret = self.textView.selectedRange.location
        let oldLength = (oldText as NSString).length
        self.replaceBypassingAutoindent(NSRange(location: 0, length: oldLength), with: newText)
        let newLength = (newText as NSString).length
        self.textView.selectedRange = NSRange(location: min(caret, newLength), length: 0)
    }
    
    @objc func formatDocument() {
        guard !self.isReadOnly else { return }
        let original = self.textView.text
        var formatted: String? = nil
        if self.file.isClang {
            formatted = MDKASTUnit.formattedSource(original, fileName: self.file.fileURL.lastPathComponent)
        } else if self.file.isSwift {
            formatted = SwiftReindenter.reindent(original)
        }
        guard let result = formatted else { return }
        self.replaceWholeText(result)
    }
    
    /// The identifier under (or right before) the caret.
    private func identifierAtCaret() -> String? {
        let text = self.textView.text as NSString
        let selection = self.textView.selectedRange
        if selection.length > 0 {
            let selected = text.substring(with: selection)
            return SymbolRenamer.isIdentifier(selected) ? selected : nil
        }
        func isIdentifierUnit(_ unit: unichar) -> Bool {
            (unit >= 0x30 && unit <= 0x39) || (unit >= 0x41 && unit <= 0x5A) || (unit >= 0x61 && unit <= 0x7A) || unit == 0x5F
        }
        var start = min(selection.location, text.length)
        var end = start
        while start > 0, isIdentifierUnit(text.character(at: start - 1)) { start -= 1 }
        while end < text.length, isIdentifierUnit(text.character(at: end)) { end += 1 }
        guard end > start else { return nil }
        let word = text.substring(with: NSRange(location: start, length: end - start))
        return SymbolRenamer.isIdentifier(word) ? word : nil
    }
    
    @objc func promptRenameSymbol() {
        guard !self.isReadOnly else { return }
        guard let symbol = identifierAtCaret() else {
            let alert = UIAlertController(title: "Rename Symbol", message: "Place the cursor on a name first.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            self.present(alert, animated: true)
            return
        }
        
        let alert = UIAlertController(title: "Rename \"\(symbol)\"", message: "Whole-word replacement in every project file.", preferredStyle: .alert)
        alert.addTextField { field in
            field.text = symbol
            field.autocapitalizationType = .none
            field.autocorrectionType = .no
            field.clearButtonMode = .whileEditing
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Continue", style: .default) { [weak self, weak alert] _ in
            guard let self = self,
                  let newName = alert?.textFields?.first?.text?.trimmingCharacters(in: .whitespaces),
                  newName != symbol else { return }
            guard SymbolRenamer.isIdentifier(newName) else {
                let invalid = UIAlertController(title: "Invalid Name", message: "\"\(newName)\" is not a valid identifier.", preferredStyle: .alert)
                invalid.addAction(UIAlertAction(title: "OK", style: .default))
                self.present(invalid, animated: true)
                return
            }
            self.confirmRename(symbol, to: newName)
        })
        self.present(alert, animated: true)
    }
    
    private func confirmRename(_ symbol: String, to newName: String) {
        let plan = SymbolRenamer.plan(renaming: symbol, to: newName, in: self.project, currentEditor: self)
        guard plan.occurrences > 0 else { return }
        
        let fileWord = plan.changes.count == 1 ? "file" : "files"
        let alert = UIAlertController(
            title: "Rename to \"\(newName)\"?",
            message: "\(plan.occurrences) occurrence\(plan.occurrences == 1 ? "" : "s") in \(plan.changes.count) \(fileWord). Matches in comments and strings are renamed too. Open files can be undone with ⌘Z; closed files are written directly.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Rename", style: .destructive) { _ in
            let failures = SymbolRenamer.apply(plan)
            if !failures.isEmpty {
                NXAlertDiagnosticPresenter.notifyUser(with: .error, withMessage: "Could not write: \(failures.joined(separator: ", "))", withDelay: 0.0)
            }
        })
        self.present(alert, animated: true)
    }
}

/// Text-based, whole-word renaming across the project.
enum SymbolRenamer {
    struct Change {
        let url: URL
        let newText: String
        let count: Int
    }
    
    struct Plan {
        let changes: [Change]
        var occurrences: Int { changes.reduce(0) { $0 + $1.count } }
    }
    
    static func isIdentifier(_ text: String) -> Bool {
        text.range(of: "^[A-Za-z_][A-Za-z0-9_]*$", options: .regularExpression) != nil
    }
    
    static func plan(renaming symbol: String, to newName: String, in project: NXProject?, currentEditor: CodeEditorViewController) -> Plan {
        guard let regex = try? NSRegularExpression(pattern: "(?<![A-Za-z0-9_])" + NSRegularExpression.escapedPattern(for: symbol) + "(?![A-Za-z0-9_])") else {
            return Plan(changes: [])
        }
        let template = NSRegularExpression.escapedTemplate(for: newName)
        
        var urls: [URL] = []
        if let project = project {
            let root: URL = project.url
            urls = ProjectFileIndex.files(in: root)
        }
        let currentURL = currentEditor.file.fileURL
        if !urls.contains(where: { $0.resolvingSymlinksInPath().path == currentURL.resolvingSymlinksInPath().path }) {
            urls.append(currentURL)
        }
        
        var changes: [Change] = []
        for url in urls {
            let live = LiveEditorRegistry.editor(forPath: url.path)
            guard let text = live?.textView.text ?? (try? String(contentsOf: url, encoding: .utf8)) else { continue }
            let range = NSRange(location: 0, length: (text as NSString).length)
            let count = regex.numberOfMatches(in: text, range: range)
            guard count > 0 else { continue }
            let newText = regex.stringByReplacingMatches(in: text, range: range, withTemplate: template)
            changes.append(Change(url: url, newText: newText, count: count))
        }
        return Plan(changes: changes)
    }
    
    /// Applies the plan; returns the names of files that could not be written.
    static func apply(_ plan: Plan) -> [String] {
        var failures: [String] = []
        for change in plan.changes {
            if let editor = LiveEditorRegistry.editor(forPath: change.url.path) {
                editor.replaceWholeText(change.newText)
            } else if (try? change.newText.write(to: change.url, atomically: true, encoding: .utf8)) == nil {
                failures.append(change.url.lastPathComponent)
            }
        }
        return failures
    }
}

// MARK: - Fork: parameter help (signature help)

/// The bubble above the caret showing the called function's signature.
final class SignatureHelpView: UIView {
    private let signatureLabel = UILabel()
    private let docLabel = UILabel()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .secondarySystemBackground
        layer.cornerRadius = 10
        layer.borderWidth = 0.5
        layer.borderColor = UIColor.separator.cgColor
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.2
        layer.shadowRadius = 8
        layer.shadowOffset = CGSize(width: 0, height: 3)
        isUserInteractionEnabled = false
        
        signatureLabel.numberOfLines = 3
        docLabel.numberOfLines = 2
        docLabel.font = UIFont.systemFont(ofSize: 12)
        docLabel.textColor = .secondaryLabel
        
        let stack = UIStackView(arrangedSubviews: [signatureLabel, docLabel])
        stack.axis = .vertical
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12)
        ])
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func configure(text: String, activeRange: NSRange?, doc: String?, overloads: Int) {
        let font = UIFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        let attributed = NSMutableAttributedString(string: text, attributes: [.font: font, .foregroundColor: UIColor.label])
        if let range = activeRange, range.location + range.length <= (text as NSString).length {
            attributed.addAttributes([
                .font: UIFont.monospacedSystemFont(ofSize: 13, weight: .bold),
                .foregroundColor: UIColor.tintColor
            ], range: range)
        }
        if overloads > 1 {
            attributed.append(NSAttributedString(string: "   +\(overloads - 1)", attributes: [
                .font: UIFont.systemFont(ofSize: 11),
                .foregroundColor: UIColor.secondaryLabel
            ]))
        }
        signatureLabel.attributedText = attributed
        docLabel.text = doc
        docLabel.isHidden = (doc ?? "").isEmpty
    }
}

/// Asks the compiler for the signature of the call being typed and keeps the bubble up to date.
final class SignatureHelpController {
    private weak var editor: CodeEditorViewController?
    private let bubble = SignatureHelpView()
    private var generation = 0
    private var busy = false
    private var anchorLine: Int?
    
    var isVisible: Bool { bubble.superview != nil && !bubble.isHidden }
    
    init(editor: CodeEditorViewController) {
        self.editor = editor
        bubble.isHidden = true
    }
    
    func textDidChange() {
        guard EditorCompletionController.isEnabled, let editor = editor, !editor.isReadOnly,
              editor.file.isClang || editor.file.isSwift else { return }
        let text = editor.textView.text as NSString
        let caret = editor.textView.selectedRange.location
        guard caret > 0, caret <= text.length else { hide(); return }
        let typed = text.character(at: caret - 1)
        
        if typed == 0x29 /* ) */ {
            hide()
            return
        }
        /* open on "(" and ","; while open, follow every edit so the active argument moves */
        if typed == 0x28 /* ( */ || typed == 0x2C /* , */ || isVisible {
            request()
        }
    }
    
    func selectionDidChange() {
        guard isVisible, let editor = editor, let line = anchorLine else { return }
        if currentLine(in: editor) != line {
            hide()
        }
    }
    
    func hide() {
        generation += 1
        anchorLine = nil
        bubble.isHidden = true
    }
    
    /// Shows the signature for the call around the caret (also used by ⌃⇧Space).
    func request() {
        guard let editor = editor, let server = editor.languageServer, !busy else { return }
        generation += 1
        let currentGeneration = generation
        let text = editor.textView.text
        let caret = editor.textView.selectedRange.location
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            guard let self = self, currentGeneration == self.generation, !self.busy else { return }
            self.busy = true
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                let position = SignatureHelpController.lineAndUTF8Column(text, utf16Offset: caret)
                let help = server.signatureHelp(line: position.line, utf8Column: position.column, content: text)
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    self.busy = false
                    guard currentGeneration == self.generation, let editor = self.editor,
                          editor.textView.selectedRange.location == caret else { return }
                    guard let help = help, let signature = help["text"] as? String, !signature.isEmpty else {
                        self.hide()
                        return
                    }
                    var active: NSRange? = nil
                    if let start = (help["activeStart"] as? NSNumber)?.intValue,
                       let length = (help["activeLength"] as? NSNumber)?.intValue, length > 0 {
                        active = NSRange(location: start, length: length)
                    }
                    let doc = (help["doc"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
                    let overloads = (help["count"] as? NSNumber)?.intValue ?? 1
                    self.show(text: signature, active: active, doc: doc, overloads: overloads)
                }
            }
        }
    }
    
    private func show(text: String, active: NSRange?, doc: String?, overloads: Int) {
        guard let editor = editor, let end = editor.textView.selectedTextRange?.end else { return }
        if bubble.superview == nil {
            editor.view.addSubview(bubble)
        }
        bubble.configure(text: text, activeRange: active, doc: doc, overloads: overloads)
        
        let bounds = editor.view.bounds
        let width = min(560, bounds.width - 16)
        let size = bubble.systemLayoutSizeFitting(
            CGSize(width: width, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        )
        let caretRect = editor.textView.convert(editor.textView.caretRect(for: end), to: editor.view)
        let x = min(max(8, caretRect.minX - 40), bounds.width - width - 8)
        /* above the caret line; the suggestion list uses the space below */
        var y = caretRect.minY - size.height - 6
        if y < editor.view.safeAreaInsets.top + 4 {
            y = caretRect.maxY + 6
        }
        bubble.frame = CGRect(x: x, y: y, width: width, height: size.height)
        bubble.isHidden = false
        anchorLine = currentLine(in: editor)
        editor.view.bringSubviewToFront(bubble)
    }
    
    private func currentLine(in editor: CodeEditorViewController) -> Int {
        let text = editor.textView.text as NSString
        let caret = min(editor.textView.selectedRange.location, text.length)
        return text.substring(to: caret).utf16.reduce(0) { $1 == 0x0A ? $0 + 1 : $0 }
    }
    
    private static func lineAndUTF8Column(_ text: String, utf16Offset: Int) -> (line: Int, column: Int) {
        let ns = text as NSString
        let before = ns.substring(to: min(utf16Offset, ns.length))
        var line = 1
        var bytesSinceNewline = 0
        for byte in before.utf8 {
            if byte == 0x0A {
                line += 1
                bytesSinceNewline = 0
            } else {
                bytesSinceNewline += 1
            }
        }
        return (line, bytesSinceNewline + 1)
    }
}

extension CodeEditorViewController {
    @objc func signatureHelpShow() {
        self.signatureHelp?.request()
    }
    
    @objc func signatureHelpDismiss() {
        self.signatureHelp?.hide()
    }
}

// MARK: - Fork: fix-its

/// One compiler-suggested fix: where the issue is and the edits that resolve it.
struct EditorFixIt {
    struct Edit {
        let startLine: Int
        let startColumn: Int
        let endLine: Int
        let endColumn: Int
        let text: String
    }
    let line: Int
    let message: String
    let edits: [Edit]
    
    init?(_ raw: [String: Any]) {
        guard let line = (raw["line"] as? NSNumber)?.intValue,
              let rawEdits = raw["edits"] as? [[String: Any]] else { return nil }
        self.line = line
        self.message = (raw["message"] as? String) ?? "Fix"
        self.edits = rawEdits.compactMap { edit in
            guard let startLine = (edit["startLine"] as? NSNumber)?.intValue,
                  let startColumn = (edit["startColumn"] as? NSNumber)?.intValue,
                  let endLine = (edit["endLine"] as? NSNumber)?.intValue,
                  let endColumn = (edit["endColumn"] as? NSNumber)?.intValue else { return nil }
            return Edit(startLine: startLine, startColumn: startColumn, endLine: endLine, endColumn: endColumn, text: (edit["text"] as? String) ?? "")
        }
        if self.edits.isEmpty { return nil }
    }
}

enum FixItApplier {
    /// UTF-16 offset of a 1-based line and UTF-8 byte column.
    static func utf16Offset(in text: String, line: Int, column: Int) -> Int? {
        let bytes = Array(text.utf8)
        var currentLine = 1
        var index = 0
        while currentLine < line {
            guard let newline = bytes[index...].firstIndex(of: 0x0A) else { return nil }
            index = newline + 1
            currentLine += 1
        }
        let byte = index + max(column, 1) - 1
        guard byte <= bytes.count else { return nil }
        let utf8Index = text.utf8.index(text.utf8.startIndex, offsetBy: byte)
        guard let position = utf8Index.samePosition(in: text.utf16) else { return nil }
        return text.utf16.distance(from: text.utf16.startIndex, to: position)
    }
    
    /// Applies the edits of several fixes to `text`, back to front, skipping overlaps.
    static func apply(_ fixes: [EditorFixIt], to text: String) -> String? {
        var ranges: [(range: NSRange, text: String)] = []
        for fix in fixes {
            for edit in fix.edits {
                guard let start = utf16Offset(in: text, line: edit.startLine, column: edit.startColumn),
                      let end = utf16Offset(in: text, line: edit.endLine, column: edit.endColumn),
                      end >= start else { continue }
                ranges.append((NSRange(location: start, length: end - start), edit.text))
            }
        }
        guard !ranges.isEmpty else { return nil }
        
        ranges.sort { $0.range.location > $1.range.location }
        let result = NSMutableString(string: text)
        var lowestApplied = Int.max
        for item in ranges {
            /* a later (already applied) edit starting before this one ends would overlap */
            guard item.range.location + item.range.length <= lowestApplied else { continue }
            result.replaceCharacters(in: item.range, with: item.text)
            lowestApplied = item.range.location
        }
        return result as String
    }
}

extension CodeEditorViewController {
    /// Re-checks the current text, then hands the fresh fixes to `completion` on the main queue.
    private func fetchFreshFixIts(_ completion: @escaping ([EditorFixIt]) -> Void) {
        guard let server = self.languageServer else {
            completion([])
            return
        }
        let text = self.textView.text
        let isSwift = self.file.isSwift
        let flags: [String] = self.isReadOnly ? (NXProjectConfig.sdkCompilerFlags() ?? []) : (self.project?.projectConfig.compilerFlags ?? [])
        let swiftFlags: [String] = self.project?.projectConfig.swiftFlags ?? []
        let projectPath = self.project?.url.path
        
        DispatchQueue.global(qos: .userInitiated).async {
            if isSwift {
                let swiftFiles: [String] = LDEFilesFinder(projectPath, ["swift"], ["Resources", "Config"])
                server.reparseFile(text, withArgs: swiftFlags + swiftFiles)
            } else {
                server.reparseFile(text, withArgs: flags)
            }
            let fixes = server.getFixIts().compactMap { EditorFixIt($0) }
            DispatchQueue.main.async {
                completion(fixes)
            }
        }
    }
    
    private func currentLineNumber() -> Int {
        let text = self.textView.text as NSString
        let caret = min(self.textView.selectedRange.location, text.length)
        return text.substring(to: caret).utf16.reduce(1) { $1 == 0x0A ? $0 + 1 : $0 }
    }
    
    private func applyFixes(_ fixes: [EditorFixIt]) {
        let original = self.textView.text
        guard let fixed = FixItApplier.apply(fixes, to: original) else { return }
        self.replaceWholeText(fixed)
    }
    
    private func showFixMessage(_ title: String, _ message: String?) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        self.present(alert, animated: true)
    }
    
    @objc func fixIssueOnCurrentLine() {
        guard !self.isReadOnly, self.languageServer != nil else { return }
        let line = currentLineNumber()
        fetchFreshFixIts { [weak self] fixes in
            guard let self = self else { return }
            let onLine = fixes.filter { $0.line == line }
            guard !onLine.isEmpty else {
                self.showFixMessage("No Fix Available", "The compiler has no suggested fix for line \(line).")
                return
            }
            if onLine.count == 1 {
                self.applyFixes(onLine)
                return
            }
            let sheet = UIAlertController(title: "Fix Line \(line)", message: nil, preferredStyle: .actionSheet)
            for fix in onLine {
                sheet.addAction(UIAlertAction(title: fix.message, style: .default) { [weak self] _ in
                    self?.applyFixes([fix])
                })
            }
            sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            if let popover = sheet.popoverPresentationController {
                popover.sourceView = self.view
                popover.sourceRect = CGRect(x: self.view.bounds.midX, y: self.view.bounds.midY, width: 0, height: 0)
                popover.permittedArrowDirections = []
            }
            self.present(sheet, animated: true)
        }
    }
    
    @objc func fixAllIssues() {
        guard !self.isReadOnly, self.languageServer != nil else { return }
        fetchFreshFixIts { [weak self] fixes in
            guard let self = self else { return }
            guard !fixes.isEmpty else {
                self.showFixMessage("No Fixes Available", "The compiler has no suggested fixes for this file.")
                return
            }
            let alert = UIAlertController(
                title: "Apply \(fixes.count) Fix\(fixes.count == 1 ? "" : "es")?",
                message: fixes.prefix(6).map { "• Line \($0.line): \($0.message)" }.joined(separator: "\n") + (fixes.count > 6 ? "\n…" : ""),
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            alert.addAction(UIAlertAction(title: "Apply", style: .default) { [weak self] _ in
                self?.applyFixes(fixes)
            })
            self.present(alert, animated: true)
        }
    }
}
