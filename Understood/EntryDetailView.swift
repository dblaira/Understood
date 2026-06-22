//
//  EntryDetailView.swift
//  Understood
//
//  Created by Adam Blair on 2/25/26.
//

import SwiftUI
import PhotosUI
import UIKit
import Auth

struct EntryDetailView: View {
    @State var entry: Entry
    let supabase = SupabaseService.shared

    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteConfirm = false
    @State private var isDeleting = false
    @State private var currentImagePage = 0
    @State private var showLinkedCapture = false
    @State private var showEntryEditor = false
    @State private var linkedEntryType: String = "action"
    @State private var starSpinning = false

    var onDeleted: (() -> Void)?
    var onFeaturedChanged: (() -> Void)?

    var body: some View {
        ScrollView {
            detailContent
                .padding(24)
        }
        .background(Color.understoodCream.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbarBackground(Color.sandyBrown, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .tint(.black)
        .toolbar { detailToolbar }
        .alert("Delete Entry", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                Task { await deleteEntry() }
            }
        } message: {
            Text("This will permanently delete this entry and cannot be undone.")
        }
        .sheet(isPresented: $showEntryEditor) {
            EntryEditorView(entry: entry, onSaved: { updatedEntry in
                entry = updatedEntry
                currentImagePage = min(currentImagePage, max(0, updatedEntry.allImages.count - 1))
                onFeaturedChanged?()
            }, onDeleted: {
                onDeleted?()
                dismiss()
            })
        }
    }

    @ToolbarContentBuilder
    private var detailToolbar: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            Button {
                dismiss()
            } label: {
                HeaderIconButton(systemName: "chevron.left")
            }
            .buttonStyle(.plain)
        }

