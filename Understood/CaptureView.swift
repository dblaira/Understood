//
//  CaptureView.swift
//  Understood
//
//  Created by Adam Blair on 2/25/26.
//

import SwiftUI
import PhotosUI
import Auth

struct CaptureView: View {
    @Environment(\.dismiss) private var dismiss
    let supabase = SupabaseService.shared

    // Form state
    @State private var content = ""
    @State private var selectedCategory = "Business"
    @FocusState private var isContentFocused: Bool

    // Photo state
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var selectedImages: [UIImage] = []

    // Save state
    @State private var isSaving = false
    @State private var savedEntry: Entry?
    @State private var inferenceResult: InferEntryResponse?
    @State private var showPostCapture = false
    @State private var errorMessage: String?

    let categories = ["Business", "Finance", "Health", "Spiritual", "Fun", "Social", "Romance"]

    /// Callback when entry is saved (so feed can refresh)
    var onSaved: (() -> Void)?

    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color.understoodCream
                    .ignoresSafeArea()

                VStack(spacing: 0) {

                    // MARK: - Category Selector

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(categories, id: \.self) { category in
                                Button {
                                    selectedCategory = category
                                    Haptics.selection()
                                } label: {
                                    Text(category)
                                        .font(Typography.uiMedium)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(selectedCategory == category ? Color.black : Color.surfaceSubtle)
                                        .foregroundStyle(selectedCategory == category ? Color.white : Color.textPrimary)
                                        .cornerRadius(20)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                    }

                    Divider()
                        .foregroundStyle(.borderLight)

                    // MARK: - Photo Attachment Bar

                    HStack(spacing: 12) {
                        PhotosPicker(
                            selection: $selectedPhotoItems,
                            maxSelectionCount: Entry.maxImagesPerEntry,
                            matching: .images,
                            photoLibrary: .shared()
                        ) {
                            HStack(spacing: 5) {
                                Image(systemName: "photo.on.rectangle.angled")
                                    .font(.system(size: 14))
                                if selectedImages.isEmpty {
                                    Text("Add Photos")
                                        .font(Typography.uiMedium)
                                } else {
                                    Text("\(selectedImages.count)/\(Entry.maxImagesPerEntry)")
                                        .font(Typography.uiMedium)
                                }
                            }
                            .foregroundStyle(.textSecondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.surfaceSubtle)
                            .cornerRadius(16)
                        }
                        .onChange(of: selectedPhotoItems) { _, items in
                            Task { await loadSelectedPhotos(items) }
                        }

                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)

                    // MARK: - Selected Image Previews

                    if !selectedImages.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(Array(selectedImages.enumerated()), id: \.offset) { index, image in
                                    ZStack(alignment: .topTrailing) {
                                        Image(uiImage: image)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 72, height: 72)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))

                                        // Remove button
                                        Button {
                                            withAnimation(.easeInOut(duration: 0.2)) {
                                                selectedImages.remove(at: index)
                                                if index < selectedPhotoItems.count {
                                                    selectedPhotoItems.remove(at: index)
                                                }
                                            }
                                            Haptics.light()
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .font(.system(size: 18))
                                                .foregroundStyle(.white, .black.opacity(0.6))
                                        }
                                        .offset(x: 4, y: -4)
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                        .padding(.bottom, 8)
                    }

                    // MARK: - Content Area

                    TextEditor(text: $content)
                        .font(Typography.editor)
                        .foregroundStyle(.textPrimary)
                        .lineSpacing(4)
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .focused($isContentFocused)
                        .scrollContentBackground(.hidden)
                        .background(Color.clear)
                        .overlay(alignment: .topLeading) {
                            if content.isEmpty {
                                Text("What happened? What are you thinking about?")
                                    .font(Typography.editor)
                                    .foregroundStyle(Color.textPrimary.opacity(0.25))
                                    .padding(.horizontal, 21)
                                    .padding(.top, 20)
                                    .allowsHitTesting(false)
                            }
                        }

