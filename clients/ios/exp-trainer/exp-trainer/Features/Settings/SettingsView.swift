import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var app
    @State private var storageText = "正在计算…"

    var body: some View {
        @Bindable var app = app
        Form {
            Section("训练默认值") {
                Picker("默认目标", selection: $app.defaultGoal) {
                    ForEach(TrainingGoal.allCases) { goal in Text(goal.title).tag(goal) }
                }
                Picker("默认时长", selection: $app.defaultDuration) {
                    Text("1 分钟").tag(TimeInterval(60))
                    Text("3 分钟").tag(TimeInterval(180))
                    Text("5 分钟").tag(TimeInterval(300))
                    Text("10 分钟").tag(TimeInterval(600))
                }
            }

            Section {
                Toggle("实时 AI 教练", isOn: Binding(
                    get: { app.realtimeAIEnabled },
                    set: { enabled in
                        if enabled && !app.hasConsentedToAI {
                            app.requestAIConsent()
                        } else {
                            app.realtimeAIEnabled = enabled
                        }
                    }
                ))
                .tint(ETColor.teal)
            } header: {
                Text("AI")
            } footer: {
                Text("默认关闭。开启后仅发送训练主题、确认逐字稿与本地问题摘要；App 不保存供应商密钥。")
            }

            Section("权限") {
                permissionRow(.microphone, title: "麦克风")
                permissionRow(.speechRecognition, title: "语音识别")
            }

            Section("本地数据") {
                LabeledContent("占用空间", value: storageText)
                Button("清除全部训练数据", role: .destructive) {
                    app.overlay = .confirmDeleteAll
                }
            }

            Section("隐私") {
                Label("默认不保存原始录音", systemImage: "waveform.slash")
                Label("无需登录，不启用 iCloud", systemImage: "person.crop.circle.badge.xmark")
                Label("日志不记录完整逐字稿", systemImage: "doc.text.magnifyingglass")
            }

            Section("关于") {
                LabeledContent("产品", value: "Expression Trainer")
                LabeledContent("版本", value: version)
                Text("把话说清楚")
                    .foregroundStyle(ETColor.secondaryText)
            }
        }
        .scrollContentBackground(.hidden)
        .expressionScreen()
        .navigationTitle("设置")
        .accessibilityIdentifier("screen.settings")
        .task {
            let bytes = await app.environment.storage.localStorageBytes()
            storageText = ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
        }
    }

    private func permissionRow(_ kind: PermissionKind, title: String) -> some View {
        let state = app.environment.permissions.status(for: kind)
        return HStack {
            Text(title)
            Spacer()
            Text(permissionTitle(state))
                .foregroundStyle(state == .granted ? ETColor.teal : ETColor.amber)
            if state == .denied {
                Button("设置") { app.environment.permissions.openSystemSettings() }
                    .font(.caption)
            }
        }
    }

    private func permissionTitle(_ state: PermissionState) -> String {
        switch state {
        case .notDetermined: "未请求"
        case .granted: "已允许"
        case .denied: "未允许"
        }
    }

    private var version: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(short) (\(build))"
    }
}
