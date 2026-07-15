import CoreTransferable
import SwiftUI

struct ReportView: View {
    let sessionID: UUID
    @Environment(AppModel.self) private var app
    @State private var aiReport: AITrainingReport?
    @State private var aiStatus: ReportGenerationStatus = .localOnly
    @State private var progress: Double = 0
    @State private var progressMessage = "准备深度复盘"
    @State private var showingShareOptions = false
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Group {
            if let session = app.session(id: sessionID) {
                ScrollView {
                    VStack(alignment: .leading, spacing: ETSpacing.lg) {
                        reportHeader(session)
                        nextFocusCard(session)
                        metrics(session)
                        issueBreakdown(session)
                        localTranscript(session)
                        aiSection(session)
                        actions(session)
                    }
                    .padding(ETSpacing.lg)
                }
                .task { loadOrGenerateAI(for: session) }
            } else {
                ContentUnavailableView("找不到训练记录", systemImage: "doc.questionmark")
            }
        }
        .expressionScreen()
        .navigationTitle("训练复盘")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier(aiStatus == .generating ? "screen.report.aiLoading" : (aiReport == nil ? "screen.report.local" : "screen.report.aiComplete"))
    }

    private func reportHeader(_ session: TrainingSessionRecord) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(session.topic.isEmpty ? "自由表达" : session.topic)
                .font(.system(.title, design: .rounded, weight: .bold))
            HStack {
                Label(session.goal.title, systemImage: session.goal.symbol)
                Text("·")
                Text(session.createdAt.formatted(date: .abbreviated, time: .shortened))
            }
            .font(.subheadline)
            .foregroundStyle(ETColor.secondaryText)
        }
    }

    private func nextFocusCard(_ session: TrainingSessionRecord) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("下次重点").font(.caption.weight(.semibold)).foregroundStyle(ETColor.teal)
            Text(aiReport?.nextFocus ?? session.nextFocus)
                .font(.title2.weight(.semibold))
            HStack {
                Rectangle().fill(ETColor.teal).frame(height: 3)
                Image(systemName: "star.fill").foregroundStyle(ETColor.teal)
            }
        }
        .padding(20)
        .background(
            LinearGradient(colors: [ETColor.teal.opacity(0.38), ETColor.surface], startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 17)
        )
        .overlay { RoundedRectangle(cornerRadius: 17).stroke(ETColor.teal.opacity(0.5)) }
    }

    private func metrics(_ session: TrainingSessionRecord) -> some View {
        let speed = session.effectiveDuration < 10
            ? "—"
            : session.unitsPerMinute.map { String(format: "%.0f", $0) } ?? "—"
        return VStack(alignment: .leading, spacing: 12) {
            Text("客观数据").font(.headline)
            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: 10) {
                    MetricCard(title: "有效时长", value: duration(session.effectiveDuration), detail: nil, tint: ETColor.ivory)
                    MetricCard(title: "语速", value: speed, detail: "字/分钟", tint: ETColor.amber)
                    MetricCard(title: "有效字数", value: "\(session.effectiveTextUnits)", detail: nil, tint: ETColor.ivory)
                    MetricCard(title: "问题次数", value: "\(session.issueCount)", detail: "只统计 final", tint: ETColor.orange)
                }
            } else {
                HStack(spacing: 10) {
                    MetricCard(title: "有效时长", value: duration(session.effectiveDuration), detail: nil, tint: ETColor.ivory)
                    MetricCard(title: "语速", value: speed, detail: "字/分钟", tint: ETColor.amber)
                }
                HStack(spacing: 10) {
                    MetricCard(title: "有效字数", value: "\(session.effectiveTextUnits)", detail: nil, tint: ETColor.ivory)
                    MetricCard(title: "问题次数", value: "\(session.issueCount)", detail: "只统计 final", tint: ETColor.orange)
                }
            }
        }
    }

    private func issueBreakdown(_ session: TrainingSessionRecord) -> some View {
        let grouped = Dictionary(grouping: session.issues, by: { $0.category })
        return VStack(alignment: .leading, spacing: 13) {
            Text("高频问题词").font(.headline)
            if session.issues.isEmpty {
                Text("这次没有命中本地问题词库。")
                    .foregroundStyle(ETColor.secondaryText)
            } else {
                ForEach(ExpressionIssueCategory.allCases, id: \.self) { category in
                    if let items = grouped[category], !items.isEmpty {
                        HStack {
                            Circle().fill(color(category)).frame(width: 8, height: 8)
                            Text(category.displayName)
                            Spacer()
                            Text("\(items.count)").monospacedDigit().foregroundStyle(color(category))
                        }
                        ForEach(items.prefix(3)) { item in
                            HStack(alignment: .top) {
                                Text("“\(item.matchedText)”").font(.subheadline.bold())
                                Spacer()
                                Text(item.suggestions.first ?? "尝试更具体地表达")
                                    .font(.caption)
                                    .foregroundStyle(ETColor.secondaryText)
                            }
                        }
                    }
                }
            }
        }
        .expressionCard()
    }

    private func localTranscript(_ session: TrainingSessionRecord) -> some View {
        DisclosureGroup {
            Text(session.confirmedTranscript)
                .font(.body)
                .lineSpacing(6)
                .textSelection(.enabled)
                .padding(.top, 10)
        } label: {
            Label("确认逐字稿", systemImage: "text.quote")
                .font(.headline)
        }
        .tint(ETColor.orange)
        .expressionCard()
    }

    @ViewBuilder
    private func aiSection(_ session: TrainingSessionRecord) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("AI 深度复盘", systemImage: "sparkles").font(.headline)
                Spacer()
                Text("不改变客观数据").font(.caption2).foregroundStyle(ETColor.secondaryText)
            }
            switch aiStatus {
            case .queued, .generating:
                ProgressView(value: progress)
                    .tint(ETColor.teal)
                Text(progressMessage).font(.subheadline).foregroundStyle(ETColor.secondaryText)
            case .failed:
                Text("AI 服务暂不可用，本地复盘已完整保留。")
                    .font(.subheadline)
                    .foregroundStyle(ETColor.secondaryText)
                Button("重试") { Task { await generateAI(for: session) } }
                    .foregroundStyle(ETColor.teal)
            case .completed:
                if let aiReport {
                    Text(aiReport.diagnosis).font(.body).lineSpacing(5)
                    ForEach(aiReport.rewrites) { rewrite in
                        VStack(alignment: .leading, spacing: 7) {
                            Text(rewrite.original).strikethrough().foregroundStyle(ETColor.secondaryText)
                            Text(rewrite.revised).foregroundStyle(ETColor.teal)
                            Text(rewrite.reason).font(.caption).foregroundStyle(ETColor.secondaryText)
                        }
                        .padding(12)
                        .background(ETColor.surfaceElevated, in: RoundedRectangle(cornerRadius: 10))
                    }
                }
            case .localOnly:
                Text("开启 AI 后，会基于你的确认逐字稿提供带原句证据的诊断。")
                    .font(.subheadline)
                    .foregroundStyle(ETColor.secondaryText)
                if app.hasConsentedToAI {
                    Button("生成深度复盘") { Task { await generateAI(for: session) } }
                        .foregroundStyle(ETColor.teal)
                } else {
                    Button("了解并开启 AI") { app.requestAIConsent() }
                        .foregroundStyle(ETColor.teal)
                }
            }
        }
        .expressionCard()
    }

    private func actions(_ session: TrainingSessionRecord) -> some View {
        VStack(spacing: 12) {
            PrimaryActionButton(title: "同题再练一次", symbol: "arrow.counterclockwise") {
                app.presentNewTraining(prefill: session)
                app.routes.removeAll()
            }
            Menu {
                ShareLink(item: exportPayload(session, includeReport: false, includeTranscript: true).text) {
                    Label("仅逐字稿（文本）", systemImage: "text.quote")
                }
                ShareLink(
                    item: markdownDocument(session, includeTranscript: false),
                    preview: SharePreview("训练报告")
                ) {
                    Label("报告（不含逐字稿）", systemImage: "doc")
                }
                ShareLink(
                    item: markdownDocument(session, includeTranscript: true),
                    preview: SharePreview("训练报告与逐字稿")
                ) {
                    Label("报告与完整逐字稿", systemImage: "doc.text")
                }
            } label: {
                Label("分享训练记录", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(ETColor.surface, in: RoundedRectangle(cornerRadius: 14))
            }
            .foregroundStyle(ETColor.ivory)
        }
    }

    private func loadOrGenerateAI(for session: TrainingSessionRecord) {
        if let saved = session.reports
            .filter({ $0.transcriptVersion == session.transcriptVersion })
            .sorted(by: { ($0.generatedAt ?? .distantPast) > ($1.generatedAt ?? .distantPast) })
            .first,
           let decoded = saved.decodedReport {
            aiReport = decoded
            aiStatus = .completed
        } else {
            aiStatus = session.reportStatus
            if session.realtimeAIEnabled && app.hasConsentedToAI {
                Task { await generateAI(for: session) }
            }
        }
    }

    private func generateAI(for session: TrainingSessionRecord) async {
        aiStatus = .generating
        progress = 0.05
        progressMessage = "正在读取确认逐字稿"
        try? app.environment.repository.updateReport(
            sessionID: session.id,
            transcriptVersion: session.transcriptVersion,
            status: .generating,
            report: nil,
            errorMessage: nil
        )
        let issues = session.issues.map {
            ExpressionIssue(
                id: $0.id,
                category: $0.category,
                matchedText: $0.matchedText,
                range: UTF16TextRange(location: $0.utf16Location, length: $0.utf16Length),
                suggestions: $0.suggestions,
                segmentID: $0.segmentID
            )
        }
        let metrics = TrainingMetrics(
            effectiveDuration: session.effectiveDuration,
            effectiveTextUnits: session.effectiveTextUnits,
            unitsPerMinute: session.unitsPerMinute,
            issueCount: session.issueCount
        )
        let request = DeepReportRequest(
            sessionID: session.id,
            topic: session.topic,
            goal: session.goal,
            transcriptVersion: session.transcriptVersion,
            transcript: session.confirmedTranscript,
            objectiveMetrics: metrics,
            localIssues: issues
        )
        do {
            let events = try await app.environment.feedback.report(for: request)
            for try await event in events {
                switch event {
                case .progress(let value, let message):
                    progress = value
                    progressMessage = message
                case .partial(let report):
                    aiReport = report
                case .completed(let report):
                    aiReport = report
                    aiStatus = .completed
                    try app.environment.repository.updateReport(
                        sessionID: session.id,
                        transcriptVersion: session.transcriptVersion,
                        status: .completed,
                        report: report,
                        errorMessage: nil
                    )
                    app.reload()
                case .failed(let message):
                    throw BackendError.server(message)
                }
            }
        } catch {
            aiStatus = .failed
            try? app.environment.repository.updateReport(
                sessionID: session.id,
                transcriptVersion: session.transcriptVersion,
                status: .failed,
                report: nil,
                errorMessage: error.localizedDescription
            )
        }
    }

    private func exportPayload(
        _ session: TrainingSessionRecord,
        includeReport: Bool = true,
        includeTranscript: Bool = true
    ) -> SharePayload {
        app.environment.share.payload(
            for: SessionExportSnapshot(
                topic: session.topic,
                goal: session.goal.title,
                createdAt: session.createdAt,
                effectiveDuration: session.effectiveDuration,
                effectiveTextUnits: session.effectiveTextUnits,
                unitsPerMinute: session.unitsPerMinute,
                issueCount: session.issueCount,
                nextFocus: session.nextFocus,
                transcript: session.confirmedTranscript,
                reportSummary: aiReport?.diagnosis
            ),
            includeReport: includeReport,
            includeTranscript: includeTranscript
        )
    }

    private func markdownDocument(
        _ session: TrainingSessionRecord,
        includeTranscript: Bool
    ) -> MarkdownExportDocument {
        let payload = exportPayload(
            session,
            includeReport: true,
            includeTranscript: includeTranscript
        )
        return MarkdownExportDocument(
            filename: session.topic.isEmpty ? "训练复盘" : session.topic,
            data: payload.markdownData ?? Data(payload.text.utf8)
        )
    }

    private func duration(_ interval: TimeInterval) -> String {
        let seconds = Int(interval)
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    private func color(_ category: ExpressionIssueCategory) -> Color {
        switch category {
        case .filler: ETColor.orange
        case .hesitation, .vague: ETColor.amber
        case .clarity: ETColor.teal
        }
    }
}