                    // MARK: - Error Message

                    if let error = errorMessage {
                        Text(error)
                            .font(Typography.small)
                            .foregroundStyle(.red)
                            .padding(.horizontal, 20)
                            .padding(.bottom, 8)
                    }
                }
            }
            .navigationTitle("Capture")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.understoodCream, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(.textPrimary)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task { await saveEntry() }
                    } label: {
                        if isSaving {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .scaleEffect(0.8)
                        } else {
                            Text("Save")
                                .fontWeight(.bold)
                        }
                    }
                    .disabled(content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
                    .foregroundStyle(content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .gray : .textPrimary)
                }
            }
            .onAppear {
                isContentFocused = true
            }
            .sheet(isPresented: $showPostCapture) {
                PostCaptureSheet(
                    inferenceResult: inferenceResult,
                    onDismiss: {
                        showPostCapture = false
                        dismiss()
                    }
                )
                .presentationDetents([.fraction(0.35)])
                .presentationDragIndicator(.visible)
            }
        }
    }

    // MARK: - Photo Loading

    private func loadSelectedPhotos(_ items: [PhotosPickerItem]) async {
        var newImages: [UIImage] = []
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                newImages.append(image)
            }
        }
        await MainActor.run {
            selectedImages = newImages
        }
    }

    // MARK: - Save Logic

    private func saveEntry() async {
        isSaving = true
        errorMessage = nil

        // Build metadata with auto-captured context
        let now = Date()
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: now)
        let timeOfDay: String
        switch hour {
        case 5..<12: timeOfDay = "morning"
        case 12..<17: timeOfDay = "afternoon"
        case 17..<21: timeOfDay = "evening"
        default: timeOfDay = "night"
        }

        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "EEEE"
        let dayOfWeek = dayFormatter.string(from: now)

        let metadata = EntryMetadata(
            timestamp: ISO8601DateFormatter().string(from: now),
            dayOfWeek: dayOfWeek,
            timeOfDay: timeOfDay,
            device: "mobile"
        )

        do {
            // 1. Save to Supabase (text only, get entry ID)
            let entry = try await supabase.createEntry(
                content: content,
                category: selectedCategory,
                metadata: metadata
            )
            savedEntry = entry
            Haptics.success()

            // 2. Upload images in background (parallel with inference)
            let imagesToUpload = selectedImages
            if !imagesToUpload.isEmpty {
                Task {
                    await uploadImages(entryId: entry.id, images: imagesToUpload)
                    onSaved?() // Refresh feed after images uploaded
                }
            }

            // 3. Trigger AI inference in parallel
            async let inferTask: () = runInference(entryId: entry.id, content: content)
            async let enrichTask: () = runEnrichment(entryId: entry.id, content: content, timeOfDay: timeOfDay, dayOfWeek: dayOfWeek)

            // Wait for inference and enrichment
            _ = try? await (inferTask, enrichTask)

            // 4. Trigger version generation in background
            Task {
                await runVersionGeneration(entry: entry)
                onSaved?()
            }

            // 5. Notify feed to refresh
            onSaved?()

            // 6. Show post-capture sheet or dismiss
            await MainActor.run {
                isSaving = false
                if inferenceResult != nil {
                    showPostCapture = true
                } else {
                    dismiss()
                }
            }

        } catch {
            await MainActor.run {
                errorMessage = "Failed to save: \(error.localizedDescription)"
                isSaving = false
            }
            print("Save error: \(error)")
        }
    }

    // MARK: - Image Upload

    private func uploadImages(entryId: String, images: [UIImage]) async {
        guard let userId = supabase.currentSession?.user.id.uuidString else { return }

        var entryImages: [EntryImage] = []

        for (index, image) in images.enumerated() {
            do {
                let url = try await supabase.uploadEntryImage(
                    image: image,
                    userId: userId,
                    entryId: entryId,
                    index: index
                )
                let entryImage = EntryImage(
                    url: url,
                    isPoster: index == 0,
                    order: index
                )
                entryImages.append(entryImage)
            } catch {
                print("Image upload error for index \(index): \(error)")
            }
        }

        // Update the entry with the images array
        if !entryImages.isEmpty {
            do {
                try await supabase.updateEntryImages(entryId: entryId, images: entryImages)
            } catch {
                print("Failed to update entry images: \(error)")
            }
        }
    }

    // MARK: - AI Processing

    private func runInference(entryId: String, content: String) async {
        do {
            let result = try await supabase.inferEntry(content: content)
            await MainActor.run {
                self.inferenceResult = result
            }

            // Update entry with inferred fields
            var updates: [String: String] = [:]
            if let headline = result.headline { updates["headline"] = headline }
            if let subheading = result.subheading { updates["subheading"] = subheading }
            if let category = result.category { updates["category"] = category }
            if let mood = result.mood { updates["mood"] = mood }
            if let entryType = result.entryType { updates["entry_type"] = entryType }
            if let connectionType = result.connectionType { updates["connection_type"] = connectionType }

            if !updates.isEmpty {
                try? await supabase.updateEntry(id: entryId, fields: updates)
            }
        } catch {
            print("Inference error: \(error)")
        }
    }

    private func runVersionGeneration(entry: Entry) async {
        do {
            try await supabase.generateVersions(entry: entry)
            print("Versions generated successfully for entry \(entry.id)")
        } catch {
            print("Version generation error: \(error)")
        }
    }

    private func runEnrichment(entryId: String, content: String, timeOfDay: String, dayOfWeek: String) async {
        do {
            let result = try await supabase.inferEnrichment(content: content, timeOfDay: timeOfDay, dayOfWeek: dayOfWeek)

            // Update mood if enrichment returned one
            if let moods = result.mood, let firstMood = moods.first {
                try? await supabase.updateEntry(id: entryId, fields: ["mood": firstMood])
            }

            // Build enriched metadata and update
            let enrichedMetadata = EntryMetadata(
                activity: result.activity,
                energy: result.energy,
                environment: result.environment,
                trigger: result.trigger,
                dayOfWeek: dayOfWeek,
                timeOfDay: timeOfDay,
                device: "mobile"
            )
            try? await supabase.updateEntryMetadata(id: entryId, metadata: enrichedMetadata)
        } catch {
            print("Enrichment error: \(error)")
        }
    }
}

