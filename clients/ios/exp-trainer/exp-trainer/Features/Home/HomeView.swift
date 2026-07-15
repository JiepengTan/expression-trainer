import SwiftUI

struct HomeView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ETSpacing.lg) {
                header
                Text("今天练什么？")
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                VoiceRibbon(height: 68)
                startButton

                if let recent = app.sessions.first(where: { $0.state == .completed }) {
                    HStack {
                        Text("最近练习").font(.headline)
                        Spacer()
                        Button("同题复练") { app.presentNewTraining(prefill: recent) }
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(ETColor.orange)
                    }
                    SessionCard(session: recent) { app.routes.append(.report(recent.id)) }
                } else {
                    emptyState
                }
            }
            .padding(ETSpacing.lg)
        }
        .expressionScreen()
        .accessibilityIdentifier(app.sessions.isEmpty ? "screen.home.empty" : "screen.home.returning")
        .sheet(item: Binding(
            get: { app.presentedTrainingDraft.map(TrainingDraftSheetItem.init) },
            set: { if $0 == nil { app.presentedTrainingDraft = nil } }
        )) { item in
            NewTrainingView(initialDraft: item.draft)
        }
        .onAppear { app.reload() }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("EXPRESSION TRAINER")
                    .font(.system(size: 12, weight: .bold))
                    .tracking(1.4)
                    .foregroundStyle(ETColor.orange)
                Text("把话说清楚")
                    .font(.system(size: 13))
                    .foregroundStyle(ETColor.secondaryText)
            }
            Spacer()
            Button { app.routes.append(.settings) } label: {
                Image(systemName: "gearshape")
                    .font(.title3)
                    .frame(width: 44, height: 44)
                    .background(ETColor.surface, in: Circle())
            }
            .foregroundStyle(ETColor.ivory)
            .accessibilityLabel("设置")
        }
    }

    private var startButton: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                PrimaryActionButton(title: "开始训练", symbol: "mic.fill") {
                    app.presentNewTraining()
                }
            } else {
                Button { app.presentNewTraining() } label: {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [ETColor.orangeBright, ETColor.orange],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .shadow(color: ETColor.orange.opacity(0.22), radius: 28)
                        VStack(spacing: 8) {
                            Image(systemName: "mic.fill").font(.title2)
                            Text("开始训练").font(.title3.bold())
                        }
                        .foregroundStyle(.white)
                    }
                    .frame(width: 174, height: 174)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
        }
        .accessibilityLabel("开始新训练")
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 9) {
            Label("第一次练习可以从 3 分钟开始", systemImage: "lightbulb")
                .font(.headline)
                .foregroundStyle(ETColor.amber)
            Text("选一个真实场景，比如周会发言、项目汇报或面试自我介绍。")
                .font(.subheadline)
                .foregroundStyle(ETColor.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .expressionCard()
    }
}

private struct TrainingDraftSheetItem: Identifiable {
    let id = UUID()
    let draft: TrainingDraft
}
