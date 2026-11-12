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
 Fork doctoralvarez/Nyxian — version 1.7.0
 Changelog:
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
            return 14
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
            } else if indexPath.row == 12 {
                /* fork: landscape on iPhone too, or one orientation kept */
                let picker = PickerTableCell(options: ForkOrientation.options, title: "Orientation", key: ForkOrientation.key, defaultValue: 0)
                picker.callback = { _ in ForkOrientation.apply() }
                cell = picker
            } else if indexPath.row == 11 {
                /* fork: font of Python windows */
                cell = StepperTableCell(title: "Python Font Size", key: ForkPython.fontSizeKey, defaultValue: ForkPython.defaultFontSize, minValue: 8, maxValue: 60)
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