// MARK: - Post-Capture Sheet

struct PostCaptureSheet: View {
    let inferenceResult: InferEntryResponse?
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            if let result = inferenceResult {
                VStack(spacing: 12) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 28))
                        .foregroundStyle(.understoodCrimson)

                    if let headline = result.headline, !headline.isEmpty {
                        Text(headline)
                            .font(Typography.cardHeadlineLight)
                            .multilineTextAlignment(.center)
                    }

                    HStack(spacing: 12) {
                        if let category = result.category {
                            Text(category.uppercased())
                                .font(Typography.categoryLabel)
                                .tracking(1.5)
                                .foregroundStyle(.understoodCrimson)
                        }
                        if let mood = result.mood {
                            Text(mood)
                                .font(Typography.info)
                                .foregroundStyle(.textSecondary)
                        }
                    }

                    if result.entryType == "connection", let connectionType = result.connectionType {
                        Text("Belief detected: \(connectionType.replacingOccurrences(of: "_", with: " ").capitalized)")
                            .font(Typography.uiMedium)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.understoodCrimson.opacity(0.1))
                            .cornerRadius(12)
                    }
                }

                Text("Entry saved and analyzed")
                    .font(Typography.small)
                    .foregroundStyle(.textSecondary)
            }

            Button {
                onDismiss()
            } label: {
                Text("Done")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.black)
                    .foregroundStyle(.white)
                    .cornerRadius(8)
            }
            .padding(.horizontal, 32)
        }
        .padding(.top, 20)
        .padding(.bottom, 16)
    }
}

#Preview {
    CaptureView()
}
