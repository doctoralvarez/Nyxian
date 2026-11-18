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
 Fork doctoralvarez/Nyxian — version 1.11.0
 Changelog:
  - 1.11.0 (2026-11-18): "This Device" under Live Issues: the model code
    (iPhone19,4 …) with its common name, screen size in inches, the screen
    in points and pixels now, iOS version, RAM and the layout Nyxian uses
    (iPad / iPhone). Tap it to copy. The iPhone Duo Layout row moves one
    down.
  - 1.10.0 (2026-11-18): on iPhone Duo, "iPhone Duo Layout": Automatic (the
    iPad layout when Nyxian starts on the large inner screen), iPad or
    iPhone; it applies the next time Nyxian opens.
  - 1.9.0 (2026-11-17): "Live Issues (check while typing)" toggle: off, the
    editor no longer runs the compiler while you type (errors still show
    when you build).
  - 1.8.0 (2026-11-15): "Appearance": Automatic (follows the device), Light or
    Dark, for Nyxian and the apps it runs.
  - 1.7.0 (2026-11-12): "App Preview (panel at the right, iPad)" toggle.
  - 1.6.0 (2026-11-11): Credentials > Username defaults to "mioftalmologo"
    (the old default "Anonym" is replaced).
  - 1.5.0 (2026-11-09): "SDK Backup" (owner/repo) and "GitHub Token" — where
    the iOS SDK comes from when nyxian.app fails twice.
  - 1.4.1 (2026-11-08): Debugger off by default ("breakpoints; slower builds").
  - 1.4.0 (2026-11-08): "Orientation" picker (Automatic / Portrait /
    Landscape).
  - 1.3.0 (2026-11-08): "Python Font Size" stepper (Python console and
    script windows).
  - 1.2.0 (2026-11-07): "Debugger (pause, breakpoints)" toggle.
  - 1.1.0 (2026-11-07): toggles for "Code Completion" and
    "Shortcut List (hold ⌘)".
  - 1.0.0 (2026-11-07): editor font size defaults to 20 (was 12); the
    stepper now goes up to 32.
*/

import UIKit
import Runestone

class CustomizationViewController: NXUITableViewController {
    var textField: UITextField?
    
    var currentIconName: String {
        UIApplication.shared.alternateIconName ?? "Default"
    }
    
    var icons: [String] = (["Default"] + Bundle.main.alternateIconNames).sorted {
        $0.localizedStandardCompare($1) == .orderedAscending
    }
    
    var themePreviewCell: ThemePickerPreviewCell?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.register(ToggleTableCell.self, forCellReuseIdentifier: ToggleTableCell.reuseIdentifier)
        
