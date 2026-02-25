//
//  ContentView.swift
//  Understood
//
//  Created by Adam Blair on 2/24/26.
//

import SwiftUI

struct ContentView: View {
    let supabase = SupabaseService.shared
    @State private var entries: [Entry] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showCapture = false

    var body: some View {
        NavigationStack {
            ZStack {
                // Background color
                Color(red: 0.96, green: 0.94, blue: 0.91)
                    .ignoresSafeArea()

                if isLoading {
                    ProgressView("Loading entries...")
                        .foregroundStyle(.secondary)
                } else if let error = errorMessage {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 40))
                            .foregroundStyle(.secondary)
                        Text(error)
                            .font(.system(size: 15))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        Button("Retry") {
                            Task { await loadEntries() }
                        }
                        .foregroundStyle(.black)
                    }
                    .padding()
                } else if entries.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "book.pages")
                            .font(.system(size: 80))
                            .foregroundStyle(.black.opacity(0.2))
                        Text("No entries yet")
                            .font(.system(size: 34, weight: .light, design: .serif))
                        Text("Your journal entries will appear here")
                            .font(.system(size: 15))
                            .foregroundStyle(.secondary)
                    }
                } else {
                    List {
                        ForEach(entries) { entry in
                            NavigationLink(destination: EntryDetailView(entry: entry)) {
                                EntryRow(entry: entry)
                            }
                            .listRowBackground(Color(red: 0.96, green: 0.94, blue: 0.91))
                            .listRowSeparatorTint(.black.opacity(0.1))
                        }
                    }
                    .listStyle(.plain)
                    .refreshable {
                        await loadEntries()
                    }
                }
            }
            .navigationTitle("Understood")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        Task {
                            try? await supabase.signOut()
                        }
                    } label: {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .foregroundStyle(.black.opacity(0.5))
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showCapture = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(.black)
                    }
                }
            }
            .fullScreenCover(isPresented: $showCapture) {
                CaptureView(onSaved: {
                    Task { await loadEntries() }
                })
            }
        }
        .task {
            await loadEntries()
        }
    }

    private func loadEntries() async {
        isLoading = entries.isEmpty
        errorMessage = nil

        do {
            entries = try await supabase.fetchEntries()
            isLoading = false
        } catch {
            errorMessage = "Could not load entries.\n\(error.localizedDescription)"
            isLoading = false
            print("Fetch error: \(error)")
        }
    }
}

// MARK: - Entry Row

struct EntryRow: View {
    let entry: Entry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Category label
            Text(entry.category.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .tracking(1.5)
                .foregroundStyle(Color(red: 0.86, green: 0.08, blue: 0.24)) // Understood crimson

            // Headline
            Text(entry.headline)
                .font(.system(size: 20, weight: .regular, design: .serif))
                .foregroundStyle(.black)
                .lineLimit(2)

            // Bottom row: date + mood
            HStack {
                Text(formatDate(entry.createdAt))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.black.opacity(0.5))

                if let mood = entry.mood, !mood.isEmpty {
                    Text("  \(mood)")
                        .font(.system(size: 13))
                        .foregroundStyle(.black.opacity(0.55))
                }

                Spacer()
            }
        }
        .padding(.vertical, 8)
    }

    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        guard let date = formatter.date(from: dateString) else {
            // Try without fractional seconds
            formatter.formatOptions = [.withInternetDateTime]
            guard let date = formatter.date(from: dateString) else {
                return dateString
            }
            return formatRelative(date)
        }
        return formatRelative(date)
    }

    private func formatRelative(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            let formatter = DateFormatter()
            formatter.dateFormat = "h:mm a"
            return "Today, \(formatter.string(from: date))"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d, yyyy"
            return formatter.string(from: date)
        }
    }
}

#Preview {
    ContentView()
}