        ToolbarItemGroup(placement: .navigationBarTrailing) {
            Button {
                showEntryEditor = true
            } label: {
                HeaderIconButton(systemName: "pencil")
            }
            .buttonStyle(.plain)

            Button {
                showDeleteConfirm = true
            } label: {
                HeaderIconButton(systemName: "trash")
            }
            .buttonStyle(.plain)
            .disabled(isDeleting)
        }
    }

    @ViewBuilder
    private var detailContent: some View {
        VStack(alignment: .leading, spacing: 24) {

                // MARK: - Image Gallery

                if entry.hasImages {
                    ImageGalleryView(
                        images: entry.allImages,
                        currentPage: $currentImagePage
                    )
                    .padding(.horizontal, -24)
                }

                // MARK: - Action Status (for actions only)

                if entry.isAction {
                    ActionStatusBar(
                        entry: $entry,
                        onToggle: { await toggleComplete() }
                    )
                }

                // MARK: - Hero Section

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        if let label = entry.patternDisplayLabel {
                            Text(label)
                                .font(Typography.sectionHeader)
                                .tracking(1.5)
                                .foregroundStyle(.understoodCrimson)
                        }

                        Spacer()

                        Button {
                            showEntryEditor = true
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: "pencil")
                                    .font(.system(size: 14, weight: .semibold))
                                Text("Edit")
                                    .font(Typography.uiMedium)
                                    .fontWeight(.semibold)
                            }
                            .foregroundStyle(.textSecondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.surfaceSubtle)
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)

                        // Featured star (stories only)
                        if entry.isStory {
                            FeaturedStarButton(
                                isFeatured: entry.featured == true,
                                isSpinning: starSpinning,
                                onTap: { Task { await toggleFeatured() } }
                            )
                        }
                    }

                    Text(entry.displayHeadline)
                        .font(Typography.headline)
                        .foregroundStyle(entry.isCompleted ? .textMuted : .textPrimary)
                        .strikethrough(entry.isCompleted)

                    if let subheading = entry.subheading, !subheading.isEmpty {
                        Text(subheading)
                            .font(Typography.subheading)
                            .foregroundStyle(.textSecondary)
                    }

                    HStack(spacing: 12) {
                        Text(formatDate(entry.createdAt))
                            .font(Typography.date)
                            .foregroundStyle(.textMetadata)

                        if let mood = entry.mood, !mood.isEmpty {
                            Text(mood)
                                .font(Typography.uiMedium)
                                .foregroundStyle(.textSecondary)
                        }

                        if let metadata = entry.metadata {
                            if let energy = metadata.energy {
                                MetadataChip(label: energy)
                            }
                            if let environment = metadata.environment {
                                MetadataChip(label: environment)
                            }
                        }
                    }

                    if entry.isAction {
                        DueDateLabel(entry: entry)
                    }
                }

                Divider()
                    .foregroundStyle(.borderMedium)

                // MARK: - Content Body

                Text(stripHTML(entry.content))
                    .font(Typography.body)
                    .lineSpacing(6)
                    .foregroundStyle(Color.textPrimary.opacity(0.9))

                // MARK: - Context

                if let metadata = entry.metadata {
                    if metadata.activity != nil || metadata.trigger != nil || metadata.location != nil {
                        Divider()
                            .foregroundStyle(.borderMedium)

                        VStack(alignment: .leading, spacing: 12) {
                            Text("CONTEXT")
                                .font(Typography.sectionHeader)
                                .tracking(1.5)
                                .foregroundStyle(.textMuted)

                            HStack(spacing: 8) {
                                if let activity = metadata.activity {
                                    MetadataChip(label: activity)
                                }
                                if let trigger = metadata.trigger {
                                    MetadataChip(label: trigger)
                                }
                                if let location = metadata.location, let city = location.city {
                                    MetadataChip(label: city)
                                }
                            }
                        }
                    }
                }

                // MARK: - Delete

                Divider()
                    .foregroundStyle(.borderMedium)

                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    HStack {
                        Image(systemName: "trash")
                        Text("Delete Entry")
                    }
                    .font(Typography.uiMedium)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.red.opacity(0.1))
                    .foregroundStyle(.red)
                    .cornerRadius(8)
                }
                .disabled(isDeleting)
        }
    }

    // MARK: - Actions

    private func deleteEntry() async {
        isDeleting = true
        do {
            try await supabase.deleteEntry(id: entry.id)
            await MainActor.run {
                onDeleted?()
                dismiss()
            }
        } catch {
            isDeleting = false
            print("Delete error: \(error)")
        }
    }

    private func toggleFeatured() async {
        let wasFeatured = entry.featured == true

        // Optimistic update
        await MainActor.run {
            withAnimation(.easeInOut(duration: 0.3)) {
                entry.featured = !wasFeatured
            }
            if !wasFeatured {
                starSpinning = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    starSpinning = false
                }
            }
        }

        do {
            try await supabase.toggleFeatured(entryId: entry.id, currentlyFeatured: wasFeatured)
            Haptics.medium()
            onFeaturedChanged?()
        } catch {
            // Revert on error
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.3)) {
                    entry.featured = wasFeatured
                }
            }
            Haptics.error()
        }
    }

    private func toggleComplete() async {
        let wasCompleted = entry.isCompleted
        let now = ISO8601DateFormatter().string(from: Date())

        await MainActor.run {
            withAnimation(.easeInOut(duration: 0.3)) {
                entry.completedAt = wasCompleted ? nil : now
            }
        }

        do {
            try await supabase.toggleActionComplete(id: entry.id, currentlyCompleted: wasCompleted)
            Haptics.medium()
        } catch {
            await MainActor.run {
                entry.completedAt = wasCompleted ? entry.completedAt : nil
            }
            Haptics.error()
        }
    }

    // MARK: - Formatting

    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        guard let date = formatter.date(from: dateString) else {
            formatter.formatOptions = [.withInternetDateTime]
            guard let date = formatter.date(from: dateString) else {
                return dateString
            }
            return formatFull(date)
        }
        return formatFull(date)
    }

    private func formatFull(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d, yyyy 'at' h:mm a"
        return formatter.string(from: date)
    }

    /// Strip HTML tags and convert to readable plain text
    private func stripHTML(_ html: String) -> String {
        var text = html
        let blockTags = ["</p>", "</h1>", "</h2>", "</h3>", "</h4>", "</li>", "</blockquote>", "<br>", "<br/>", "<br />"]
        for tag in blockTags {
            text = text.replacingOccurrences(of: tag, with: "\n", options: .caseInsensitive)
        }
        text = text.replacingOccurrences(of: "<li>", with: "\n- ", options: .caseInsensitive)
        while let range = text.range(of: "<[^>]+>", options: .regularExpression) {
            text = text.replacingCharacters(in: range, with: "")
        }
        text = text.replacingOccurrences(of: "&amp;", with: "&")
        text = text.replacingOccurrences(of: "&lt;", with: "<")
        text = text.replacingOccurrences(of: "&gt;", with: ">")
        text = text.replacingOccurrences(of: "&quot;", with: "\"")
        text = text.replacingOccurrences(of: "&#39;", with: "'")
        text = text.replacingOccurrences(of: "&nbsp;", with: " ")
        while text.contains("\n\n\n") {
            text = text.replacingOccurrences(of: "\n\n\n", with: "\n\n")
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Entry Editor

struct EntryEditorView: View {
    let entry: Entry
    let onSaved: (Entry) -> Void
    var onDeleted: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var headline: String
    @State private var subheading: String
    @State private var content: String
    @State private var selectedPatternStep: String?
    @State private var selectedEntryType: String
    @State private var hasDueDate: Bool
    @State private var dueDate: Date
    @State private var isActionCompleted: Bool
    @State private var retainedImages: [EntryImage]
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var selectedImages: [UIImage] = []
    @State private var isLoadingPhotos = false
    @State private var showCamera = false
    @State private var isSaving = false
    @State private var isDeleting = false
    @State private var showDeleteConfirm = false
    @State private var errorMessage: String?

    private let supabase = SupabaseService.shared
    private let entryTypes: [(id: String, label: String)] = [
        ("story", "Story"),
        ("connection", "Connection")
    ]

    init(entry: Entry, onSaved: @escaping (Entry) -> Void, onDeleted: (() -> Void)? = nil) {
        self.entry = entry
        self.onSaved = onSaved
        self.onDeleted = onDeleted
        _headline = State(initialValue: entry.headline)
        _subheading = State(initialValue: entry.subheading ?? "")
        _content = State(initialValue: entry.content)
        _selectedPatternStep = State(initialValue: entry.patternStep)
        _selectedEntryType = State(initialValue: entry.entryType == "connection" ? "connection" : "story")
        _hasDueDate = State(initialValue: entry.parsedDueDate != nil)
        _dueDate = State(initialValue: entry.parsedDueDate ?? Date())
        _isActionCompleted = State(initialValue: entry.isCompleted)
        _retainedImages = State(initialValue: entry.allImages)
    }

    private var cleanedContent: String {
        content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var remainingSlots: Int {
        max(0, availableNewImageSlots - selectedImages.count)
    }

    private var availableNewImageSlots: Int {
        max(0, Entry.maxImagesPerEntry - retainedImages.count)
    }

    private var canSave: Bool {
        !cleanedContent.isEmpty && !isLoadingPhotos && !isSaving && !isDeleting
    }

    private var isEditingAction: Bool {
        selectedEntryType == "action"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                entryEditorFields
                    .padding(24)
            }
            .background(Color.understoodCream.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.sandyBrown, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .tint(.black)
            .toolbar { editorToolbar }
            .sheet(isPresented: $showCamera) { cameraSheet }
            .alert("Delete Entry", isPresented: $showDeleteConfirm) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    Task { await deleteEntry() }
                }
            } message: {
                Text("This will permanently delete this entry and cannot be undone.")
            }
        }
    }

    @ToolbarContentBuilder
    private var editorToolbar: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            Button {
                dismiss()
            } label: {
                HeaderPillButton(title: "Cancel", isEnabled: !isSaving)
            }
            .disabled(isSaving)
            .buttonStyle(.plain)
        }

        ToolbarItem(placement: .principal) {
            Text("Edit Entry")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundStyle(.black)
        }

        ToolbarItem(placement: .navigationBarTrailing) {
            Button {
                Task { await saveEntry() }
            } label: {
                if isSaving {
                    ProgressView()
                        .scaleEffect(0.8)
                        .tint(.white)
                        .frame(width: 56, height: 46)
                        .background(Color.black.opacity(0.9))
                        .clipShape(Capsule())
                } else {
                    HeaderPillButton(title: "Save", isEnabled: canSave)
                }
            }
            .disabled(!canSave)
            .buttonStyle(.plain)
        }
    }

    private var cameraSheet: some View {
        CameraImagePicker { image in
            guard let image, remainingSlots > 0 else { return }
            selectedImages.append(image.uprightOrientation())
            selectedPhotoItems.removeAll()
            errorMessage = nil
        }
        .ignoresSafeArea()
    }

    @ViewBuilder
    private var entryEditorFields: some View {
        VStack(alignment: .leading, spacing: 24) {
            editorTypeSection
            editorTitleSection
            editorSubtitleSection
            editorBodySection
            editorRetainedPhotosSection
            editorAddPhotosSection
            editorPatternSection
            editorDeleteButton
        }
    }

    @ViewBuilder
    private var editorTypeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("TYPE")
                .font(Typography.sectionHeader)
                .tracking(1.5)
                .foregroundStyle(.textMuted)

            HStack(spacing: 8) {
                ForEach(entryTypes, id: \.id) { type in
                    Button {
                        selectedEntryType = type.id
                        Haptics.selection()
                    } label: {
                        Text(type.label)
                            .font(Typography.uiMedium)
                            .foregroundStyle(selectedEntryType == type.id ? .white : .textPrimary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(selectedEntryType == type.id ? Color.black : Color.surfaceSubtle)
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private var editorTitleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("TITLE")
                .font(Typography.sectionHeader)
                .tracking(1.5)
                .foregroundStyle(.textMuted)

            TextField("Optional title", text: $headline, axis: .vertical)
                .font(Typography.editor)
                .foregroundStyle(.textPrimary)
                .padding(12)
                .background(Color.surfaceSubtle)
                .cornerRadius(8)
        }
    }

    @ViewBuilder
    private var editorSubtitleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("SUBTITLE")
                .font(Typography.sectionHeader)
                .tracking(1.5)
                .foregroundStyle(.textMuted)

            TextField("Optional subtitle", text: $subheading, axis: .vertical)
                .font(Typography.body)
                .foregroundStyle(.textPrimary)
                .padding(12)
                .background(Color.surfaceSubtle)
                .cornerRadius(8)
        }
    }

    @ViewBuilder
    private var editorBodySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("BODY")
                .font(Typography.sectionHeader)
                .tracking(1.5)
                .foregroundStyle(.textMuted)

            TextEditor(text: $content)
                .font(Typography.editor)
                .foregroundStyle(.textPrimary)
                .lineSpacing(4)
                .frame(minHeight: 220)
                .padding(8)
                .scrollContentBackground(.hidden)
                .background(Color.surfaceSubtle)
                .cornerRadius(8)
        }
    }

    @ViewBuilder
    private var editorRetainedPhotosSection: some View {
        if !retainedImages.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("CURRENT PHOTOS")
                    .font(Typography.sectionHeader)
                    .tracking(1.5)
                    .foregroundStyle(.textMuted)

                EditablePhotoThumbnailStrip(images: retainedImages) { index in
                    retainedImages.remove(at: index)
                    retainedImages = normalizedImages(retainedImages)
                    currentPhotoSelectionTrimmedToLimit()
                }
            }
        }
    }

    @ViewBuilder
    private var editorAddPhotosSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ADD PHOTOS")
                .font(Typography.sectionHeader)
                .tracking(1.5)
                .foregroundStyle(.textMuted)

            if availableNewImageSlots > 0 {
                HStack(spacing: 10) {
                    PhotosPicker(
                        selection: $selectedPhotoItems,
                        maxSelectionCount: max(1, remainingSlots),
                        matching: .images,
                        photoLibrary: .shared()
                    ) {
                        HStack(spacing: 8) {
                            Image(systemName: "photo.on.rectangle.angled")
                            Text(selectedImages.isEmpty ? "Choose Photos" : "\(selectedImages.count) Selected")
                            Spacer()
                        }
                        .font(Typography.uiMedium)
                        .foregroundStyle(.textPrimary)
                        .padding(14)
                        .background(Color.surfaceSubtle)
                        .cornerRadius(8)
                    }
                    .onChange(of: selectedPhotoItems) { _, items in
                        Task { await loadSelectedPhotos(items) }
                    }
                    .disabled(remainingSlots == 0)

                    Button {
                        Task { await openCamera() }
                    } label: {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.textPrimary)
                            .frame(width: 50, height: 50)
                            .background(Color.surfaceSubtle)
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    .disabled(remainingSlots == 0 || !CameraAccess.isAvailable)
                }

                if !selectedImages.isEmpty {
                    SelectedPhotoStrip(images: selectedImages) { index in
                        selectedImages.remove(at: index)
                        if index < selectedPhotoItems.count {
                            selectedPhotoItems.remove(at: index)
                        }
                    }
                }
            } else {
                Text("This entry already has the maximum of \(Entry.maxImagesPerEntry) photos.")
                    .font(Typography.body)
                    .foregroundStyle(.textSecondary)
            }

            if isLoadingPhotos {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.75)
                    Text("Preparing photos...")
                        .font(Typography.small)
                        .foregroundStyle(.textSecondary)
                }
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(Typography.small)
                    .foregroundStyle(.red)
            }
        }
    }

    @ViewBuilder
    private var editorPatternSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("PATTERN")
                .font(Typography.sectionHeader)
                .tracking(1.5)
                .foregroundStyle(.textMuted)

            Menu {
                Button {
                    selectedPatternStep = nil
                    Haptics.selection()
                } label: {
                    if selectedPatternStep == nil {
                        Label("None", systemImage: "checkmark")
                    } else {
                        Text("None")
                    }
                }

                ForEach(AdamPattern.steps, id: \.self) { step in
                    Button {
                        selectedPatternStep = step
                        Haptics.selection()
                    } label: {
                        if selectedPatternStep == step {
                            Label(step, systemImage: "checkmark")
                        } else {
                            Text(step)
                        }
                    }
                }
            } label: {
                HStack {
                    Image(systemName: "list.number")
                    Text(selectedPatternStep ?? "None")
                        .font(Typography.uiMedium)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(.understoodCrimson)
                .padding(14)
                .background(Color.surfaceSubtle)
                .cornerRadius(8)
            }
        }
    }

    private var editorDeleteButton: some View {
        Button(role: .destructive) {
            showDeleteConfirm = true
        } label: {
            HStack {
                Image(systemName: "trash")
                Text("Delete Entry")
            }
            .font(Typography.uiMedium)
            .fontWeight(.semibold)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.red.opacity(0.1))
            .foregroundStyle(.red)
            .cornerRadius(8)
        }
        .disabled(isSaving || isDeleting)
    }

    private func openCamera() async {
        guard remainingSlots > 0 else { return }

        if let message = await CameraAccess.requestIfNeeded() {
            errorMessage = message
        } else {
            showCamera = true
        }
    }

    private func loadSelectedPhotos(_ items: [PhotosPickerItem]) async {
        await MainActor.run {
            isLoadingPhotos = true
            errorMessage = nil
        }

        var loadedImages: [UIImage] = []
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                loadedImages.append(image)
            }
        }

        await MainActor.run {
            selectedImages = loadedImages.map { $0.uprightOrientation() }
            isLoadingPhotos = false
            if loadedImages.count != items.count {
                errorMessage = "One or more photos could not be prepared. Remove and re-add them before saving."
            }
        }
    }

    private func deleteEntry() async {
        isDeleting = true
        errorMessage = nil

        do {
            try await supabase.deleteEntry(id: entry.id)
            await MainActor.run {
                Haptics.warning()
                onDeleted?()
                dismiss()
            }
        } catch {
            await MainActor.run {
                Haptics.error()
                errorMessage = "Could not delete entry: \(error.localizedDescription)"
                isDeleting = false
            }
        }
    }

    private func saveEntry() async {
        isSaving = true
        errorMessage = nil

        do {
            guard let userId = supabase.currentSession?.user.id.uuidString else {
                throw NSError(domain: "EntryEditorView", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
            }

            let validRetained = retainedImages.filter { Entry.isValidImageURL($0.url) }
            var uploadedImages: [EntryImage] = []

            for (index, image) in selectedImages.enumerated() {
                print("EntryEditorView: uploading image \(index + 1) of \(selectedImages.count) for entry \(entry.id)")
                let url = try await supabase.uploadEntryImage(
                    image: image,
                    userId: userId,
                    entryId: entry.id,
                    index: validRetained.count + index
                )
                print("EntryEditorView: uploaded image \(index + 1) to \(url)")
                uploadedImages.append(EntryImage(
                    url: url,
                    isPoster: false,
                    order: index
                ))
            }

            // New uploads become the poster so edits to older entries refresh the carousel.
            let updatedImages = normalizedImages(uploadedImages + validRetained)
            let updatedAt = ISO8601DateFormatter().string(from: Date())
            let trimmedHeadline = headline.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedSubheading = subheading.trimmingCharacters(in: .whitespacesAndNewlines)
            let dueDateValue = isEditingAction && hasDueDate ? ISO8601DateFormatter().string(from: dueDate) : nil
            let completedAtValue: String? = isEditingAction && isActionCompleted
                ? (entry.completedAt ?? updatedAt)
                : nil

            let payload = EntryUpdatePayload(
                headline: trimmedHeadline,
                subheading: trimmedSubheading,
                content: cleanedContent,
                category: entry.category,
                entryType: selectedEntryType,
                dueDate: dueDateValue,
                completedAt: completedAtValue,
                updatedAt: updatedAt,
                shouldClearDueDate: entry.dueDate != nil || !isEditingAction,
                shouldClearCompletedAt: entry.completedAt != nil || !isEditingAction
            )
            try await supabase.updateEntry(id: entry.id, payload: payload)

            var metadata = entry.metadata ?? EntryMetadata()
            metadata.patternStep = selectedPatternStep
            try await supabase.updateEntryMetadata(id: entry.id, metadata: metadata)
            print("EntryEditorView: updated text fields for entry \(entry.id)")
            try await supabase.updateEntryImages(entryId: entry.id, images: updatedImages)
            print("EntryEditorView: saved \(updatedImages.count) image(s) for entry \(entry.id)")

            var updatedEntry = entry
            updatedEntry.headline = trimmedHeadline
            updatedEntry.subheading = trimmedSubheading
            updatedEntry.content = cleanedContent
            updatedEntry.category = entry.category
            updatedEntry.metadata = metadata
            updatedEntry.entryType = selectedEntryType
            updatedEntry.dueDate = dueDateValue
            updatedEntry.completedAt = completedAtValue
            updatedEntry.images = updatedImages
            updatedEntry.photoUrl = updatedImages.first?.url
            updatedEntry.imageUrl = nil
            updatedEntry.updatedAt = updatedAt

            await MainActor.run {
                Haptics.success()
                onSaved(updatedEntry)
                dismiss()
            }
        } catch {
            print("EntryEditorView save error for entry \(entry.id): \(error)")
            await MainActor.run {
                Haptics.error()
                errorMessage = "Could not save entry: \(error.localizedDescription)"
                isSaving = false
            }
        }
    }

    private func normalizedImages(_ images: [EntryImage]) -> [EntryImage] {
        images.enumerated().map { index, image in
            EntryImage(
                url: image.url,
                isPoster: index == 0,
                order: index,
                focalX: image.focalX,
                focalY: image.focalY
            )
        }
    }

    private func currentPhotoSelectionTrimmedToLimit() {
        let allowedSelectionCount = availableNewImageSlots
        if selectedImages.count > allowedSelectionCount {
            selectedImages = Array(selectedImages.prefix(allowedSelectionCount))
            selectedPhotoItems = Array(selectedPhotoItems.prefix(allowedSelectionCount))
        }
    }
}

