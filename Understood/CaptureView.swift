//
//  CaptureView.swift
//  Understood
//
//  Created by Adam Blair on 2/25/26.
//

import SwiftUI
import PhotosUI
import UIKit
import AVFoundation
import Combine
import Speech
import Auth

struct CaptureView: View {
    @Environment(\.dismiss) private var dismiss
    let supabase = SupabaseService.shared

    // Water Cycle linked entry params (optional)
    var sourceEntryId: String? = nil
    var entryType: String = "story"
    var prefillCategory: String? = nil

    // Form state
    @State private var content = ""
    @State private var selectedCategory = "Business"
    @FocusState private var isContentFocused: Bool

    // Photo state
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var selectedImages: [UIImage] = []
    @State private var isLoadingPhotos = false
    @State private var photoLoadError: String?
    @State private var showCamera = false

    // Save state
    @State private var isSaving = false
    @State private var savedEntry: Entry?
    @State private var errorMessage: String?
    @StateObject private var speechCapture = SpeechCaptureController()
    @State private var autosaveTask: Task<Void, Never>?
    @State private var isAutosaving = false
    @State private var lastAutosavedContent = ""
    @State private var lastAutosavedCategory = ""
    @State private var hasLocalDraft = false
    @State private var saveFeedbackVisible = false

    let categories = ["Business", "Finance", "Health", "Spiritual", "Fun", "Social", "Romance"]

    var onSaved: (() -> Void)?

