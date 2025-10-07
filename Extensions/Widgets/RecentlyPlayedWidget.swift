//
//  RecentlyPlayedWidget.swift (stub)
//  Add a Widget Extension target in Xcode and move this file there.
//
/*
import WidgetKit
import SwiftUI

struct RecentlyPlayedEntry: TimelineEntry { let date: Date; let title: String; let artist: String }

struct RecentlyPlayedWidgetEntryView : View {
    var entry: Provider.Entry
    var body: some View {
        VStack(alignment: .leading) {
            Text(entry.title).font(.headline).lineLimit(1)
            Text(entry.artist).font(.caption).foregroundColor(.secondary)
        }.padding()
    }
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> RecentlyPlayedEntry { RecentlyPlayedEntry(date: Date(), title: "Song", artist: "Artist") }
    func getSnapshot(in context: Context, completion: @escaping (RecentlyPlayedEntry) -> ()) { completion(placeholder(in: context)) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<RecentlyPlayedEntry>) -> ()) {
        let entry = RecentlyPlayedEntry(date: Date(), title: "Song", artist: "Artist")
        completion(Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(600))))
    }
}

@main
struct RecentlyPlayedWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "RecentlyPlayedWidget", provider: Provider()) { entry in
            RecentlyPlayedWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Recently Played")
        .description("Quickly access your recent music.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
*/