struct EditablePhotoThumbnailStrip: View {
    let images: [EntryImage]
    let onRemove: (Int) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(Array(images.enumerated()), id: \.offset) { index, entryImage in
                    ZStack(alignment: .topTrailing) {
                        AsyncImage(url: URL(string: entryImage.url)) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFill()
                            case .failure:
                                Color.surfaceSubtle
                                    .overlay {
                                        Image(systemName: "photo")
                                            .foregroundStyle(.textMuted)
                                    }
                            case .empty:
                                Color.surfaceSubtle
                                    .overlay(ProgressView())
                            @unknown default:
                                Color.surfaceSubtle
                            }
                        }
                        .frame(width: 84, height: 84)
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                        Button {
                            onRemove(index)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .font(.system(size: 19))
                                .foregroundStyle(.white, Color.red)
                        }
                        .offset(x: 5, y: -5)
                    }
                }
            }
        }
    }
}

struct SelectedPhotoStrip: View {
    let images: [UIImage]
    let onRemove: (Int) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(Array(images.enumerated()), id: \.offset) { index, image in
                    ZStack(alignment: .topTrailing) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 84, height: 84)
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                        Button {
                            onRemove(index)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 18))
                                .foregroundStyle(.white, .black.opacity(0.65))
                        }
                        .offset(x: 5, y: -5)
                    }
                }
            }
        }
    }
}