    private var trimmedContent: String {
        content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSave: Bool {
        !trimmedContent.isEmpty && !isSaving && !isLoadingPhotos && photoLoadError == nil
    }

    private var remainingImageSlots: Int {
        max(0, Entry.maxImagesPerEntry - selectedImages.count)
    }

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
                            maxSelectionCount: max(1, remainingImageSlots),
                            matching: .images,
                            photoLibrary: .shared()
                        ) {
                            HStack(spacing: 6) {
                                Image(systemName: "photo.on.rectangle.angled")
                                    .font(.system(size: 15, weight: .semibold))
                                Text(selectedImages.isEmpty ? "Add Photos" : "\(selectedImages.count)/\(Entry.maxImagesPerEntry) Photos")
                                    .font(Typography.uiMedium)
                                    .fontWeight(.semibold)
                            }
                            .foregroundStyle(.textSecondary)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                        }
                        .onChange(of: selectedPhotoItems) { _, items in
                            Task { await loadSelectedPhotos(items) }
                        }
                        .disabled(remainingImageSlots == 0)

                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 6)

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

                    if isLoadingPhotos {
                        HStack(spacing: 8) {
                            ProgressView()
                                .scaleEffect(0.75)
                            Text("Preparing photos...")
                                .font(Typography.small)
                                .foregroundStyle(.textSecondary)
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 8)
                    }

                    if let photoLoadError {
                        Text(photoLoadError)
                            .font(Typography.small)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 20)
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
                                Text(placeholderText)
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

                    if let speechError = speechCapture.errorMessage {
                        Text(speechError)
                            .font(Typography.small)
                            .foregroundStyle(.red)
                            .padding(.horizontal, 20)
                            .padding(.bottom, 8)
                    }

                    if savedEntry != nil || isAutosaving || hasLocalDraft {
                        Text(captureSaveStatusText)
                            .font(Typography.small)
                            .foregroundStyle(.textSecondary)
                            .padding(.horizontal, 20)
                            .padding(.bottom, 8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                bottomCaptureDock
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.sandyBrown, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .tint(.black)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(captureTitle)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundStyle(.black)
                }
            }
            .onAppear {
                if let prefillCategory {
                    selectedCategory = prefillCategory
                }
                restoreLocalDraftIfNeeded()
            }
            .onChange(of: content) { _, _ in
                scheduleAutosave()
            }
            .onChange(of: selectedCategory) { _, _ in
                scheduleAutosave()
            }
            .onDisappear {
                autosaveTask?.cancel()
                speechCapture.stopTranscription()
            }
            .fullScreenCover(isPresented: $showCamera) {
                CameraImagePicker { image in
                    guard let image, remainingImageSlots > 0 else { return }
                    selectedImages.append(image)
                    selectedPhotoItems.removeAll()
                    photoLoadError = nil
                }
                .ignoresSafeArea()
            }
        }
    }

    private var bottomCaptureDock: some View {
        HStack(spacing: 0) {
            Button {
                showCamera = true
            } label: {
                bottomIcon(systemName: "camera.fill", label: "Camera", foreground: .textPrimary, iconSize: 24)
            }
            .buttonStyle(.plain)
            .disabled(remainingImageSlots == 0 || !UIImagePickerController.isSourceTypeAvailable(.camera))

            Button {
                isContentFocused = false
                Task {
                    await speechCapture.toggleTranscription(currentText: content) { transcript in
                        content = transcript
                    }
                }
            } label: {
                bottomIcon(
                    systemName: speechCapture.isRecording ? "stop.fill" : "mic.fill",
                    label: speechCapture.isRecording ? "Stop" : "Dictate",
                    foreground: .understoodCrimson,
                    iconSize: 34
                )
                .scaleEffect(speechCapture.isRecording ? 1.08 : 1)
                .opacity(speechCapture.isRecording ? 0.72 : 1)
                .animation(
                    speechCapture.isRecording
                        ? .easeInOut(duration: 0.9).repeatForever(autoreverses: true)
                        : .default,
                    value: speechCapture.isRecording
                )
            }
            .buttonStyle(.plain)

            Button {
                Task { await saveEntry() }
            } label: {
                if isSaving {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.textPrimary)
                        .frame(width: 72, height: 58)
                } else {
                    bottomIcon(
                        systemName: saveFeedbackVisible ? "checkmark.circle.fill" : "tray.and.arrow.down.fill",
                        label: saveFeedbackVisible ? "Saved" : "Save",
                        foreground: .textPrimary,
                        iconSize: 24
                    )
                    .contentTransition(.symbolEffect(.replace))
                }
            }
            .disabled(!canSave)
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 8)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(Color.sandyBrown)
        .overlay(alignment: .top) {
            Divider()
        }
    }

    private func bottomIcon(systemName: String, label: String, foreground: Color, iconSize: CGFloat) -> some View {
        VStack(spacing: 4) {
            Image(systemName: systemName)
                .font(.system(size: iconSize, weight: .bold))
            Text(label)
                .font(Typography.chipLabel)
                .fontWeight(.semibold)
        }
        .foregroundStyle(foreground)
        .frame(maxWidth: .infinity)
        .frame(height: 58)
    }

    private var captureTitle: String {
        switch entryType {
        case "action": return "New Action"
        case "note": return "New Note"
        default: return sourceEntryId != nil ? "New Story" : "Capture"
        }
    }

    private var captureSaveStatusText: String {
        if isAutosaving { return "Saving..." }
        if savedEntry != nil { return "Saved" }
        return "Draft saved"
    }

    private var placeholderText: String {
        switch entryType {
        case "action": return "What do you want to do?"
        case "note": return "What are you noticing?"
        default: return "What happened? What are you thinking about?"
        }
    }

    // MARK: - Photo Loading

    private func loadSelectedPhotos(_ items: [PhotosPickerItem]) async {
        await MainActor.run {
            isLoadingPhotos = true
            photoLoadError = nil
        }

        var newImages: [UIImage] = []
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                newImages.append(image)
            }
        }
        await MainActor.run {
            selectedImages = newImages
            isLoadingPhotos = false
            if newImages.count != items.count {
                photoLoadError = "One or more photos could not be prepared. Remove and re-add them before saving."
            }
        }
    }

    // MARK: - Save Logic

    private func saveEntry() async {
        autosaveTask?.cancel()
        speechCapture.stopTranscription()
        isSaving = true
        saveFeedbackVisible = false
        errorMessage = nil

        if let savedEntry {
            do {
                try await updateAutosavedEntryIfNeeded(savedEntry.id)
                if !selectedImages.isEmpty {
                    try await uploadImages(entryId: savedEntry.id, images: selectedImages)
                }
                onSaved?()
                await showSaveFeedbackThenDismiss()
            } catch {
                await MainActor.run {
                    errorMessage = "Entry saved, but image upload failed: \(error.localizedDescription)"
                    isSaving = false
                }
            }
            return
        }

        let metadata = captureMetadata()

        do {
            // 1. Save to Supabase (text only, get entry ID)
            let entry = try await supabase.createEntry(
                content: content,
                category: selectedCategory,
                entryType: entryType,
                sourceEntryId: sourceEntryId,
                metadata: metadata
            )
            savedEntry = entry
            markAutosaved()
            Haptics.success()

            // 2. Attach images before leaving capture so returning to the feed is reliable.
            let imagesToUpload = selectedImages
            if !imagesToUpload.isEmpty {
                try await uploadImages(entryId: entry.id, images: imagesToUpload)
            }

            // 3. Notify feed to refresh
            onSaved?()

            await showSaveFeedbackThenDismiss()

        } catch {
            await MainActor.run {
                if savedEntry == nil {
                    errorMessage = "Failed to save: \(error.localizedDescription)"
                } else {
                    errorMessage = "Entry saved, but image upload failed: \(error.localizedDescription)"
                }
                isSaving = false
            }
            print("Save error: \(error)")
        }
    }

    private func showSaveFeedbackThenDismiss() async {
        await MainActor.run {
            isSaving = false
            saveFeedbackVisible = true
            Haptics.light()
        }

        try? await Task.sleep(for: .milliseconds(450))

        await MainActor.run {
            dismiss()
        }
    }

    private func scheduleAutosave() {
        autosaveTask?.cancel()

        persistLocalDraft()

        guard !trimmedContent.isEmpty, !isSaving, supabase.currentSession != nil else { return }

        autosaveTask = Task {
            try? await Task.sleep(for: .seconds(2.0))
            guard !Task.isCancelled else { return }
            await autoSaveEntry()
        }
    }

    private func autoSaveEntry() async {
        guard !trimmedContent.isEmpty, !isSaving, !isAutosaving else { return }
        guard content != lastAutosavedContent || selectedCategory != lastAutosavedCategory else { return }

        isAutosaving = true
        defer { isAutosaving = false }

        do {
            if let savedEntry {
                try await updateAutosavedEntryIfNeeded(savedEntry.id)
            } else {
                let entry = try await supabase.createEntry(
                    content: content,
                    category: selectedCategory,
                    entryType: entryType,
                    sourceEntryId: sourceEntryId,
                    metadata: captureMetadata()
                )
                savedEntry = entry
                onSaved?()
                Haptics.light()
                markAutosaved()
            }
        } catch {
            print("Autosave error: \(error)")
        }
    }

    private func updateAutosavedEntryIfNeeded(_ entryId: String) async throws {
        guard content != lastAutosavedContent || selectedCategory != lastAutosavedCategory else { return }

        try await supabase.updateEntry(id: entryId, fields: [
            "content": content,
            "category": selectedCategory
        ])
        markAutosaved()
        onSaved?()
    }

    private func markAutosaved() {
        lastAutosavedContent = content
        lastAutosavedCategory = selectedCategory
        clearLocalDraft()
    }

    private var localDraftKey: String {
        let source = sourceEntryId ?? "root"
        return "captureDraft.\(entryType).\(source)"
    }

    private func persistLocalDraft() {
        guard !trimmedContent.isEmpty else {
            clearLocalDraft()
            return
        }

        let draft = CaptureLocalDraft(content: content, category: selectedCategory)
        if let data = try? JSONEncoder().encode(draft) {
            UserDefaults.standard.set(data, forKey: localDraftKey)
            hasLocalDraft = true
        }
    }

    private func restoreLocalDraftIfNeeded() {
        guard content.isEmpty,
              let data = UserDefaults.standard.data(forKey: localDraftKey),
              let draft = try? JSONDecoder().decode(CaptureLocalDraft.self, from: data) else {
            return
        }

        content = draft.content
        selectedCategory = draft.category
        hasLocalDraft = !draft.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func clearLocalDraft() {
        UserDefaults.standard.removeObject(forKey: localDraftKey)
        hasLocalDraft = false
    }

    private func captureMetadata() -> EntryMetadata {
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

        return EntryMetadata(
            timestamp: ISO8601DateFormatter().string(from: now),
            dayOfWeek: dayOfWeek,
            timeOfDay: timeOfDay,
            device: "mobile"
        )
    }

    // MARK: - Image Upload

    private func uploadImages(entryId: String, images: [UIImage]) async throws {
        guard let userId = supabase.currentSession?.user.id.uuidString else {
            throw NSError(domain: "CaptureView", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }

        var entryImages: [EntryImage] = []
        var uploadErrors: [Error] = []

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
                uploadErrors.append(error)
                print("Image upload error for index \(index): \(error)")
            }
        }

        if !entryImages.isEmpty {
            try await supabase.updateEntryImages(entryId: entryId, images: entryImages)
        }

        if entryImages.count != images.count {
            throw NSError(
                domain: "CaptureView",
                code: 500,
                userInfo: [NSLocalizedDescriptionKey: "\(uploadErrors.count) image upload(s) failed. The text entry was saved."]
            )
        }
    }
}

