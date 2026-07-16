import SwiftUI

struct CowboyAIView: View {
    @State private var model = CowboyAIViewModel()
    @State private var isWorkerMenuPresented = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                modeCard
                if !model.isDiscovered {
                    tailscaleCard
                }
                if model.phase == .needsPairing || (model.isAvailable && !model.isPaired) {
                    pairingCard
                }
                composer
                phaseMessage
                if let envelope = model.envelope {
                    result(envelope)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 120)
        }
        .background(Color.understoodCream.ignoresSafeArea())
        .task {
            await model.start()
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-uitestOpenWorkerMenu") {
                isWorkerMenuPresented = true
            }
            #endif
        }
        .accessibilityIdentifier("cowboyAIView")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("COWBOY AI")
                .font(Typography.sectionHeader)
                .tracking(2)
                .foregroundStyle(.understoodCrimson)
            Text("Your dependable reasoning layer")
                .font(Typography.headline)
                .foregroundStyle(.textPrimary)
            Text("Your words stay intact. Accepted beliefs govern. Everything else is labeled.")
                .font(Typography.subtitle)
                .foregroundStyle(.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var modeCard: some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(modeColor)
                .frame(width: 10, height: 10)
                .padding(.top, 5)
            VStack(alignment: .leading, spacing: 4) {
                Text(model.modeTitle)
                    .font(Typography.uiMedium)
                    .foregroundStyle(.textPrimary)
                Text(model.modeExplanation)
                    .font(Typography.small)
                    .foregroundStyle(.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(Color.surfaceSubtle)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var modeColor: Color {
        switch model.phase {
        case .ready: .actionGreen
        case .thinking, .searching, .pairing: .orange
        case .captureOnly, .unavailable, .needsPairing: .understoodCrimson
        case .failed: .overdueRed
        }
    }

    private var pairingCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("PAIR THIS IPHONE")
                .font(Typography.sectionHeader)
                .tracking(1.5)
                .foregroundStyle(.textMuted)
            TextField("Six-digit code", text: $model.pairingCode)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .font(Typography.body)
                .padding(12)
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .accessibilityIdentifier("cowboyPairingCode")
            Button("Pair Mac") { Task { await model.pair() } }
                .font(Typography.uiMedium)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.understoodCrimson)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding(16)
        .background(Color.understoodBeige)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var tailscaleCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("AWAY FROM THIS NETWORK?")
                .font(Typography.sectionHeader)
                .tracking(1.5)
                .foregroundStyle(.textMuted)
            TextField("Secure Mac address from Tailscale", text: $model.tailscaleAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.URL)
                .font(Typography.body)
                .padding(12)
                .background(Color.surfaceSubtle)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            Button("Connect to my Mac") { Task { await model.connectThroughTailscale() } }
                .font(Typography.uiMedium)
                .foregroundStyle(.understoodCrimson)
        }
        .padding(16)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.borderLight))
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("WHAT DO YOU WANT TO UNDERSTAND?")
                    .font(Typography.sectionHeader)
                    .tracking(1.3)
                    .foregroundStyle(.textMuted)
                Spacer()
                Button {
                    isWorkerMenuPresented = true
                } label: {
                    HStack(spacing: 6) {
                        Text(model.route.label)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 14, weight: .bold))
                    }
                    .font(Typography.uiMedium)
                    .foregroundStyle(Color.understoodCrimson)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Choose worker, currently \(model.route.label)")
                .accessibilityIdentifier("cowboyWorkerMenu")
                .popover(
                    isPresented: $isWorkerMenuPresented,
                    attachmentAnchor: .point(.bottom),
                    arrowEdge: .top
                ) {
                    workerMenu
                        .presentationCompactAdaptation(.popover)
                        .presentationBackground(Color.sandyBrown.opacity(0.55))
                }
            }
            TextEditor(text: $model.rawWords)
                .font(Typography.editor)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 130)
                .padding(12)
                .background(Color.surfaceSubtle)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .accessibilityIdentifier("cowboyRawWords")
            Button {
                Task { await model.submit() }
            } label: {
                HStack {
                    if model.phase == .thinking { ProgressView().tint(.white) }
                    Text(model.phase == .thinking ? "Reasoning" : "Ask Cowboy AI")
                    Spacer()
                    Image(systemName: "arrow.up")
                }
                .font(Typography.uiMedium)
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Color.understoodCrimson)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .disabled(model.rawWords.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || model.phase == .thinking)
            .accessibilityIdentifier("cowboySubmit")
        }
    }

    private var workerMenu: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(CowboyAIViewModel.LaborRoute.allCases) { route in
                Button {
                    model.route = route
                    isWorkerMenuPresented = false
                    Haptics.selection()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 15, weight: .bold))
                            .opacity(model.route == route ? 1 : 0)
                            .frame(width: 18)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(route.label)
                                .font(Typography.uiMedium)
                            Text(route.detail)
                                .font(Typography.small)
                                .opacity(0.72)
                        }

                        Spacer(minLength: 8)
                    }
                    .foregroundStyle(Color.understoodCrimson)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("cowboyWorkerOption-\(route.rawValue)")

                if route != CowboyAIViewModel.LaborRoute.allCases.last {
                    Divider()
                        .overlay(Color.understoodCrimson.opacity(0.12))
                }
            }
        }
        .frame(minWidth: 250)
        .background(Color.sandyBrown.opacity(0.55))
    }

    @ViewBuilder
    private var phaseMessage: some View {
        switch model.phase {
        case .failed(let message):
            Text(message)
                .font(Typography.small)
                .foregroundStyle(.overdueRed)
                .fixedSize(horizontal: false, vertical: true)
        case .searching:
            Label("Looking for Cowboy AI on this network…", systemImage: "dot.radiowaves.left.and.right")
                .font(Typography.small)
                .foregroundStyle(.textSecondary)
        default:
            EmptyView()
        }
    }

    private func result(_ envelope: ReasoningEnvelope) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            resultSection("ANSWER", color: .textPrimary) {
                Text(envelope.finalAnswer)
                    .font(Typography.body)
                    .foregroundStyle(.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("cowboyFinalAnswer")
            }

            resultSection("ACCEPTED AUTHORITY", color: .actionGreen) {
                if envelope.acceptedAuthorityUsed.isEmpty {
                    emptyLabel("No accepted belief was used.")
                } else {
                    ForEach(envelope.acceptedAuthorityUsed) { belief in
                        VStack(alignment: .leading, spacing: 5) {
                            Text(belief.consequent).font(Typography.subtitle).foregroundStyle(.textPrimary)
                            Text("When \(belief.antecedent) · \(Int(belief.confidence * 100))%")
                                .font(Typography.small).foregroundStyle(.textSecondary)
                        }
                    }
                }
            }

            resultSection("SUPPORTING EVIDENCE", color: .blue) {
                if envelope.supportingEvidenceUsed.isEmpty {
                    emptyLabel("No supporting evidence was used.")
                } else {
                    ForEach(envelope.supportingEvidenceUsed) { evidence in
                        VStack(alignment: .leading, spacing: 3) {
                            Text(evidence.label).font(Typography.subtitle).foregroundStyle(.textPrimary)
                            if let source = evidence.source {
                                Text(source).font(Typography.small).foregroundStyle(.textSecondary)
                            }
                        }
                    }
                }
            }

            resultSection("CANDIDATES — REQUIRE REVIEW", color: .orange) {
                if envelope.candidateRelationshipsGenerated.isEmpty {
                    emptyLabel("No new relationship was proposed.")
                } else {
                    ForEach(envelope.candidateRelationshipsGenerated) { candidate in
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "questionmark.diamond")
                                    .foregroundStyle(.orange)
                                Text(candidate.statement)
                                    .font(Typography.subtitle)
                                    .foregroundStyle(.textPrimary)
                            }
                            if model.isAvailable && model.isPaired {
                                HStack(spacing: 10) {
                                    Button("Reject") {
                                        Task { await model.reviewCandidate(candidate, status: "rejected") }
                                    }
                                    Button("Queue for belief review") {
                                        Task { await model.reviewCandidate(candidate, status: "approved_for_supabase_sync") }
                                    }
                                }
                                .font(Typography.small)
                                .buttonStyle(.bordered)
                                .tint(.orange)
                            }
                        }
                    }
                }
            }

            if model.isAvailable && model.isPaired {
                resultSection("TRAINING REVIEW", color: .purple) {
                    Text("Only your approval or replacement enters the adapter dataset.")
                        .font(Typography.small)
                        .foregroundStyle(.textSecondary)
                    TextEditor(text: $model.correctionText)
                        .font(Typography.body)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 88)
                        .padding(10)
                        .background(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    HStack(spacing: 10) {
                        Button("Accept as mine") { Task { await model.acceptAnswer() } }
                        Button("Save my correction") { Task { await model.saveCorrection() } }
                    }
                    .font(Typography.small)
                    .buttonStyle(.bordered)
                    .tint(.purple)
                    if let message = model.reviewMessage {
                        Text(message).font(Typography.small).foregroundStyle(.textSecondary)
                    }
                }
            } else if let message = model.reviewMessage {
                Text(message).font(Typography.small).foregroundStyle(.textSecondary)
            }

            resultSection("ROUTE TRACE", color: .understoodCrimson) {
                ForEach(Array(envelope.routeTrace.enumerated()), id: \.element.id) { index, step in
                    HStack(alignment: .top, spacing: 10) {
                        Text("\(index + 1)").font(Typography.chipLabel)
                            .frame(width: 24, height: 24)
                            .background(Color.surfaceChip)
                            .clipShape(Circle())
                        VStack(alignment: .leading, spacing: 2) {
                            Text(step.worker).font(Typography.subtitle).foregroundStyle(.textPrimary)
                            Text([step.role, step.model].compactMap { $0 }.joined(separator: " · "))
                                .font(Typography.small).foregroundStyle(.textSecondary)
                        }
                    }
                }
                Divider()
                Text("Graph \(envelope.graphRevision) · Adapter \(envelope.adapterVersion)")
                    .font(Typography.small)
                    .foregroundStyle(.textMuted)
            }
        }
    }

    private func resultSection<Content: View>(
        _ title: String,
        color: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Rectangle().fill(color).frame(width: 3, height: 14)
                Text(title).font(Typography.sectionHeader).tracking(1.4).foregroundStyle(.textMuted)
            }
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.surfaceSubtle)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func emptyLabel(_ text: String) -> some View {
        Text(text).font(Typography.small).foregroundStyle(.textSecondary)
    }
}

#Preview {
    CowboyAIView()
}