// MARK: - Featured Star Button

struct FeaturedStarButton: View {
    let isFeatured: Bool
    let isSpinning: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Image(systemName: isFeatured ? "star.fill" : "star")
                .font(.system(size: 20))
                .foregroundStyle(isFeatured ? .understoodCrimson : .textMuted)
                .rotationEffect(.degrees(isSpinning ? 360 : 0))
                .animation(
                    isSpinning ? .easeInOut(duration: 0.6) : .default,
                    value: isSpinning
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isFeatured
            ? "This story is featured on your landing page. Tap to remove."
            : "Feature this story on your landing page"
        )
    }
}

// MARK: - Action Status Bar

struct ActionStatusBar: View {
    @Binding var entry: Entry
    let onToggle: () async -> Void

    var body: some View {
        HStack(spacing: 12) {
            ActionCheckbox(
                isCompleted: entry.isCompleted,
                isOverdue: entry.isOverdue
            ) {
                Task { await onToggle() }
            }

            Text(entry.isCompleted ? "Completed" : "Mark Complete")
                .font(Typography.uiMedium)
                .fontWeight(.semibold)
                .foregroundStyle(entry.isCompleted ? .actionGreen : .textSecondary)

            Spacer()

            if entry.isCompleted {
                Button {
                    Task { await onToggle() }
                } label: {
                    Text("Undo")
                        .font(Typography.uiMedium)
                        .foregroundStyle(.textMetadata)
                }
            }
        }
        .padding(12)
        .background(entry.isCompleted ? Color.actionGreen.opacity(0.08) : Color.surfaceSubtle)
        .cornerRadius(8)
    }
}