private struct CaptureLocalDraft: Codable {
    let content: String
    let category: String
}

@MainActor
final class SpeechCaptureController: ObservableObject {
    @Published private(set) var isRecording = false
    @Published var errorMessage: String?

    private let audioEngine = AVAudioEngine()
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var baseText = ""

    func toggleTranscription(currentText: String, onTranscript: @escaping (String) -> Void) async {
        if isRecording {
            stopTranscription()
            return
        }

        await startTranscription(currentText: currentText, onTranscript: onTranscript)
    }

    private func startTranscription(currentText: String, onTranscript: @escaping (String) -> Void) async {
        errorMessage = nil

        guard await requestSpeechAuthorization(), await requestMicrophoneAuthorization() else {
            errorMessage = "Microphone or speech recognition permission is needed to dictate."
            return
        }

        guard let speechRecognizer, speechRecognizer.isAvailable else {
            errorMessage = "Speech recognition is not available right now."
            return
        }

        recognitionTask?.cancel()
        recognitionTask = nil

        let audioSession = AVAudioSession.sharedInstance()

        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = true
            recognitionRequest = request
            baseText = currentText.trimmingCharacters(in: .whitespacesAndNewlines)

            let inputNode = audioEngine.inputNode
            let recordingFormat = inputNode.outputFormat(forBus: 0)
            inputNode.removeTap(onBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
                self?.recognitionRequest?.append(buffer)
            }

            audioEngine.prepare()
            try audioEngine.start()
            isRecording = true

            recognitionTask = speechRecognizer.recognitionTask(with: request) { [weak self] result, error in
                Task { @MainActor in
                    guard let self else { return }

                    if let result {
                        let spokenText = result.bestTranscription.formattedString
                        onTranscript(self.mergedTranscript(spokenText))

                        if result.isFinal {
                            self.stopTranscription()
                        }
                    }

                    if error != nil {
                        self.stopTranscription()
                    }
                }
            }
        } catch {
            errorMessage = "Could not start dictation: \(error.localizedDescription)"
            stopTranscription()
        }
    }

    private func mergedTranscript(_ spokenText: String) -> String {
        guard !baseText.isEmpty else { return spokenText }
        guard !spokenText.isEmpty else { return baseText }
        return "\(baseText)\n\(spokenText)"
    }

    func stopTranscription() {
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }

        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil

        isRecording = false

        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func requestSpeechAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    private func requestMicrophoneAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { isGranted in
                continuation.resume(returning: isGranted)
            }
        }
    }
}

#Preview {
    CaptureView()
}