        self.title = "Customization"
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0:
            return "Credentials"
        case 1:
            return "Themes"
        case 2:
            return "Icons"
        default:
            return nil
        }
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        switch indexPath.section {
        case 1:
            return (indexPath.row == 0) ? 150 : UITableView.automaticDimension
        case 2:
            if #available(iOS 26.0, *) {
                return 80
            } else {
                return 70
            }
        default:
            return UITableView.automaticDimension
        }
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 3
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0:
            return 4
        case 1:
            /* fork: one more row on iPhone Duo */
            return NXForkIsIPhoneDuo() ? 18 : 17
        case 2:
            return self.icons.count
        default:
            return 2
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: UITableViewCell
        
        if indexPath.section == 0 {
            if indexPath.row == 0 {
                _ = NXUserDefaultUsernameApplied()
                cell = NXTextFieldTableCell(title: "Username", hint: "mioftalmologo", key: "LDEUsername", defaultValue: "mioftalmologo")
            } else if indexPath.row == 1 {
                cell = NXTextFieldTableCell(title: "Hostname", hint: "localhost", key: "LDEHostname", defaultValue: "localhost") { newValue in
                    ksurface_sethostname(newValue)
                }
            } else if indexPath.row == 2 {
                /* fork: where the SDK comes from when nyxian.app fails (a release "ios-sdk") */
                cell = NXTextFieldTableCell(title: "SDK Backup", hint: "owner/repo", key: "fork.sdk.backupRepo", defaultValue: "doctoralvarez/nyxian-sdk")
            } else {
                let tokenCell = NXTextFieldTableCell(title: "GitHub Token", hint: "for a private SDK backup", key: "fork.sdk.githubToken", defaultValue: "")
                tokenCell.textField.isSecureTextEntry = true
                tokenCell.textField.autocorrectionType = .no
                tokenCell.textField.autocapitalizationType = .none
                cell = tokenCell
            }
        } else if indexPath.section == 1 {
            if indexPath.row == 0 {
                themePreviewCell = ThemePickerPreviewCell()
                cell = themePreviewCell!
                (cell as! ThemePickerPreviewCell).populate(with: ThemePickerPreviewCell.ViewModel(theme: LDEThemeReader.shared.currentlySelectedTheme(), text: """
#include <stdio.h>

int main(void)
{
\tprintf(\"Hello, World\\n\");
\treturn 0;
}
"""))
            } else if indexPath.row == 1 {
                var options: [String] = []
                for theme in LDEThemeReader.shared.themes {
                    options.append(theme.name)
                }
                cell = PickerTableCell(options: options, title: "Theme", key: "LDETheme", defaultValue: 0)
                (cell as! PickerTableCell).callback = { selected in
                    self.themePreviewCell!.switchTheme(theme: LDEThemeReader.shared.themes[selected])
                    LDEThemeReader.shared.selectedThemeIndex = selected
                    RevertUI()
                }
            } else if indexPath.row == 2 {
                cell = StepperTableCell(title: "Font Size", key: "LDEFontSize", defaultValue: 20, minValue: 6, maxValue: 32)
                (cell as! StepperTableCell).callback = { newValue in
                    self.themePreviewCell!.switchTheme(theme: LDEThemeReader.shared.currentlySelectedTheme())
                }
            } else if indexPath.row == 3 {
                cell = tableView.dequeueReusableCell(withIdentifier: ToggleTableCell.reuseIdentifier, for: indexPath) as! ToggleTableCell
                (cell as! ToggleTableCell).configure(title: "Show Line Numbers", key: "LDEShowLineNumbers", defaultValue: true) { newValue in
                    self.themePreviewCell!.switchTheme(theme: LDEThemeReader.shared.currentlySelectedTheme())
                }
            } else if indexPath.row == 4 {
                cell = tableView.dequeueReusableCell(withIdentifier: ToggleTableCell.reuseIdentifier, for: indexPath) as! ToggleTableCell
                (cell as! ToggleTableCell).configure(title: "Show Spaces", key: "LDEShowSpaces", defaultValue: true) { newValue in
                    self.themePreviewCell!.switchTheme(theme: LDEThemeReader.shared.currentlySelectedTheme())
                }
            } else if indexPath.row == 5 {
                cell = tableView.dequeueReusableCell(withIdentifier: ToggleTableCell.reuseIdentifier, for: indexPath) as! ToggleTableCell
                (cell as! ToggleTableCell).configure(title: "Wrap Lines", key: "LDEWrapLines", defaultValue: true) { newValue in
                    self.themePreviewCell!.switchTheme(theme: LDEThemeReader.shared.currentlySelectedTheme())
                }
            } else if indexPath.row == 6 {
                cell = tableView.dequeueReusableCell(withIdentifier: ToggleTableCell.reuseIdentifier, for: indexPath) as! ToggleTableCell
                (cell as! ToggleTableCell).configure(title: "Show Line Breaks", key: "LDEShowLineBreaks", defaultValue: true) { newValue in
                    self.themePreviewCell!.switchTheme(theme: LDEThemeReader.shared.currentlySelectedTheme())
                }
            } else if indexPath.row == 7 {
                cell = tableView.dequeueReusableCell(withIdentifier: ToggleTableCell.reuseIdentifier, for: indexPath) as! ToggleTableCell
                (cell as! ToggleTableCell).configure(title: "Autoindent", key: "LDEAutoindent", defaultValue: true)
            } else if indexPath.row == 8 {
                /* fork: suggestions while typing */
                cell = tableView.dequeueReusableCell(withIdentifier: ToggleTableCell.reuseIdentifier, for: indexPath) as! ToggleTableCell
                (cell as! ToggleTableCell).configure(title: "Code Completion", key: "LDECodeCompletion", defaultValue: true)
            } else if indexPath.row == 9 {
                /* fork: hold ⌘ for the shortcut list */
                cell = tableView.dequeueReusableCell(withIdentifier: ToggleTableCell.reuseIdentifier, for: indexPath) as! ToggleTableCell
                (cell as! ToggleTableCell).configure(title: "Shortcut List (hold ⌘)", key: "fork.shortcutHUD", defaultValue: true)
            } else if indexPath.row == 17 {
                /* fork: iPhone Duo's large inner screen */
                let picker = PickerTableCell(options: ["Automatic", "iPad (large screen)", "iPhone"], title: "iPhone Duo Layout", key: "fork.duoLayout", defaultValue: 0)
                picker.callback = { _ in
                    NXAlertDiagnosticPresenter.notifyUser(with: .note, withMessage: "Close and open Nyxian again to use the new layout", withDelay: 0.0)
                }
                cell = picker
            } else if indexPath.row == 16 {
                /* fork: which device Nyxian is running on */
                let info = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
                info.textLabel?.text = "This Device"
                info.detailTextLabel?.text = ForkDeviceInfo.summary(view: tableView)
                info.detailTextLabel?.numberOfLines = 0
                info.detailTextLabel?.font = UIFont.monospacedDigitSystemFont(ofSize: 13, weight: .regular)
                info.detailTextLabel?.textColor = .secondaryLabel
                info.imageView?.image = UIImage(systemName: NXForkIsPadLayout() ? "ipad" : "iphone")
                cell = info
            } else if indexPath.row == 15 {
                /* fork: the compiler checking the code while you type */
                cell = tableView.dequeueReusableCell(withIdentifier: ToggleTableCell.reuseIdentifier, for: indexPath) as! ToggleTableCell
                (cell as! ToggleTableCell).configure(title: "Live Issues (check while typing)", key: "fork.liveIssues", defaultValue: true)
            } else if indexPath.row == 12 {
                /* fork: landscape on iPhone too, or one orientation kept */
                let picker = PickerTableCell(options: ForkOrientation.options, title: "Orientation", key: ForkOrientation.key, defaultValue: 0)
                picker.callback = { _ in ForkOrientation.apply() }
                cell = picker
            } else if indexPath.row == 11 {
                /* fork: font of Python windows */
                cell = StepperTableCell(title: "Python Font Size", key: ForkPython.fontSizeKey, defaultValue: ForkPython.defaultFontSize, minValue: 8, maxValue: 60)
            } else if indexPath.row == 14 {
                /* fork: light / dark mode for Nyxian and the apps it runs */
                let picker = PickerTableCell(options: ForkAppearance.options, title: "Appearance", key: ForkAppearance.key, defaultValue: 0)
                picker.callback = { _ in ForkAppearance.apply() }
                cell = picker
            } else if indexPath.row == 13 {
                /* fork: the running app in a panel at the right of the editor */
                cell = tableView.dequeueReusableCell(withIdentifier: ToggleTableCell.reuseIdentifier, for: indexPath) as! ToggleTableCell
                (cell as! ToggleTableCell).configure(title: "App Preview (panel at the right, iPad)", key: ForkAppPreview.enabledKey, defaultValue: true)
            } else {
                /* fork: attach the debugger to every run */
                cell = tableView.dequeueReusableCell(withIdentifier: ToggleTableCell.reuseIdentifier, for: indexPath) as! ToggleTableCell
                (cell as! ToggleTableCell).configure(title: "Debugger (breakpoints; slower builds)", key: "fork.debugger", defaultValue: false)
            }
        } else {
            cell = UITableViewCell(style: .default, reuseIdentifier: nil)
            let iconName = icons[indexPath.row]
            
            if let image = UIImage(named: "IconPreview\(iconName)") {
                let customImageView = UIImageView(image: image)
                
                if #available(iOS 26.0, *)
                {
                    customImageView.layer.cornerRadius = 15;
                } else {
                    customImageView.layer.cornerRadius = 10;
                }
                
                customImageView.layer.masksToBounds = true
                customImageView.translatesAutoresizingMaskIntoConstraints = false
                customImageView.contentMode = .scaleAspectFit
                cell.contentView.addSubview(customImageView)
                
                NSLayoutConstraint.activate([
                    customImageView.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor, constant: 16),
                    customImageView.centerYAnchor.constraint(equalTo: cell.contentView.centerYAnchor),
                    customImageView.widthAnchor.constraint(equalToConstant: 50),
                    customImageView.heightAnchor.constraint(equalToConstant: 50)
                ])
            }

            cell.textLabel?.text = iconName
            cell.textLabel?.font = UIFont.systemFont(ofSize: 14, weight: .bold)
            cell.textLabel?.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                cell.textLabel!.centerYAnchor.constraint(equalTo: cell.contentView.centerYAnchor),
                cell.textLabel!.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor, constant: 80)
            ])
            
            if iconName == currentIconName {
                cell.accessoryType = .checkmark
            } else {
                cell.accessoryType = .none
            }
        }

        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        /* fork: This Device: copy what it shows */
        if indexPath.section == 1 && indexPath.row == 16 {
            UIPasteboard.general.string = ForkDeviceInfo.summary(view: tableView)
            NXAlertDiagnosticPresenter.notifyUser(with: .note, withMessage: "Device info copied", withDelay: 0.0)
            return
        }
        guard indexPath.section == 2 else { return }

        let iconName = icons[indexPath.row]
        
        if iconName == "Default" {
            UIApplication.shared.setAlternateIconName(nil)
        } else {
            UIApplication.shared.setAlternateIconName(iconName)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            tableView.reloadSections(IndexSet(integer: 2), with: .automatic)
        }
    }

}

