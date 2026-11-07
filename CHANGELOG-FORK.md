# Fork doctoralvarez/Nyxian — Changelog

Fork version is tracked here and in each modified file's header.
The app's `VERSION` in `Config.xcconfig` is intentionally left untouched:
Nyxian uses it to check compatibility with emexLabs OTA updates.

## 1.15.0 — 2026-11-07

- **Jump to Definition** now also in Swift files, with **⌃⌘J** (and the edit
  menu as before). SDK symbols say which module defines them.
- **Find References** (**⇧⌃⌘F**, or the edit menu): every whole-word match in
  the project's files of the same language; in Swift each match is checked by
  the compiler (same symbol, not only the same name). C/Objective-C results
  are text matches.

## 1.14.1 — 2026-11-07

- Build fix for 1.14.0 (console view initializer).

## 1.14.0 — 2026-11-07

- **Document Symbols** (⌃6, or the list button in the editor toolbar):
  functions, types, properties, enum cases and `MARK` sections of the file
  (Swift, C, C++, Objective-C), filterable; tap to jump.
- **Recent tabs** (iPad): ⌃⇥ goes to the previously used tab (again to come
  back), ⌃⇧⇥ to the least recently used one.
- **Faster Swift rebuilds**: when no Swift file changed since the last build
  (and the flags are the same), the Swift compiler is skipped and only the
  link runs. Any Swift change still recompiles all Swift files.
- **iPhone console**: the app's `print()` output goes to a **Console** window
  (project ⋯ menu > Console) that lives next to the app in the window
  switcher — no new edge gestures.
- **GitHub: review before pushing**: *Commit and Push…* first lists the files
  modified / added / deleted since the last sync with +/− line counts; tap a
  file for its line diff, then *Commit…*.
- Code folding is not included: the editor engine (Runestone) cannot hide
  lines.

## 1.13.0 — 2026-11-07

- **App icons**: importing a `.swiftpm` turns its `AppIcon` into a real icon
  (loose PNGs + `CFBundleIcons`, no asset catalog compiler needed);
  long-press a project > **Set App Icon…** for any project; the project list
  shows the icon; exporting writes `AppIcon.appiconset` and
  `appIcon: .asset("AppIcon")`.
- **Permissions**: `capabilities` with a `purposeString` (camera, photos,
  location, microphone, contacts, calendars, Face ID, Bluetooth…) become
  Info.plist usage descriptions on import, and go back to `capabilities` on
  export (the original block is reused when the project came from a package).
- **Update from .swiftpm…** (long-press a project): re-imports a package into
  the existing project, replacing its Swift files.

## 1.12.0 — 2026-11-07

- **No TeamWin splash on launch**: normal launches show a plain background
  while the IDE loads. Recovery > Settings > *Show TeamWin boot splash* brings
  the image back; verbose boot still shows its console.
- **Faster launch**: when booting the bundled IDE with a TrustStore already
  installed, the TrustStore check runs in the background instead of holding
  the launch for up to 4 seconds. The 1-second volume-button window stays, as
  it is the way into Recovery.

## 1.11.2 — 2026-11-07

- **.swiftpm export fix**: Swift Playgrounds rejected the manifest
  ("PlaceholderIcon has no member 'gear'"). The default icon is now `.leaf`.
- Imported `.swiftpm` apps keep their original manifest in
  `Config/SwiftPlaygrounds-Package.swift.txt`; exporting them back reuses its
  placeholder icon and accent color. (Projects imported before 1.11.2 use the
  defaults.)

## 1.11.1 — 2026-11-07

