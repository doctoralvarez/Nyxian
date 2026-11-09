/*
 Copyright (C) 2026 doctoralvarez

 This file is part of the doctoralvarez/Nyxian fork.
 See LICENSE for the full license terms.
*/

/*
 Fork doctoralvarez/Nyxian — version 1.0.0
 Changelog:
  - 1.0.0 (2026-11-08): Format Document for Swift beyond re-indentation —
    keeps the file's indentation (spaces or tabs), SwiftUI modifier chains
    one level in, `case` aligned with `switch`, trailing spaces removed, at
    most one blank line in a row (none right inside braces), spaces in
    `if(` / `){` / `}else` / `else{` and after commas; strings, comments and
    multi-line strings are left alone. Python: trailing spaces and blank
    lines only (its indentation is code). Pure Swift (Foundation), tested by
    CI (tools/fork/formatter_test).
*/

import Foundation

enum ForkSwiftFormatter {
    /// The indentation the file already uses: a tab, or 2/4 spaces.
    static func indentUnit(of text: String) -> String {
        var tabs = 0, two = 0, four = 0
        for line in text.split(separator: "\n", omittingEmptySubsequences: true) {
            if line.hasPrefix("\t") { tabs += 1 }
            else if line.hasPrefix("    ") { four += 1 }
            else if line.hasPrefix("  ") && !line.hasPrefix("   ") { two += 1 }
        }
        if tabs > four + two { return "\t" }
        if two > four { return "  " }
        return "    "
    }

    // MARK: Swift

    static func formatSwift(_ text: String, indent unit: String? = nil) -> String {
        let unit = unit ?? indentUnit(of: text)
        let lines = text.components(separatedBy: "\n")
        var output: [String] = []
        var depth = 0
        var inBlockComment = false
        var inMultilineString = false
        /* the braces that opened a switch */
        var braceIsSwitch: [Bool] = []
        var previousCode = ""        // last non-blank line written (trimmed)
        var previousIndent = 0       // its indentation level

        for rawLine in lines {
            /* multi-line string literals keep their exact text */
            if inMultilineString {
                output.append(rawLine)
                if rawLine.contains("\"\"\"") { inMultilineString = false }
                continue
            }
            var trimmed = rawLine.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty {
                output.append("")
                continue
            }
            if !inBlockComment {
                trimmed = normalizeSpacing(trimmed)
            }

            var level = depth
            if !inBlockComment {
                var leadingClosers = 0
                for character in trimmed {
                    if character == "}" || character == ")" || character == "]" { leadingClosers += 1 } else { break }
                }
                level = max(depth - leadingClosers, 0)
                let insideSwitch = braceIsSwitch.last == true && leadingClosers == 0
                if insideSwitch && (trimmed.hasPrefix("case ") || trimmed.hasPrefix("default:") || trimmed.hasPrefix("@unknown default")) {
                    level = max(level - 1, 0)
                }
                /* SwiftUI modifiers: one level in from the view they follow, the same as the modifier before */
                if trimmed.hasPrefix(".") && !trimmed.hasPrefix("...") && !trimmed.hasPrefix("..<") {
                    if previousCode.hasPrefix(".") && !previousCode.hasSuffix("{") && !previousCode.hasSuffix("(") {
                        level = previousIndent
                    } else if previousCode.hasPrefix("}") || previousCode.hasPrefix(")") || previousCode.hasPrefix("]") {
                        level = depth
                    } else if !previousCode.hasSuffix("{") && !previousCode.hasSuffix("(") && !previousCode.hasSuffix(",") && !previousCode.isEmpty {
                        level = depth + 1
                    }
                }
            }

            let commentPad = (inBlockComment && trimmed.hasPrefix("*")) ? " " : ""
            output.append(String(repeating: unit, count: level) + commentPad + trimmed)

            let scanned = scan(trimmed, depth: depth, inBlockComment: inBlockComment, braceIsSwitch: braceIsSwitch)
            depth = scanned.depth
            inBlockComment = scanned.inBlockComment
            inMultilineString = scanned.opensMultilineString
            braceIsSwitch = scanned.braceIsSwitch
            if !inBlockComment && !trimmed.hasPrefix("//") {
                previousCode = trimmed
                previousIndent = level
            }
        }
        return tidyBlankLines(output, braces: true)
    }

