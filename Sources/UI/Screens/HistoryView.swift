import SwiftUI
import Dependencies

// MARK: - History View

/// Shows conversation history with search and filtering
public struct HistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = HistoryViewModel()

    @State private var searchText = ""
    @State private var showingDeleteConfirmation = false
    @State private var sessionToDelete: ConversationSession?

    public init() {}

    public var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    loadingView
                } else if viewModel.sessions.isEmpty {
                    emptyStateView
                } else {
                    sessionList
                }
            }
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search conversations")
            .onChange(of: searchText) { _, newValue in
                viewModel.search(query: newValue)
            }
            .task {
                await viewModel.loadSessions()
            }
            .alert("Delete Conversation?", isPresented: $showingDeleteConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    if let session = sessionToDelete {
                        Task {
                            await viewModel.deleteSession(session)
                        }
                    }
                }
            } message: {
                Text("This action cannot be undone.")
            }
        }
    }

    // MARK: - Subviews

    private var loadingView: some View {
        VStack {
            ProgressView()
            Text("Loading history...")
                .font(DesignSystem.Typography.caption1)
                .foregroundColor(DesignSystem.Colors.textSecondary)
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            Image(systemName: DesignSystem.Icons.history)
                .font(.system(size: 64))
                .foregroundColor(DesignSystem.Colors.textTertiary)

            Text("No Conversations Yet")
                .font(DesignSystem.Typography.title2)
                .foregroundColor(DesignSystem.Colors.textPrimary)

            Text("Your conversation history will appear here")
                .font(DesignSystem.Typography.body)
                .foregroundColor(DesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    private var sessionList: some View {
        List {
            ForEach(filteredSessions) { session in
                NavigationLink {
                    SessionDetailView(session: session)
                } label: {
                    SessionRow(session: session)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        sessionToDelete = session
                        showingDeleteConfirmation = true
                    } label: {
                        Label("Delete", systemImage: DesignSystem.Icons.trash)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private var filteredSessions: [ConversationSession] {
        if searchText.isEmpty {
            return viewModel.sessions
        }
        return viewModel.searchResults
    }
}

// MARK: - Session Row

public struct SessionRow: View {
    public let session: ConversationSession

    public var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            HStack {
                Text(session.displayTitle)
                    .font(DesignSystem.Typography.headline)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .lineLimit(1)

                Spacer()

                Text(formattedDate)
                    .font(DesignSystem.Typography.caption1)
                    .foregroundColor(DesignSystem.Colors.textTertiary)
            }

            HStack(spacing: DesignSystem.Spacing.sm) {
                LanguageChip(language: session.sourceLanguage, isSource: true)

                Image(systemName: "arrow.right")
                    .font(.caption)
                    .foregroundColor(DesignSystem.Colors.textTertiary)

                LanguageChip(language: session.targetLanguage, isSource: false)
            }

            Text("\(session.transcripts.count) messages")
                .font(DesignSystem.Typography.caption1)
                .foregroundColor(DesignSystem.Colors.textSecondary)
        }
        .padding(.vertical, DesignSystem.Spacing.xs)
    }

    private var formattedDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: session.createdAt, relativeTo: Date())
    }
}

// MARK: - Session Detail View

public struct SessionDetailView: View {
    public let session: ConversationSession

    @State private var showingShareSheet = false
    @State private var showingExportOptions = false

    public var body: some View {
        ScrollView {
            LazyVStack(spacing: DesignSystem.Spacing.md) {
                ForEach(session.transcripts) { item in
                    TranscriptBubble(item: item)
                }
            }
            .padding(.vertical, DesignSystem.Spacing.md)
        }
        .navigationTitle(session.displayTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        showingShareSheet = true
                    } label: {
                        Label("Share", systemImage: DesignSystem.Icons.share)
                    }

                    Button {
                        showingExportOptions = true
                    } label: {
                        Label("Export", systemImage: "square.and.arrow.up.on.square")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingExportOptions) {
            ExportOptionsSheet(session: session)
        }
    }
}

// MARK: - Export Options Sheet

public struct ExportOptionsSheet: View {
    @Environment(\.dismiss) private var dismiss
    public let session: ConversationSession

    public var body: some View {
        NavigationView {
            List {
                Section("Export Format") {
                    ForEach(ExportFormat.allCases, id: \.self) { format in
                        Button {
                            exportSession(format: format)
                        } label: {
                            HStack {
                                Image(systemName: format.icon)
                                    .foregroundColor(DesignSystem.Colors.primaryFallback)

                                VStack(alignment: .leading) {
                                    Text(format.displayName)
                                        .foregroundColor(DesignSystem.Colors.textPrimary)

                                    Text(format.description)
                                        .font(DesignSystem.Typography.caption1)
                                        .foregroundColor(DesignSystem.Colors.textSecondary)
                                }
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Export")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func exportSession(format: ExportFormat) {
        // Export logic would go here
        dismiss()
    }
}

// MARK: - Export Format Extension

extension ExportFormat: CaseIterable {
    public static var allCases: [ExportFormat] = [.plainText, .markdown, .pdf, .json]

    public var displayName: String {
        switch self {
        case .plainText:
            return "Plain Text"
        case .markdown:
            return "Markdown"
        case .pdf:
            return "PDF"
        case .json:
            return "JSON"
        }
    }

    public var description: String {
        switch self {
        case .plainText:
            return "Simple text format"
        case .markdown:
            return "Formatted with headers"
        case .pdf:
            return "Printable document"
        case .json:
            return "Machine-readable"
        }
    }

    public var icon: String {
        switch self {
        case .plainText:
            return "doc.text"
        case .markdown:
            return "doc.richtext"
        case .pdf:
            return "doc.fill"
        case .json:
            return "curlybraces"
        }
    }
}

// MARK: - History View Model

@MainActor
public final class HistoryViewModel: ObservableObject {
    @Published public var sessions: [ConversationSession] = []
    @Published public var searchResults: [ConversationSession] = []
    @Published public var isLoading = false

    @Dependency(\.conversationRepository) private var repository

    public init() {}

    public func loadSessions() async {
        isLoading = true
        defer { isLoading = false }

        do {
            sessions = try await repository.getAll()
        } catch {
            sessions = []
        }
    }

    public func search(query: String) {
        guard !query.isEmpty else {
            searchResults = []
            return
        }

        Task {
            do {
                searchResults = try await repository.search(query: query)
            } catch {
                searchResults = []
            }
        }
    }

    public func deleteSession(_ session: ConversationSession) async {
        do {
            try await repository.delete(id: session.id)
            sessions.removeAll { $0.id == session.id }
        } catch {
            // Handle error
        }
    }
}

// MARK: - Preview

#if DEBUG
struct HistoryView_Previews: PreviewProvider {
    static var previews: some View {
        HistoryView()
    }
}
#endif