// MARK: - Water Cycle Buttons

struct WaterCycleButtons: View {
    let entry: Entry
    let onCreateLinked: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("WATER CYCLE")
                .font(Typography.sectionHeader)
                .tracking(1.5)
                .foregroundStyle(.textMuted)

            if entry.isStory {
                waterCycleButton(
                    icon: "bolt.circle.fill",
                    title: "Act on This",
                    subtitle: "Create an action from this story",
                    entryType: "action"
                )
            }

            if entry.isAction && !entry.isCompleted {
                waterCycleButton(
                    icon: "note.text.badge.plus",
                    title: "Collect Notes",
                    subtitle: "Capture notes while working on this",
                    entryType: "note"
                )
            }

            if entry.isAction && entry.isCompleted {
                waterCycleButton(
                    icon: "sparkles",
                    title: "What Changed?",
                    subtitle: "Reflect on what completing this meant",
                    entryType: "story"
                )
            }

            if entry.isNote {
                waterCycleButton(
                    icon: "bolt.circle.fill",
                    title: "Act on This",
                    subtitle: "Turn this note into an action",
                    entryType: "action"
                )
            }
        }
    }

    private func waterCycleButton(icon: String, title: String, subtitle: String, entryType: String) -> some View {
        Button {
            Haptics.light()
            onCreateLinked(entryType)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundStyle(.understoodCrimson)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(Typography.uiMedium)
                        .fontWeight(.semibold)
                        .foregroundStyle(.textPrimary)
                    Text(subtitle)
                        .font(Typography.small)
                        .foregroundStyle(.textMetadata)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.textMuted)
            }
            .padding(12)
            .background(Color.surfaceSubtle)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Literary Version (Cream, Georgia serif, drop cap, decorative separator)

