import SwiftUI

struct MemoriesView: View {
    @State private var memories: [MemorySummary] = []
    @State private var error: String?
    @State private var loading = false

    private var byType: [(String, [MemorySummary])] {
        Dictionary(grouping: memories) { $0.type ?? "memory" }
            .sorted { $0.key < $1.key }
    }

    var body: some View {
        NavigationStack {
            Group {
                if let error {
                    ContentUnavailableView("Can't reach the Mac mini",
                                           systemImage: "wifi.exclamationmark",
                                           description: Text(error))
                } else if memories.isEmpty && !loading {
                    ContentUnavailableView("No memories yet", systemImage: "brain",
                                           description: Text("Capture one from the Capture tab."))
                } else {
                    List {
                        ForEach(byType, id: \.0) { type, items in
                            Section(type.capitalized) {
                                ForEach(items) { m in
                                    NavigationLink(value: m) { row(m) }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Memories")
            .navigationDestination(for: MemorySummary.self) { MemoryDetailView(summary: $0) }
            .refreshable { await load() }
            .task { await load() }
        }
    }

    private func row(_ m: MemorySummary) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(m.title).font(.headline)
                Spacer()
                if m.notification_count > 0 {
                    Image(systemName: "bell.fill").font(.caption).foregroundStyle(.orange)
                }
            }
            if !m.description.isEmpty {
                Text(m.description).font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
            }
            if !m.tags.isEmpty {
                Text(m.tags.map { "#\($0)" }.joined(separator: "  "))
                    .font(.caption).foregroundStyle(.tertiary)
            }
        }
    }

    private func load() async {
        loading = true
        defer { loading = false }
        do {
            memories = try await API.shared.memories()
            error = nil
        } catch { self.error = error.localizedDescription }
    }
}

struct MemoryDetailView: View {
    let summary: MemorySummary
    @State private var detail: MemoryDetail?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                chips
                Divider()
                if let detail {
                    Text(markdown(detail.body)).textSelection(.enabled)
                    notificationsSection(detail)
                } else {
                    ProgressView()
                }
            }
            .padding()
        }
        .navigationTitle(summary.title)
        .navigationBarTitleDisplayMode(.inline)
        .task { detail = try? await API.shared.memory(path: summary.path) }
    }

    private var chips: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                chip(summary.type ?? "memory", color: .blue)
                chip(summary.status, color: summary.status == "stable" ? .green : .orange)
                if !summary.generated_at.isEmpty {
                    Text(summary.generated_at.prefix(10))
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            if !summary.tags.isEmpty {
                Text(summary.tags.map { "#\($0)" }.joined(separator: "  "))
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func notificationsSection(_ detail: MemoryDetail) -> some View {
        if let notes = detail.frontmatter["notifications"]?.arrayValue, !notes.isEmpty {
            Divider()
            Label("Reminders", systemImage: "bell").font(.headline)
            ForEach(Array(notes.enumerated()), id: \.offset) { _, n in
                if let o = n.objectValue {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(o["title"]?.stringValue ?? "").font(.subheadline).bold()
                        Text(o["body"]?.stringValue ?? "").font(.subheadline)
                        Text(o["at"]?.stringValue ?? "").font(.caption).foregroundStyle(.secondary)
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }

    private func chip(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption).bold()
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(color.opacity(0.15), in: Capsule())
            .foregroundStyle(color)
    }

    private func markdown(_ body: String) -> AttributedString {
        (try? AttributedString(
            markdown: body,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        )) ?? AttributedString(body)
    }
}
