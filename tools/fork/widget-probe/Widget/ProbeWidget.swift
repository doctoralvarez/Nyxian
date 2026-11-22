//  ProbeWidget.swift
//  WidgetProbe Widget - Version 1.0.0 (2026-11-22)
//  Fork doctoralvarez/Nyxian: the smallest static widget (no App Group, no data).
import WidgetKit
import SwiftUI

struct ProbeEntry: TimelineEntry { let date: Date }

struct ProbeProvider: TimelineProvider {
    func placeholder(in context: Context) -> ProbeEntry { ProbeEntry(date: Date()) }
    func getSnapshot(in context: Context, completion: @escaping (ProbeEntry) -> Void) { completion(ProbeEntry(date: Date())) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<ProbeEntry>) -> Void) {
        completion(Timeline(entries: [ProbeEntry(date: Date())], policy: .after(Date().addingTimeInterval(900))))
    }
}

struct ProbeWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "WidgetProbe", provider: ProbeProvider()) { entry in
            VStack {
                Image(systemName: "checkmark.seal.fill").font(.title)
                Text(entry.date, style: .time)
            }
            .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("WidgetProbe")
        .description("A test widget.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct ProbeWidgetBundle: WidgetBundle {
    var body: some Widget { ProbeWidget() }
}