struct LiteraryVersionView: View {
    let title: String
    let bodyText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section label
            Text("PERSONAL ESSAY")
                .font(Typography.chipLabel)
                .tracking(2)
                .foregroundStyle(.voiceLiteraryTitle)
                .frame(maxWidth: .infinity, alignment: .center)

            // Body with drop cap (letter floats left, text wraps below)
            if let firstChar = bodyText.first {
                DropCapText(
                    dropCap: String(firstChar),
                    remainingText: String(bodyText.dropFirst())
                )
            } else {
                Text(bodyText)
                    .font(.custom("Georgia", size: 17))
                    .lineSpacing(8)
                    .foregroundStyle(.voiceLiteraryText)
            }

            // Decorative separator
            Text("❦")
                .font(.system(size: 20))
                .foregroundStyle(.textMuted)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 12)
        }
        .padding(20)
        .background(Color.voiceLiteraryBg)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.04), radius: 2, x: 0, y: 1)
    }
}

// MARK: - Drop Cap (CSS float-left simulation)

/// Renders a large first letter with body text wrapping below it, like Vanity Fair / literary magazines.
/// The drop cap sits in the top-left and the first ~3 lines indent around it, then text continues full-width.
struct DropCapText: View {
    let dropCap: String
    let remainingText: String