- **Link fix** for apps whose display name differs from the executable name
  (typical of imported `.swiftpm` apps, e.g. "ZCS Explorer" / `ZCSExplorer`):
  the linker wrote into `Payload/<display name>.app`, but the builder only
  creates `Payload/<executable>.app` ("failed to open … No such file or
  directory"). `-[NXProject machoURL]` now redirects into the real bundle, so
  already-imported projects work without re-importing; new projects and the
  importer use `$(NXExecutable).app`.

## 1.11.0 — 2026-11-07

- **Export as Swift Playgrounds App (.swiftpm)**: long-press a project, or
  swipe it right > Export. Writes `Package.swift` (`.iOSApplication`, target
  `AppModule`, path `.`), copies the Swift files with their folders, turns loose
  images (`name.png`, `name@2x.png`…) into `Assets.xcassets` image sets, puts
  other resources in `Resources/` and saves the package with "Export to Files".
  It warns about C/Objective-C files (left out), a missing SwiftUI `@main App`,
  `Bundle.module`, and usage descriptions to re-add in App Settings.
- **Swipe actions in the project list**: swipe left for **Delete** (asks
  first), swipe right for **Export** (Nyxian `.zip` or `.swiftpm`).

## 1.10.0 — 2026-11-07

- **GitHub sync** without a git binary (REST "Git Data" API):
  - ⋯ > **GitHub** in a project: *Commit and Push…*, *Pull*, *Repository…*
    (owner/repo + branch) and *Account…* (personal access token, kept in the
    Keychain of this device only).
  - Push refuses when GitHub has commits the project does not have (pull
    first). The first push into an existing branch keeps the files that only
    exist on GitHub.
  - Pull never overwrites a file you changed since the last sync (it is
    reported as a conflict) and only deletes local files you did not touch.
  - The sync state lives in `Config/GitHub.plist`, which is never pushed.
- **Clone from GitHub…** in the import button of the Projects screen: a Nyxian
  project is downloaded and stays linked; a Swift Playgrounds app
  (`Package.swift`) is converted like an imported `.swiftpm`.

## 1.9.1 — 2026-11-07

- Build fix for 1.7.0: `MDKFile.fileURL` is optional in Swift; the open-tabs
  registry and Rename Symbol now unwrap it.

## 1.9.0 — 2026-11-07

- **Fix-its**: **⌥⌘↩** (or the new wrench button in the editor toolbar) applies
  the compiler's suggested fix for the caret's line (a list when there are
  several); **⌃⌥⌘F** applies every fix in the file after a confirmation. The file
  is re-checked first so the positions match what is on screen; the result is
  a single undoable edit.
- Fixes come from Clang's stored diagnostics and from Swift's
  `DiagnosticInfo::FixIts` (`CCASTUnitCopyFixIts`, `-[MDKASTUnit fixIts]`,
  `-[NXLanguageServer getFixIts]`).

## 1.8.0 — 2026-11-07

- **Parameter help**: typing `(` or `,` in a call shows a bubble above the caret
  with the function's signature, the current argument in bold and its
  documentation; `)` or moving to another line closes it, **Esc** too, and
  **⌃⇧Space** shows it on demand. Swift uses the compiler's signature help
  (`IDEInspectionInstance::signatureHelp`); C/ObjC/C++ use Clang's overloads.
- **Documentation in suggestions**: the selected suggestion's doc comment is shown
  under the list (Clang brief comments, Swift doc comments).
- `CCASTUnitCopySignatureHelpAtLocation`, `-[MDKASTUnit signatureHelpAtLocation:]`,
  `-[NXLanguageServer signatureHelpAtLine:utf8Column:content:]`.

## 1.7.0 — 2026-11-07

- **Format Document (⌃I)**: C, Objective-C and C++ with clang-format (LLVM style,
  tab indentation, lines are never re-wrapped; `CCCopyFormattedSource`);
  Swift with a brace-depth re-indenter (`case` aligned with `switch`,
  multi-line strings left untouched). One undoable edit.
- **Rename Symbol (⌃⌘E)**: whole-word rename across every project text file.
  Shows how many occurrences in how many files before applying. Open tabs are
  edited in place (undo with ⌘Z); closed files are written directly. Text
  based: matches in comments and strings are renamed too.
- **Customization toggles**: "Code Completion" and "Shortcut List (hold ⌘)".
- Console tap-to-open stays iPad-only: the iPhone layout has no console pane.

## 1.6.0 — 2026-11-07

- **Shortcut list**: hold **⌘ alone for 2 seconds** to see the keyboard
  shortcuts of the current screen (read live from the app's key commands, with
  Spanish names). It closes when ⌘ is released or any other key is pressed.
  Uses GameController's keyboard input (`KeyboardShortcutsHUD`, ContentView.swift).
- **Fork version in Settings**: the footer shows "Fork doctoralvarez 1.6.0" under
  Nyxian's own version. Source of truth: `NYXIAN_FORK_VERSION` in
  `Config.xcconfig` (→ `NXForkVersion` in Info.plist); bump it with every release.
- **Editor font size 20 by default** (was 12); the stepper now goes up to 32. An
  existing setting still at the old default 12 is moved to 20 once.

## 1.5.0 — 2026-11-07

### Code completion phase 2: Swift
- Swift files get completions from the Swift compiler itself
  (`swift::ide::IDEInspectionInstance`, the engine behind SourceKit), already
  bundled in Nyxian's toolchain (`libswiftIDE`/`libswiftIDETool`), so no LLVM
  rebuild was needed.
- Understands types: members after `.`, argument labels, result types; nearer
  scopes (locals, members, this module) are listed before the SDK.
- Functions are inserted as `name()` with the caret inside the parentheses.
- The engine keeps the last type-checked AST and reuses it while typing inside
  function bodies. While it is busy, keystrokes use the word suggestions.
- Files: `CCASTUnit.cpp/.h`, `NXLanguageServer.h/.m`, `CodeEditor.swift`.

## 1.4.1 — 2026-11-07

- Build fix in `CCASTUnit.cpp`: include `clang/Frontend/FrontendActions.h`.

## 1.4.0 — 2026-11-07

### Code completion (improvement 9, phases 0 and 1)
- A suggestion list appears under the caret after typing 2+ letters of a word.
  **Tab** or **Return** accepts, **↑/↓** choose, **Esc** dismisses, or tap a row.
- **Phase 0 (all languages, Swift included):** words from the file being edited,
  the rest of the project and a built-in vocabulary (Swift keywords, common
  Swift/SwiftUI/Charts names; C/Objective-C keywords and common APIs).
- **Phase 1 (C, Objective-C, C++):** real completions from Clang
  (`ASTUnit::CodeComplete`), including members after `.` and `->`, with result
  types. Falls back to phase 0 until the file has been parsed once.
- Files: `CCASTUnit.cpp/.h` (CoreCompiler), `MDKASTUnit.h/.m`,
  `NXLanguageServer.h/.m`, `CodeEditor.swift`, `CodeEditorCoordinator.swift`.

## 1.3.1 — 2026-11-07

- Build fix in `FileList.swift` (search / quick open): `project.url` stored as a
  non-optional `URL`.

## 1.3.0 — 2026-11-07

### Editor and workspace
- **Search in Project** (⇧⌘F on iPad, or ⋯ > Search in Project): finds text in
  every project file; tapping a result opens the file at that line.
- **Open Quickly** (⇧⌘O on iPad, or ⋯ > Open Quickly): type part of a file name.
- **Move lines** up / down with ⌥⌘↑ / ⌥⌘↓.
- **Tappable runtime errors**: "file X.swift, line N" (Swift traps) and
  "path/X.swift:N:M" printed in the iPad console are underlined; tapping one
  opens that file and line.

### Projects
- **Import Swift Playgrounds apps (.swiftpm)** with the existing import button,
  as a folder or zipped. Becomes a SwiftUI app project; name, bundle ID and
  version come from Package.swift; images in Assets.xcassets become loose files.
  It warns about Swift package dependencies, `Bundle.module` and asset-catalog
  items that cannot be compiled on the device (colors, app icon).

Files: `CodeEditor.swift`, `FileList.swift`, `FileList+iPad.swift`,
`ContentView.swift`, `NXConsoleView.m`.

### CI (on main)
- Weekly "Check upstream (emexLabs)" workflow; `actions/checkout@v5`.

## 1.2.0 — 2026-11-07

### File list (project editor)
- Selection mode (⋯ > Select) gets a "Select All" button right after Delete.
  It turns into "Deselect All" once every file is selected, and back again.
  Delete, Copy and Share then act on whatever is selected.
- Checkmarks no longer disappear from selected rows while scrolling.
- File: `Nyxian/UI/FileList/FileList.swift`.

## 1.1.0 — 2026-11-07

### Boot
- New "Boot bundled IDE (this fork)" setting, on by default (Recovery > Settings).
  A normal boot now loads the IDE built into this IPA (`SuperSlot.dylib`) instead
  of downloading and booting the official emexLabs ROM from OTA, so the fork's
  changes are what actually runs. Turn it off to use a flashed/official ROM.
- "Restore Defaults" turns it back on.
- File: `Nyxian/UI/BootViewController.swift`.

## 1.0.0 — 2026-11-06

### Editor
- Find & Replace using the system find navigator (UIFindInteraction via Runestone).
  - ⌘F find, ⌥⌘F find and replace, ⌘G next match, ⇧⌘G previous match.
  - Magnifying-glass button in the on-screen editor toolbar for touch use.
- ⌘/ toggles `//` comments on the selected lines (C, ObjC, C++, Swift).
- ⌘] / ⌘[ shift the selected lines right / left.
- ⌘D duplicates the current line or selected lines.
- ⌘L go to line.

### iPad workspace
- ⌘B builds (compile and link) without signing, installing or running.
- ⇧⌘I opens the Issue Navigator.

### Issue Navigator
- Rows that navigate show "Line N, Col M" and a disclosure chevron.
- `path:line:col` references inside linker / internal messages are tappable.
- Fixed a possible crash when tapping the "Contains no messages" placeholder row.

Files: `Nyxian/UI/CodeEditor/CodeEditor.swift`,
`Nyxian/UI/FileList/FileList+iPad.swift`,
`Nyxian/LindChain/IDEBuilder/NXBuilder.swift`,
`Nyxian/LindChain/IDEFoundation/Project+Debug.swift`.
