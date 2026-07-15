import SwiftUI

struct TranscriptReviewView: View {
    let sessionID: UUID
    @Environment(AppModel.self) private var app
    @State private var transcript = ""
    @State private var issues: [ExpressionIssue] = []
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ETSpacing.lg) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("校正逐字稿")
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    Text("只修改识别错误，不必润色。确认后的版本将作为所有客观统计的唯一来源。")
                        .font(.subheadline)
                        .foregroundStyle(ETColor.secondaryText)
                }

                TextEditor(text: $transcript)
                    .font(.body)
                    .lineSpacing(6)
                    .scrollContentBackground(.hidden)
                    .padding(12)
                    .frame(minHeight: 330)
                    .background(ETColor.surface, in: RoundedRectangle(cornerRadius: 16))
                    .overlay { RoundedRectangle(cornerRadius: 16).stroke(ETColor.border) }
                    .accessibilityLabel("逐字稿编辑器")

                issueSummary

                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(ETColor.amber)
                }

                PrimaryActionButton(
                    title: isSaving ? "正在确认…" : "确认并查看复盘",
                    symbol: "checkmark",
                    isEnabled: !transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSaving
                ) {
                    confirmTranscript()
                }
            }
            .padding(ETSpacing.lg)
        }
        .expressionScreen()
        .navigationBarBackButtonHidden(true)
        .accessibilityIdentifier("screen.transcriptReview")
        .task { loadSession() }
        .task(id: transcript) {
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            issues = app.environment.lexiconAnalyzer.analyze(transcript)
        }
    }

    private var issueSummary: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("本地标记").font(.headline)
                Spacer()
                Text("\(issues.count) 处").font(.subheadline).foregroundStyle(ETColor.amber)
            }
            if issues.isEmpty {
                Text("暂未发现词库中的高频表达问题。")
                    .font(.subheadline)
                    .foregroundStyle(ETColor.secondaryText)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(issues) { issue in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(issue.category.displayName).font(.caption2).foregroundStyle(semanticColor(issue.category))
                                Text(issue.matchedText).font(.subheadline.bold())
                                if let suggestion = issue.suggestions.first {
                                    Text(suggestion).font(.caption2).foregroundStyle(ETColor.secondaryText)
                                }
                            }
                            .padding(10)
                            .background(ETColor.surfaceElevated, in: RoundedRectangle(cornerRadius: 10))
                        }
                    }
                }
            }
        }
        .expressionCard()
    }

    private func loadSession() {
        guard transcript.isEmpty, let session = app.session(id: sessionID) else { return }
        transcript = session.confirmedTranscript
        issues = app.environment.lexiconAnalyzer.analyze(transcript)
    }

    private func confirmTranscript() {
        guard let session = app.session(id: sessionID) else { return }
        isSaving = true
        errorMessage = nil
        let confirmedIssues = app.environment.lexiconAnalyzer.analyze(transcript)
        do {
            try app.environment.repository.replaceTranscript(
                sessionID: sessionID,
                text: transcript,
                issues: confirmedIssues
            )
            let start = Date(timeIntervalSince1970: 0)
            let metrics = TrainingMetrics.calculate(
                transcript: transcript,
                startedAt: start,
                endedAt: start.addingTimeInterval(session.effectiveDuration),
                pausedIntervals: [],
                issueCount: confirmedIssues.count
            )
            try app.environment.repository.updateMetrics(sessionID: sessionID, metrics: metrics)
            if session.state == .transcriptReview {
                try app.environment.repository.transition(sessionID: sessionID, to: .completed)
            }
            app.showReport(sessionID: sessionID)
        } catch {
            errorMessage = "确认失败：\(error.localizedDescription)"
        }
        isSaving = false
    }

    private func semanticColor(_ category: ExpressionIssueCategory) -> Color {
        switch category {
        case .filler: ETColor.orange
        case .hesitation, .vague: ETColor.amber
        case .clarity: ETColor.teal
        }
    }
}