    /// Drop cap metrics — sized to span exactly 3 body-text lines
    /// Body line height ≈ 25pt (17pt Georgia + 8pt lineSpacing), so 3 lines ≈ 75pt
    private let capSize: CGFloat = 82
    private let capWidth: CGFloat = 58
    private let capLineHeight: CGFloat = 82

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Drop cap letter — offset up to eat the font's built-in ascender space
            Text(dropCap)
                .font(.custom("Georgia-Bold", size: capSize))
                .foregroundStyle(.voiceLiteraryDropCap)
                .frame(width: capWidth, height: capLineHeight, alignment: .topLeading)
                .clipped()
                .offset(y: -12)

            // Body text with indented first lines wrapping around the cap
            VStack(alignment: .leading, spacing: 0) {
                // Indented portion (wraps beside the drop cap)
                Text(remainingText)
                    .font(.custom("Georgia", size: 17))
                    .lineSpacing(8)
                    .foregroundStyle(.voiceLiteraryText)
                    .padding(.leading, capWidth + 6)
                    .lineLimit(3)

                // Remaining text (full width, below the drop cap)
                let indentedChars = estimateIndentedCharCount()
                if remainingText.count > indentedChars {
                    Text(String(remainingText.dropFirst(indentedChars)))
                        .font(.custom("Georgia", size: 17))
                        .lineSpacing(8)
                        .foregroundStyle(.voiceLiteraryText)
                        .padding(.top, 2)
                }
            }
        }
    }

    /// Estimate how many characters fit in ~3 indented lines beside the wider drop cap
    private func estimateIndentedCharCount() -> Int {
        // Wider cap (58pt + 6pt gap = 64pt indent) leaves ~28 chars per line at 17pt Georgia
        // 3 indented lines × ~28 chars = ~84 chars
        min(remainingText.count, 84)
    }
}

