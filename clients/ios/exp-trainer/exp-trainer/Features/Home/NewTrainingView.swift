import SwiftUI

struct NewTrainingView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var draft: TrainingDraft

    init(initialDraft: TrainingDraft) {
        _draft = State(initialValue: initialDraft)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: ETSpacing.lg) {
                    fieldTitle("练习主题")
                    TextField("例如：向团队汇报本周进展", text: $draft.topic, axis: .vertical)
                        .textFieldStyle(.plain)
                        .padding(16)
                        .background(ETColor.surface, in: RoundedRectangle(cornerRadius: 14))

                    fieldTitle("这次只练一个目标")
                    VStack(spacing: 10) {
                        ForEach(TrainingGoal.allCases) { goal in
                            GoalChip(goal: goal, selected: draft.goal == goal) { draft.goal = goal }
                        }
                    }

                    fieldTitle("目标时长")
                    Picker("目标时长", selection: $draft.targetDuration) {
                        Text("1 分钟").tag(TimeInterval(60))
                        Text("3 分钟").tag(TimeInterval(180))
                        Text("5 分钟").tag(TimeInterval(300))
                        Text("10 分钟").tag(TimeInterval(600))
                    }
                    .pickerStyle(.segmented)

                    Toggle(isOn: Binding(
                        get: { draft.realtimeAIEnabled },
                        set: { enabled in
                            if enabled && !app.hasConsentedToAI {
                                app.requestAIConsent()
                            } else {
                                draft.realtimeAIEnabled = enabled
                            }
                        }
                    )) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("实时 AI 教练").font(.headline)
                            Text("关闭时全部训练能力仍可使用")
                                .font(.caption)
                                .foregroundStyle(ETColor.secondaryText)
                        }
                    }
                    .tint(ETColor.teal)
                    .expressionCard()

                    HStack(spacing: 8) {
                        Image(systemName: "lock.shield")
                        Text("默认不保存原始录音；final 字幕会增量保存在本机。")
                    }
                    .font(.caption)
                    .foregroundStyle(ETColor.secondaryText)

                    PrimaryActionButton(title: "开始训练", symbol: "mic.fill") {
                        app.beginTraining(draft)
                    }
                }
                .padding(ETSpacing.lg)
            }
            .expressionScreen()
            .navigationTitle("新建训练")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
        .preferredColorScheme(.dark)
        .accessibilityIdentifier("screen.newTraining")
        .onChange(of: app.hasConsentedToAI) { _, consented in
            if consented { draft.realtimeAIEnabled = true }
        }
    }

    private func fieldTitle(_ title: String) -> some View {
        Text(title).font(.headline).foregroundStyle(ETColor.ivory)
    }
}
