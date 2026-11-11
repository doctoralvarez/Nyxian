/*
 SPDX-License-Identifier: LicenseRef-EPSL-1.1

 Copyright (C) 2026 Kyle-Ye
 Copyright (C) 2026 emexlab

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
 Fork doctoralvarez/Nyxian — version 1.1.0
 Changelog:
  - 1.1.0 (2026-11-11): "Library" can be chosen (libNAME.dylib); new "Java"
    (miniJVM, .jar) and "Node.js" (JavaScript) templates.
  - 1.0.0 (2026-11-08): "Python" template (a project of Python scripts).
*/

import SwiftUI

struct ProjectTemplateSelectionView: View {
    enum templateRowFlavour {
        case last
        case first
        case generic
    }
    
    @ObservedObject var model: ProjectTemplateOptionsModel
    
    private var textColor: Color { Color(uiColor: LDETheme.currentTheme!.textColor) }
    private var backgroundColor: Color { Color(uiColor: LDETheme.currentTheme!.backgroundColor) }
    private var hairlineColor: Color { Color(uiColor: LDETheme.currentTheme!.gutterHairlineColor) }
    
    var body: some View {
        VStack(spacing: 0) {
            templateRow(title: "App", subtitle: "UI app for iPhone & iPad", systemImage: "appstore.app.fill", schemeKind: .app, scale: .large, flavour: .first)
            templateRow(title: "Command Line Tool", subtitle: "Headless iOS app", systemImage: "terminal.fill", schemeKind: .utility)
            /* fork: a folder of Python scripts, run with ▶ — no app to build */
            templateRow(title: "Python", subtitle: "Python 3 scripts, run with ▶ (main.py to start)", systemImage: "chevron.left.forwardslash.chevron.right", schemeKind: .utility, script: "python")
            /* fork: Java (miniJVM; .jar files) and Node.js (JavaScript) projects */
            templateRow(title: "Java", subtitle: "Java 8 with miniJVM, run with ▶ (Main.java); .jar tools", systemImage: "cup.and.saucer.fill", schemeKind: .utility, script: "java")
            templateRow(title: "Node.js", subtitle: "JavaScript with Node 18, run with ▶ (main.js); npm", systemImage: "curlybraces.square.fill", schemeKind: .utility, script: "node")
            /* fork: a dynamic library (libNAME.dylib) */
            templateRow(title: "Library", subtitle: "Dynamic library (libNAME.dylib) in Swift, ObjC, C or C++", systemImage: "building.columns.fill", schemeKind: .library)
            templateRow(title: "Ksurface Kernel Extension", subtitle: "Extend the ksurface microkernel your self", systemImage: "puzzlepiece.extension.fill", schemeKind: .kSurfaceKext, isEnabled: true, flavour: .last)
        }
        .padding(.top, 2)
        .padding(.horizontal, 18)
        .padding(.bottom, 6)
        .fixedSize(horizontal: false, vertical: true)
    }
    
    private func templateRow(title: String,
                             subtitle: String,
                             systemImage: String,
                             schemeKind: NXProjectSchemeKind,
                             scale: UIImage.SymbolScale = .default,
                             isEnabled: Bool = true,
                             script: String? = nil,
                             flavour: templateRowFlavour = .generic) -> some View {
        let isSelected = script != nil ? model.scriptKind == script : (model.schemeKind == schemeKind && model.scriptKind == nil)
        
        let clipTop: CGFloat = flavour == .first ? 16 : 0
        let clipBottom: CGFloat = flavour == .last ? 16 : 0
        let strokeTop: CGFloat = flavour == .first ? 16 : 4
        let strokeBottom: CGFloat = flavour == .last ? 16 : 4
        
        return Button {
            if let script {
                model.selectScript(script)
            } else {
                model.selectProjectType(schemeKind)
            }
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(isSelected ? textColor : textColor.opacity(0.08))
                    
                    let base = UIImage(systemName: systemImage) ?? UIImage(privateSystemName: systemImage)
                    let configuredBase: UIImage? = base!.applyingSymbolConfiguration(UIImage.SymbolConfiguration(pointSize: 22, weight: .semibold, scale: scale))
                    let img = configuredBase?.withRenderingMode(.alwaysTemplate) ?? UIImage()
                    
                    Image(uiImage: img)
                        .font(.system(size: 22, weight: .semibold))
                        .symbolRenderingMode(.monochrome)
                        .foregroundStyle(isSelected ? backgroundColor : textColor.opacity(0.6))
                }
                .frame(width: 42, height: 42)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(textColor)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(textColor.opacity(0.6))
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(textColor.opacity(0.05))
            .clipShape(
                    UnevenRoundedRectangle(topLeadingRadius: clipTop, bottomLeadingRadius: clipBottom, bottomTrailingRadius: clipBottom, topTrailingRadius: clipTop, style: .continuous)
                )
                .overlay {
                    UnevenRoundedRectangle(topLeadingRadius: strokeTop, bottomLeadingRadius: strokeBottom, bottomTrailingRadius: strokeBottom, topTrailingRadius: strokeTop, style: .continuous)
                    .stroke(isSelected ? textColor : hairlineColor.opacity(0.0), lineWidth: 1.5)
                }
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