// MARK: - News Version (Gray, bold Playfair headline, double border)

struct NewsVersionView: View {
    let title: String
    let bodyText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section label
            Text("SPECIAL REPORT")
                .font(Typography.chipLabel)
                .tracking(2)
                .foregroundStyle(.voiceNewsTitle)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.bottom, 12)

            // Headline with double border
            VStack(spacing: 0) {
                Rectangle()
                    .fill(Color.black)
                    .frame(height: 2)
                Text(title.uppercased())
                    .font(Typography.sectionTitle)
                    .fontWeight(.black)
                    .multilineTextAlignment(.center)
                    .tracking(-0.3)
                    .foregroundStyle(.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                Rectangle()
                    .fill(Color.black)
                    .frame(height: 0.5)
                    .padding(.bottom, 1)
                Rectangle()
                    .fill(Color.black)
                    .frame(height: 2)
            }
            .padding(.bottom, 16)

            // Body text
            Text(bodyText)
                .font(.custom("Georgia", size: 15))
                .lineSpacing(5)
                .foregroundStyle(.textPrimary)
        }
        .padding(20)
        .background(Color.voiceNewsBg)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.12), radius: 12, x: 0, y: 6)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.borderLight, lineWidth: 1)
        )
    }
}

// MARK: - Poetic Version (Parchment, italic centered Georgia, airy spacing)

struct PoeticVersionView: View {
    let title: String
    let bodyText: String

    var body: some View {
        VStack(spacing: 16) {
            // Section label
            Text("VERSE")
                .font(Typography.chipLabel)
                .tracking(3)
                .foregroundStyle(.voicePoeticTitle)

            // Body — italic, centered, airy
            Text(bodyText)
                .font(.custom("Georgia", size: 17))
                .italic()
                .multilineTextAlignment(.center)
                .lineSpacing(12)
                .tracking(0.3)
                .foregroundStyle(.voicePoeticText)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
        .padding(.vertical, 28)
        .background(Color.voicePoeticBg)
        .cornerRadius(12)
        .shadow(color: Color(red: 0.545, green: 0.271, blue: 0.075).opacity(0.08), radius: 16, x: 0, y: 4)
    }
}

// MARK: - Humorous / Fallback Version (Light green, green left border)

struct HumorousVersionView: View {
    let title: String
    let bodyText: String

    var body: some View {
        HStack(spacing: 0) {
            // Green left border
            Rectangle()
                .fill(Color.voiceHumorousBorder)
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 12) {
                Text(title)
                    .font(Typography.cardHeadline)
                    .foregroundStyle(.voiceHumorousTitle)

                Text(bodyText)
                    .font(Typography.versionBody)
                    .lineSpacing(6)
                    .foregroundStyle(.voiceHumorousText)
            }
            .padding(16)
        }
        .background(Color.voiceHumorousBg)
        .cornerRadius(12)
    }
}

// MARK: - Image Gallery

struct ImageGalleryView: View {
    let images: [EntryImage]
    @Binding var currentPage: Int

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $currentPage) {
                ForEach(Array(images.enumerated()), id: \.offset) { index, entryImage in
                    EntryPosterImage(urlString: entryImage.url)
                        .frame(height: 280)
                        .clipped()
                        .tag(index)
                }
            }
            .frame(height: 280)
            .tabViewStyle(.page(indexDisplayMode: .never))

            // Page indicator (only for multi-image entries)
            if images.count > 1 {
                HStack(spacing: 0) {
                    Spacer()
                    Text("\(currentPage + 1) / \(images.count)")
                        .font(Typography.uiMedium)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.black.opacity(0.6))
                        .cornerRadius(12)
                        .padding(12)
                }
            }
        }
    }
}

// MARK: - Metadata Chip

struct MetadataChip: View {
    let label: String

    var body: some View {
        Text(label)
            .font(Typography.chipLabel)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Color.surfaceChip)
            .cornerRadius(12)
            .foregroundStyle(.textSecondary)
    }
}
