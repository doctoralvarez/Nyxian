//  ProbeApp.swift
//  WidgetProbe - Version 1.0.0 (2026-11-22)
//  Fork doctoralvarez/Nyxian: a minimal app + widget built by Xcode in CI,
//  to compare with the same code built by Nyxian (what an Xcode widget
//  extension has that Nyxian's might lack).
import SwiftUI

@main
struct ProbeApp: App {
    var body: some Scene {
        WindowGroup {
            VStack(spacing: 12) {
                Image(systemName: "square.grid.2x2").font(.largeTitle)
                Text("WidgetProbe").font(.title2.bold())
                Text("Long-press the Home Screen › + › search \"WidgetProbe\".")
                    .multilineTextAlignment(.center).foregroundStyle(.secondary)
            }
            .padding()
        }
    }
}