// MARK: - fork: appearance

/// Customization › Appearance: Automatic follows the device's light / dark
/// mode; Light or Dark keep one. Nyxian's own windows and the apps it runs
/// (their scenes get the style) both follow it.
enum ForkAppearance {
    static let key = "fork.appearance"
    static let options: [String] = ["Automatic", "Light", "Dark"]

    static func apply() {
        let style: UIUserInterfaceStyle
        switch UserDefaults.standard.integer(forKey: key) {
        case 1: style = .light
        case 2: style = .dark
        default: style = .unspecified
        }
        for scene in UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }) {
            for window in scene.windows {
                window.overrideUserInterfaceStyle = style
            }
        }
        NXWindowServer.shared()?.forkApplyAppearance()
    }
}

// MARK: - fork: This Device

/// The device Nyxian runs on: model code (hw.machine), common name, screen size
enum ForkDeviceInfo {
    /// model code → (name, screen)
    static let models: [String: (String, String)] = [
        /* iPhone */
        "iPhone12,1": ("iPhone 11", "6.1\""),
        "iPhone12,3": ("iPhone 11 Pro", "5.8\""),
        "iPhone12,5": ("iPhone 11 Pro Max", "6.5\""),
        "iPhone12,8": ("iPhone SE (2nd generation)", "4.7\""),
        "iPhone13,1": ("iPhone 12 mini", "5.4\""),
        "iPhone13,2": ("iPhone 12", "6.1\""),
        "iPhone13,3": ("iPhone 12 Pro", "6.1\""),
        "iPhone13,4": ("iPhone 12 Pro Max", "6.7\""),
        "iPhone14,2": ("iPhone 13 Pro", "6.1\""),
        "iPhone14,3": ("iPhone 13 Pro Max", "6.7\""),
        "iPhone14,4": ("iPhone 13 mini", "5.4\""),
        "iPhone14,5": ("iPhone 13", "6.1\""),
        "iPhone14,6": ("iPhone SE (3rd generation)", "4.7\""),
        "iPhone14,7": ("iPhone 14", "6.1\""),
        "iPhone14,8": ("iPhone 14 Plus", "6.7\""),
        "iPhone15,2": ("iPhone 14 Pro", "6.1\""),
        "iPhone15,3": ("iPhone 14 Pro Max", "6.7\""),
        "iPhone15,4": ("iPhone 15", "6.1\""),
        "iPhone15,5": ("iPhone 15 Plus", "6.7\""),
        "iPhone16,1": ("iPhone 15 Pro", "6.1\""),
        "iPhone16,2": ("iPhone 15 Pro Max", "6.7\""),
        "iPhone17,1": ("iPhone 16 Pro", "6.3\""),
        "iPhone17,2": ("iPhone 16 Pro Max", "6.9\""),
        "iPhone17,3": ("iPhone 16", "6.1\""),
        "iPhone17,4": ("iPhone 16 Plus", "6.7\""),
        "iPhone17,5": ("iPhone 16e", "6.1\""),
        "iPhone18,1": ("iPhone 17 Pro", "6.3\""),
        "iPhone18,2": ("iPhone 17 Pro Max", "6.9\""),
        "iPhone18,3": ("iPhone 17", "6.3\""),
        "iPhone18,4": ("iPhone Air", "6.5\""),
        "iPhone18,5": ("iPhone 17e", "6.1\""),
        "iPhone19,2": ("iPhone 18 Pro", "6.3\""),
        "iPhone19,3": ("iPhone 18 Pro Max", "6.9\""),
        "iPhone19,7": ("iPhone 18 Pro Max", "6.9\""),
        "iPhone19,4": ("iPhone Duo", "7.6\" inner, 5.4\" outer"),
        /* iPad */
        "iPad12,1": ("iPad (9th generation)", "10.2\""),
        "iPad12,2": ("iPad (9th generation)", "10.2\""),
        "iPad13,1": ("iPad Air (4th generation)", "10.9\""),
        "iPad13,2": ("iPad Air (4th generation)", "10.9\""),
        "iPad13,4": ("iPad Pro 11\" (3rd generation, M1)", "11\""),
        "iPad13,5": ("iPad Pro 11\" (3rd generation, M1)", "11\""),
        "iPad13,6": ("iPad Pro 11\" (3rd generation, M1)", "11\""),
        "iPad13,7": ("iPad Pro 11\" (3rd generation, M1)", "11\""),
        "iPad13,8": ("iPad Pro 12.9\" (5th generation, M1)", "12.9\""),
        "iPad13,9": ("iPad Pro 12.9\" (5th generation, M1)", "12.9\""),
        "iPad13,10": ("iPad Pro 12.9\" (5th generation, M1)", "12.9\""),
        "iPad13,11": ("iPad Pro 12.9\" (5th generation, M1)", "12.9\""),
        "iPad13,16": ("iPad Air (5th generation, M1)", "10.9\""),
        "iPad13,17": ("iPad Air (5th generation, M1)", "10.9\""),
        "iPad13,18": ("iPad (10th generation)", "10.9\""),
        "iPad13,19": ("iPad (10th generation)", "10.9\""),
        "iPad14,1": ("iPad mini (6th generation)", "8.3\""),
        "iPad14,2": ("iPad mini (6th generation)", "8.3\""),
        "iPad14,3": ("iPad Pro 11\" (4th generation, M2)", "11\""),
        "iPad14,4": ("iPad Pro 11\" (4th generation, M2)", "11\""),
        "iPad14,5": ("iPad Pro 12.9\" (6th generation, M2)", "12.9\""),
        "iPad14,6": ("iPad Pro 12.9\" (6th generation, M2)", "12.9\""),
        "iPad14,8": ("iPad Air 11\" (M2)", "11\""),
        "iPad14,9": ("iPad Air 11\" (M2)", "11\""),
        "iPad14,10": ("iPad Air 13\" (M2)", "13\""),
        "iPad14,11": ("iPad Air 13\" (M2)", "13\""),
        "iPad15,3": ("iPad Air 11\" (M3)", "11\""),
        "iPad15,4": ("iPad Air 11\" (M3)", "11\""),
        "iPad15,5": ("iPad Air 13\" (M3)", "13\""),
        "iPad15,6": ("iPad Air 13\" (M3)", "13\""),
        "iPad15,7": ("iPad (A16)", "11\""),
        "iPad15,8": ("iPad (A16)", "11\""),
        "iPad16,1": ("iPad mini (A17 Pro)", "8.3\""),
        "iPad16,2": ("iPad mini (A17 Pro)", "8.3\""),
        "iPad16,3": ("iPad Pro 11\" (M4)", "11\""),
        "iPad16,4": ("iPad Pro 11\" (M4)", "11\""),
        "iPad16,5": ("iPad Pro 13\" (M4)", "13\""),
        "iPad16,6": ("iPad Pro 13\" (M4)", "13\""),
        "iPad16,8": ("iPad Air 11\" (M4)", "11\""),
        "iPad16,9": ("iPad Air 11\" (M4)", "11\""),
        "iPad16,10": ("iPad Air 13\" (M4)", "13\""),
        "iPad16,11": ("iPad Air 13\" (M4)", "13\""),
        "iPad17,1": ("iPad Pro 11\" (M5)", "11\""),
        "iPad17,2": ("iPad Pro 11\" (M5)", "11\""),
        "iPad17,3": ("iPad Pro 13\" (M5)", "13\""),
        "iPad17,4": ("iPad Pro 13\" (M5)", "13\""),
        "iPad19,1": ("iPad mini (A20 Pro)", "8.5\""),
        "iPad19,2": ("iPad mini (A20 Pro)", "8.5\"")
    ]

