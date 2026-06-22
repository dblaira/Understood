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
    @Environment(AppNavigationState.self) private var nav
    let supabase = SupabaseService.shared

    // Water Cycle linked entry params (optional)
    var sourceEntryId: String? = nil
    var entryType: String = "story"
    var prefillCategory: String? = nil

    // Form state
    @State private var content = ""
    @State private var selectedPatternStep: String? = nil
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
    @State private var lastAutosavedPatternStep: String? = nil
    @State private var hasInitializedSession = false
    @State private var saveFeedbackVisible = false
    @State private var showDeleteConfirm = false
    @State private var isDeleting = false

    var onSaved: (() -> Void)?

    /// Silent backend category while life areas are sunset on iOS
    private let defaultCategory = "Insight"

    private var trimmedContent: String {
        content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSave: Bool {
        !trimmedContent.isEmpty && !isSaving && !isLoadingPhotos
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

                    // MARK: - Pattern Selector

                    HStack {
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
                            HStack(spacing: 8) {
                                Image(systemName: "list.number")
                                    .font(.system(size: 15, weight: .semibold))
                                Text(selectedPatternStep ?? "Pattern")
                                    .font(Typography.uiMedium)
                                    .fontWeight(.semibold)
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            .foregroundStyle(.understoodCrimson)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color.surfaceSubtle)
                            .cornerRadius(20)
                        }

                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)

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

                        saveRowButton
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

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showDeleteConfirm = true
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .disabled(isSaving || isDeleting)
                    .accessibilityLabel(savedEntry == nil ? "Discard draft" : "Delete entry")
                }
            }
            .onAppear {
                guard !hasInitializedSession else { return }
                hasInitializedSession = true

                if let prefillCategory, AdamPattern.isValidStep(prefillCategory) {
                    selectedPatternStep = prefillCategory
                }

                if sourceEntryId == nil {
                    clearLocalDraft()
                } else {
                    restoreLocalDraftIfNeeded()
                }
            }
            .onChange(of: content) { _, _ in
                scheduleAutosave()
            }
            .onChange(of: selectedPatternStep) { _, _ in
                scheduleAutosave()
            }
            .onDisappear {
                autosaveTask?.cancel()
                speechCapture.stopTranscription()
            }
            .sheet(isPresented: $showCamera) {
                CameraImagePicker { image in
                    guard let image, remainingImageSlots > 0 else { return }
                    selectedImages.append(image.uprightOrientation())
                    selectedPhotoItems.removeAll()
                    photoLoadError = nil
                }
                .ignoresSafeArea()
            }
            .alert(deleteAlertTitle, isPresented: $showDeleteConfirm) {
                Button("Cancel", role: .cancel) {}
                Button(deleteAlertActionTitle, role: .destructive) {
                    Task { await handleDeleteAction() }
                }
            } message: {
                Text(deleteAlertMessage)
            }
        }
    }

    private var deleteAlertTitle: String {
        savedEntry == nil ? "Discard Draft?" : "Delete Entry?"
    }

    private var deleteAlertActionTitle: String {
        savedEntry == nil ? "Discard" : "Delete"
    }

    private var deleteAlertMessage: String {
        if savedEntry != nil {
            return "This will permanently delete this entry and cannot be undone."
        }
        return "Clear everything in this capture screen?"
    }

    private var bottomCaptureDock: some View {
        ZStack {
            HStack(spacing: 0) {
                Button {
                    returnHomeFromCapture()
                } label: {
                    bottomIcon(systemName: "house.fill", label: "Home", foreground: .textPrimary, iconSize: 27)
                        .frame(width: 112)
                }
                .buttonStyle(.plain)

                Spacer()

                Button {
                    Task { await openCamera() }
                } label: {
                    bottomIcon(systemName: "camera.fill", label: "Camera", foreground: .textPrimary, iconSize: 27)
                        .frame(width: 112)
                }
                .buttonStyle(.plain)
                .disabled(remainingImageSlots == 0 || !CameraAccess.isAvailable)
            }

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
                    iconSize: 42
                )
                .frame(width: 128)
                .scaleEffect(speechCapture.isRecording ? 1.1 : 1)
                .opacity(speechCapture.isRecording ? 0.72 : 1)
                .animation(
                    speechCapture.isRecording
                        ? .easeInOut(duration: 0.9).repeatForever(autoreverses: true)
                        : .default,
                    value: speechCapture.isRecording
                )
            }
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

    private var saveRowButton: some View {
        Button {
            Task { await saveEntry() }
        } label: {
            HStack(spacing: 6) {
                if isSaving || isAutosaving {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                        .scaleEffect(0.72)
                        .frame(width: 16, height: 16)
                } else {
                    Image(systemName: saveRowIcon)
                        .font(.system(size: 14, weight: .bold))
                        .contentTransition(.symbolEffect(.replace))
                }

                Text(saveRowLabel)
                    .font(Typography.chipLabel)
                    .fontWeight(.bold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .foregroundStyle(.white)
            .frame(width: 118, height: 38)
            .background(saveRowBackground)
            .clipShape(Capsule())
            .animation(.easeInOut(duration: 0.18), value: isAutosaving)
            .animation(.easeInOut(duration: 0.18), value: saveFeedbackVisible)
            .animation(.easeInOut(duration: 0.18), value: savedEntry?.id)
        }
        .disabled(!canSave)
        .buttonStyle(.plain)
        .opacity(canSave || isAutosaving || savedEntry != nil ? 1 : 0.42)
        .accessibilityLabel(saveRowLabel)
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

    private var saveRowLabel: String {
        if isSaving { return "Saving" }
        if isAutosaving { return "Auto saving" }
        if saveFeedbackVisible || (savedEntry != nil && !hasPendingSaveChanges) { return "Saved" }
        return "Save"
    }

    private var saveRowIcon: String {
        if saveFeedbackVisible || (savedEntry != nil && !hasPendingSaveChanges) { return "checkmark" }
        return "tray.and.arrow.down.fill"
    }

    private var saveRowBackground: Color {
        if isAutosaving || saveFeedbackVisible || (savedEntry != nil && !hasPendingSaveChanges) { return .actionGreen }
        return .textPrimary
    }

    private var hasPendingSaveChanges: Bool {
        content != lastAutosavedContent || selectedPatternStep != lastAutosavedPatternStep
    }

    private var placeholderText: String {
        switch entryType {
        case "action": return "What do you want to do?"
        case "note": return "What are you noticing?"
        default: return "What happened? What are you thinking about?"
        }
    }

    private func openCamera() async {
        guard remainingImageSlots > 0 else { return }

        if let message = await CameraAccess.requestIfNeeded() {
            photoLoadError = message
        } else {
            showCamera = true
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
            selectedImages = newImages.map { $0.uprightOrientation() }
            isLoadingPhotos = false
            if newImages.count != items.count {
                photoLoadError = "One or more photos could not be prepared. Remove and re-add them before saving."
            }
        }
    }

    private func handleDeleteAction() async {
        if let savedEntry {
            isDeleting = true
            errorMessage = nil
            do {
                try await supabase.deleteEntry(id: savedEntry.id)
                await MainActor.run {
                    Haptics.warning()
                    resetCaptureState()
                    onSaved?()
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    Haptics.error()
                    errorMessage = "Could not delete entry: \(error.localizedDescription)"
                    isDeleting = false
                }
            }
        } else {
            resetCaptureState()
            Haptics.light()
            dismiss()
        }
    }

    private func resetCaptureState() {
        autosaveTask?.cancel()
        speechCapture.stopTranscription()
        clearLocalDraft()
        content = ""
        selectedPatternStep = nil
        selectedImages = []
        selectedPhotoItems = []
        savedEntry = nil
        errorMessage = nil
        photoLoadError = nil
        isDeleting = false
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
                category: defaultCategory,
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

    private func returnHomeFromCapture() {
        autosaveTask?.cancel()
        speechCapture.stopTranscription()
        persistLocalDraft()
        isContentFocused = false
        nav.returnHome()
        dismiss()
    }

    private func scheduleAutosave() {
        autosaveTask?.cancel()

        persistLocalDraft()

        guard savedEntry != nil, !trimmedContent.isEmpty, !isSaving, supabase.currentSession != nil else { return }

        autosaveTask = Task {
            try? await Task.sleep(for: .seconds(2.0))
            guard !Task.isCancelled else { return }
            await autoSaveEntry()
        }
    }

    private func autoSaveEntry() async {
        guard !trimmedContent.isEmpty, !isSaving, !isAutosaving else { return }
        guard content != lastAutosavedContent || selectedPatternStep != lastAutosavedPatternStep else { return }

        isAutosaving = true
        defer { isAutosaving = false }

        do {
            if let savedEntry {
                try await updateAutosavedEntryIfNeeded(savedEntry.id)
            }
        } catch {
            print("Autosave error: \(error)")
        }
    }

    private func updateAutosavedEntryIfNeeded(_ entryId: String) async throws {
        guard content != lastAutosavedContent || selectedPatternStep != lastAutosavedPatternStep else { return }

        try await supabase.updateEntryMetadata(id: entryId, metadata: captureMetadata())
        try await supabase.updateEntry(id: entryId, fields: [
            "content": content
        ])
        markAutosaved()
        onSaved?()
    }

    private func markAutosaved() {
        lastAutosavedContent = content
        lastAutosavedPatternStep = selectedPatternStep
        clearLocalDraft()
    }

    private var localDraftKey: String {
        let source = sourceEntryId ?? "root"
        return "captureDraft.\(entryType).\(source)"
    }

    private func persistLocalDraft() {
        guard sourceEntryId != nil else {
            clearLocalDraft()
            return
        }

        guard !trimmedContent.isEmpty else {
            clearLocalDraft()
            return
        }

        let draft = CaptureLocalDraft(content: content, patternStep: selectedPatternStep)
        if let data = try? JSONEncoder().encode(draft) {
            UserDefaults.standard.set(data, forKey: localDraftKey)
        }
    }

    private func restoreLocalDraftIfNeeded() {
        guard content.isEmpty,
              let data = UserDefaults.standard.data(forKey: localDraftKey),
              let draft = try? JSONDecoder().decode(CaptureLocalDraft.self, from: data) else {
            return
        }

        content = draft.content
        selectedPatternStep = draft.patternStep
    }

    private func clearLocalDraft() {
        UserDefaults.standard.removeObject(forKey: localDraftKey)
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
            device: "mobile",
            patternStep: selectedPatternStep
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
    let patternStep: String?
}

@MainActor
final class SpeechCaptureController: ObservableObject {
    @Published private(set) var isRecording = false
    @Published private(set) var hasTranscript = false
    @Published var errorMessage: String?

    private var audioEngine = AVAudioEngine()
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var baseText = ""
    private var lastSpokenText = ""
    private var isStopping = false

    func toggleTranscription(currentText: String, onTranscript: @escaping (String) -> Void) async {
        if isRecording {
            stopTranscription()
            return
        }

        await startTranscription(currentText: currentText, onTranscript: onTranscript)
    }

    private func startTranscription(currentText: String, onTranscript: @escaping (String) -> Void) async {
        resetRecognitionSession(deactivateAudioSession: false)
        errorMessage = nil
        hasTranscript = false
        lastSpokenText = ""
        isStopping = false

        guard await requestSpeechAuthorization(), await requestMicrophoneAuthorization() else {
            errorMessage = "Microphone or speech recognition permission is needed to dictate."
            return
        }

        guard let speechRecognizer, speechRecognizer.isAvailable else {
            errorMessage = "Speech recognition is not available right now."
            return
        }

        let audioSession = AVAudioSession.sharedInstance()

        do {
            try audioSession.setCategory(.playAndRecord, mode: .spokenAudio, options: [.duckOthers, .defaultToSpeaker])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = true
            request.requiresOnDeviceRecognition = false
            recognitionRequest = request
            baseText = currentText.trimmingCharacters(in: .whitespacesAndNewlines)

            audioEngine = AVAudioEngine()
            let inputNode = audioEngine.inputNode
            let recordingFormat = inputNode.outputFormat(forBus: 0)
            guard recordingFormat.sampleRate > 0, recordingFormat.channelCount > 0 else {
                throw SpeechCaptureError.invalidAudioInput
            }

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
                        self.lastSpokenText = spokenText
                        self.hasTranscript = !spokenText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        onTranscript(self.mergedTranscript(spokenText))

                        if result.isFinal {
                            self.stopTranscription()
                        }
                    }

                    if error != nil, !self.isStopping {
                        if self.lastSpokenText.isEmpty {
                            self.errorMessage = "Dictation stopped before any words came through. Try once more in a quieter moment."
                        }
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
        isStopping = true
        resetRecognitionSession(deactivateAudioSession: true)
    }

    private func resetRecognitionSession(deactivateAudioSession: Bool) {
        if audioEngine.isRunning {
            audioEngine.stop()
        }

        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil

        isRecording = false

        if deactivateAudioSession {
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
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

private enum SpeechCaptureError: LocalizedError {
    case invalidAudioInput

    var errorDescription: String? {
        "The microphone was not ready. Try dictation again."
    }
}

#Preview {
    CaptureView()
        .environment(AppNavigationState())
}