    /// Spaces in `if(`, `){`, `}else`, `else{` and after commas — outside strings and comments.
    static func normalizeSpacing(_ line: String) -> String {
        let characters = Array(line)
        var result = ""
        var code = ""   // the current run of code (outside strings and comments)
        var index = 0

        func flush() {
            result += fixCode(code)
            code = ""
        }
        while index < characters.count {
            let character = characters[index]
            let next: Character? = index + 1 < characters.count ? characters[index + 1] : nil
            if character == "/" && (next == "/" || next == "*") {
                flush()
                result += String(characters[index...])
                return result
            }
            if character == "\"" {
                flush()
                /* a string: copied as it is, escapes and interpolations included */
                var end = index + 1
                var nesting = 0
                while end < characters.count {
                    if characters[end] == "\\" {
                        if end + 1 < characters.count && characters[end + 1] == "(" { nesting += 1; end += 2; continue }
                        end += 2
                        continue
                    }
                    if nesting > 0 {
                        if characters[end] == "(" { nesting += 1 }
                        if characters[end] == ")" { nesting -= 1 }
                        end += 1
                        continue
                    }
                    if characters[end] == "\"" { break }
                    end += 1
                }
                let last = min(end, characters.count - 1)
                result += String(characters[index...last])
                index = last + 1
                continue
            }
            code.append(character)
            index += 1
        }
        flush()
        return result
    }

    private static func fixCode(_ code: String) -> String {
        guard !code.isEmpty else { return code }
        var text = code
        for keyword in ["if", "for", "while", "switch", "guard", "catch", "return"] {
            text = text.replacingOccurrences(of: "(?<![A-Za-z0-9_.])\(keyword)\\(", with: "\(keyword) (", options: .regularExpression)
        }
        text = text.replacingOccurrences(of: "\\)\\{", with: ") {", options: .regularExpression)
        text = text.replacingOccurrences(of: "\\}else", with: "} else", options: .regularExpression)
        text = text.replacingOccurrences(of: "(?<![A-Za-z0-9_])else\\{", with: "else {", options: .regularExpression)
        /* "a,b" -> "a, b" (not ",)" or ",]" or at the end) */
        text = text.replacingOccurrences(of: ",(?=[^\\s\\)\\]])", with: ", ", options: .regularExpression)
        return text
    }

    /// Follows brackets outside strings and comments; remembers which `{` belong to a switch.
    private static func scan(_ line: String, depth startDepth: Int, inBlockComment startInComment: Bool, braceIsSwitch startSwitches: [Bool])
        -> (depth: Int, inBlockComment: Bool, opensMultilineString: Bool, braceIsSwitch: [Bool]) {
        let characters = Array(line)
        var depth = startDepth
        var inBlockComment = startInComment
        var inString = false
        var switches = startSwitches
        let isSwitchLine = line.range(of: "(^|[^A-Za-z0-9_])switch\\s", options: .regularExpression) != nil
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
                if index + 2 < characters.count && characters[index + 1] == "\"" && characters[index + 2] == "\"" {
                    let rest = String(characters[(index + 3)...])
                    guard let range = rest.range(of: "\"\"\"") else {
                        return (max(depth, 0), inBlockComment, true, switches)
                    }
                    index += 3 + rest.distance(from: rest.startIndex, to: range.upperBound)
                    continue
                }
                inString = true
                index += 1
                continue
            }
            switch character {
            case "{":
                depth += 1
                switches.append(isSwitchLine)
            case "(", "[":
                depth += 1
                switches.append(false)
            case "}", ")", "]":
                depth = max(depth - 1, 0)
                if !switches.isEmpty { switches.removeLast() }
            default:
                break
            }
            index += 1
        }
        return (depth, inBlockComment, false, switches)
    }

    /// At most one blank line in a row; with `braces`, none right after `{` or right before `}`; one newline at the end.
    private static func tidyBlankLines(_ lines: [String], braces: Bool) -> String {
        var result: [String] = []
        for line in lines {
            let trimmedEnd = line.replacingOccurrences(of: "[ \\t]+$", with: "", options: .regularExpression)
            if trimmedEnd.isEmpty {
                guard let last = result.last, !last.isEmpty else { continue }
                if braces && last.trimmingCharacters(in: .whitespaces).hasSuffix("{") { continue }
                result.append("")
                continue
            }
            if braces, trimmedEnd.trimmingCharacters(in: .whitespaces).hasPrefix("}"), result.last == "" {
                result.removeLast()
            }
            result.append(trimmedEnd)
        }
        while result.last == "" { result.removeLast() }
        return result.joined(separator: "\n") + "\n"
    }

    // MARK: Python

    /// Python's indentation is code: only trailing spaces, tabs in indentation (to 4 spaces) and blank-line runs (max 2).
    static func formatPython(_ text: String) -> String {
        var result: [String] = []
        var blanks = 0
        for raw in text.components(separatedBy: "\n") {
            var line = raw.replacingOccurrences(of: "[ \\t]+$", with: "", options: .regularExpression)
            let body = line.drop { $0 == " " || $0 == "\t" }
            let leading = line.prefix(line.count - body.count)
            if leading.contains("\t") {
                line = leading.replacingOccurrences(of: "\t", with: "    ") + body
            }
            if line.isEmpty {
                blanks += 1
                if blanks > 2 || result.isEmpty { continue }
            } else {
                blanks = 0
            }
            result.append(line)
        }
        while result.last == "" { result.removeLast() }
        return result.joined(separator: "\n") + "\n"
    }
}