    /// hw.machine: "iPhone19,4", "iPad16,5", …
    static var modelCode: String {
        var system = utsname()
        uname(&system)
        let code = withUnsafePointer(to: &system.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: MemoryLayout.size(ofValue: system.machine)) {
                String(cString: $0)
            }
        }
        /* the simulator says arm64; the device it plays is in the environment */
        if let simulated = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] { return simulated }
        return code
    }

    static func summary(view: UIView?) -> String {
        let code = modelCode
        let known = models[code]
        let name = known?.0 ?? "Unknown model (newer than Nyxian's list)"
        var lines: [String] = []
        lines.append("\(name) · \(code)")
        if let screen = known?.1 { lines.append("Screen: \(screen)") }

        let windowScene = view?.window?.windowScene
        let bounds = windowScene?.coordinateSpace.bounds ?? view?.window?.bounds ?? .zero
        let scale = view?.window?.traitCollection.displayScale ?? view?.traitCollection.displayScale ?? 0
        if bounds.width > 0 && scale > 0 {
            let points = "\(Int(bounds.width)) × \(Int(bounds.height)) pt"
            let pixels = "\(Int(bounds.width * scale)) × \(Int(bounds.height * scale)) px @\(Int(scale))x"
            lines.append("Now: \(points) · \(pixels)")
        }

        let device = UIDevice.current
        let ram = ByteCountFormatter.string(fromByteCount: Int64(ProcessInfo.processInfo.physicalMemory), countStyle: .memory)
        lines.append("\(device.systemName) \(device.systemVersion) · RAM \(ram)")

        var layout = NXForkIsPadLayout() ? "iPad layout" : "iPhone layout"
        if NXForkIsIPhoneDuo() {
            layout += NXForkDuoInnerDisplayNow() ? " · inner screen in use" : " · outer screen in use"
        }
        lines.append(layout)
        return lines.joined(separator: "\n")
    }
}

