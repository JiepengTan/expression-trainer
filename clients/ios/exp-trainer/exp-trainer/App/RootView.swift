import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        @Bindable var app = app
        Group {
            if app.hasCompletedOnboarding {
                NavigationStack(path: $app.routes) {
                    TabView(selection: $app.selectedTab) {
                        HomeView()
                            .tabItem { Label("训练", systemImage: "waveform.and.mic") }
                            .tag(RootTab.training)
                        HistoryView()
                            .tabItem { Label("历史", systemImage: "clock.arrow.circlepath") }
                            .tag(RootTab.history)
                    }
                    .tint(ETColor.orange)
                    .navigationDestination(for: AppRoute.self) { route in
                        switch route {
                        case .settings:
                            SettingsView()
                        case .training(let id):
                            TrainingView(sessionID: id)
                        case .transcriptReview(let id):
                            TranscriptReviewView(sessionID: id)
                        case .report(let id):
                            ReportView(sessionID: id)
                        }
                    }
                }
            } else {
                OnboardingView()
            }
        }
        .alert(item: Binding(get: { app.overlay }, set: { app.overlay = $0 })) { overlay in
            alert(for: overlay)
        }
        .overlay(alignment: .top) {
            if let toast = app.toast {
                Text(toast)
                    .font(.subheadline)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(ETColor.surfaceElevated, in: Capsule())
                    .overlay { Capsule().stroke(ETColor.border) }
                    .padding(.top, 10)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .task {
                        try? await Task.sleep(for: .seconds(3))
                        if app.toast == toast { app.toast = nil }
                    }
            }
        }
    }

    private func alert(for overlay: AppOverlay) -> Alert {
        switch overlay {
        case .permissionDenied:
            Alert(
                title: Text("需要系统权限"),
                message: Text("请在系统设置中允许麦克风与语音识别。历史记录和本地复盘仍可正常查看。"),
                primaryButton: .default(Text("打开设置")) {
                    app.environment.permissions.openSystemSettings()
                    app.overlay = nil
                },
                secondaryButton: .cancel(Text("稍后")) { app.overlay = nil }
            )
        case .speechPreparing:
            Alert(
                title: Text("正在准备离线语音识别"),
                message: Text("首次使用可能需要下载普通话资源。可以取消并稍后继续。"),
                primaryButton: .default(Text("后台继续")) { app.overlay = nil },
                secondaryButton: .cancel(Text("取消")) {
                    Task { await app.environment.speechRecognition.cancel() }
                    app.overlay = nil
                }
            )
        case .speechUnavailable(let message):
            Alert(
                title: Text("语音识别不可用"),
                message: Text(message),
                dismissButton: .default(Text("知道了")) { app.overlay = nil }
            )
        case .abandonTraining:
            Alert(
                title: Text("退出这次训练？"),
                message: Text("已确认字幕保存在本机。放弃后将不会生成本次复盘。"),
                primaryButton: .destructive(Text("放弃训练")) {
                    Task { await app.activeTraining?.abandon() }
                    app.routes.removeAll()
                    app.overlay = nil
                },
                secondaryButton: .cancel(Text("继续训练")) { app.overlay = nil }
            )
        case .interrupted(let canResume):
            Alert(
                title: Text("录音被中断"),
                message: Text(canResume ? "可以继续录音，已确认字幕不会丢失。" : "可以结束并保存已确认字幕。"),
                dismissButton: .default(Text("知道了")) { app.overlay = nil }
            )
        case .restoreDraft(let id):
            Alert(
                title: Text("发现未完成的训练"),
                message: Text("已经确认的字幕保存在本机。你可以继续录制新片段。"),
                primaryButton: .default(Text("继续训练")) { app.resumeTraining(sessionID: id) },
                secondaryButton: .cancel(Text("暂不处理")) { app.overlay = nil }
            )
        case .confirmDelete(let id):
            Alert(
                title: Text("删除这条训练？"),
                message: Text("逐字稿、标记和报告会一并删除，且无法恢复。"),
                primaryButton: .destructive(Text("删除")) { app.delete(sessionID: id) },
                secondaryButton: .cancel()
            )
        case .confirmDeleteAll:
            Alert(
                title: Text("清除全部本地数据？"),
                message: Text("所有训练、逐字稿与报告都会永久删除。"),
                primaryButton: .destructive(Text("全部清除")) { app.deleteAll() },
                secondaryButton: .cancel()
            )
        case .aiConsent:
            Alert(
                title: Text("开启 AI 前请确认"),
                message: Text("为生成提示和报告，会将训练主题、确认逐字稿及本地问题摘要发送到 Expression Trainer 后端。不会上传原始录音，也不会在 App 中保存供应商密钥。"),
                primaryButton: .default(Text("同意并开启")) { app.acceptAIConsent() },
                secondaryButton: .cancel(Text("保持关闭")) {
                    app.realtimeAIEnabled = false
                    app.overlay = nil
                }
            )
        }
    }
}
