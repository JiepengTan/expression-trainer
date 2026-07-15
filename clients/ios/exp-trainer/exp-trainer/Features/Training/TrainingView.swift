import SwiftUI

struct TrainingView: View {
    let sessionID: UUID
    @Environment(AppModel.self) private var app

    var body: some View {
        Group {
            if let controller = app.activeTraining, controller.sessionID == sessionID {
                TrainingLiveContent(controller: controller)
            } else {
                ContentUnavailableView(
                    "训练状态不可用",
                    systemImage: "mic.slash",
                    description: Text("返回首页后可以恢复未完成的训练。")
                )
            }
        }
        .expressionScreen()
        .navigationBarBackButtonHidden(true)
        .accessibilityIdentifier("screen.training")
    }
}

private struct TrainingLiveContent: View {
    @Bindable var controller: TrainingSessionController
    @Environment(AppModel.self) private var app
    @State private var showingEndConfirmation = false
    @State private var showingExitConfirmation = false
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        CoachBanner(
                            message: controller.currentHint,
                            isAI: controller.realtimeAIEnabled
                        )
                        statusStrip
                        transcript
                        Color.clear.frame(height: 1).id("bottom")
                    }
                    .padding(ETSpacing.lg)
                }
                .onChange(of: controller.confirmedSegments.count) { _, _ in
                    withAnimation { proxy.scrollTo("bottom", anchor: .bottom) }
                }
            }
            controls
                .padding(.horizontal, ETSpacing.lg)
                .padding(.vertical, ETSpacing.md)
                .background(ETColor.background.opacity(0.96))
        }
        .task { await controller.start() }
        .onChange(of: controller.readyForReview) { _, ready in
            if ready { app.reviewTranscript(sessionID: controller.sessionID) }
        }
        .alert("结束本次训练？", isPresented: $showingEndConfirmation) {
            Button("继续训练", role: .cancel) {}
            Button("结束并校正") { Task { await controller.finish() } }
        } message: {
            Text("系统会先等待尾句确认，再进入逐字稿校正。")
        }
        .confirmationDialog(
            "退出这次训练？",
            isPresented: $showingExitConfirmation,
            titleVisibility: .visible
        ) {
            if !controller.confirmedSegments.isEmpty {
                Button("保存当前内容并结束") { Task { await controller.finish() } }
            }
            Button("放弃训练", role: .destructive) {
                Task {
                    await controller.abandon()
                    app.routes.removeAll()
                    app.reload()
                }
            }
            Button("继续训练", role: .cancel) {}
        } message: {
            Text(controller.confirmedSegments.isEmpty ? "还没有有效字幕。" : "已确认字幕已经保存在本机。")
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { showingExitConfirmation = true } label: {
                    Image(systemName: "xmark")
                }
                .accessibilityLabel("退出训练")
            }
        }
        .alert(
            "录音被中断",
            isPresented: Binding(
                get: { controller.interruptionCanResume != nil },
                set: { if !$0 { controller.interruptionCanResume = nil } }
            )
        ) {
            if controller.interruptionCanResume == true {
                Button("继续录音") { controller.resumeAfterInterruption() }
            }
            Button("结束并保存") { Task { await controller.finishAfterInterruption() } }
        } message: {
            Text("已经确认的字幕已保存在本机。")
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(controller.topic.isEmpty ? "自由表达" : controller.topic)
                        .font(.headline)
                    Text(controller.goal.title)
                        .font(.caption)
                        .foregroundStyle(ETColor.orange)
                }
                Spacer()
                Label(stateTitle, systemImage: stateSymbol)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(stateColor)
            }
            VoiceRibbon(height: 38, active: controller.lifecycle.state == .recording)
        }
        .padding(.horizontal, ETSpacing.lg)
        .padding(.top, ETSpacing.sm)
    }

    private var statusStrip: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 7) {
                    Label(durationText, systemImage: "timer").monospacedDigit()
                    Label("口头禅 \(controller.issues.filter { $0.category == .filler }.count)", systemImage: "waveform.path")
                    Label("犹豫词 \(controller.issues.filter { $0.category == .hesitation }.count)", systemImage: "ellipsis")
                }
            } else {
                HStack {
                    Label(durationText, systemImage: "timer").monospacedDigit()
                    Spacer()
                    Label("口头禅 \(controller.issues.filter { $0.category == .filler }.count)", systemImage: "waveform.path")
                    Spacer()
                    Label("犹豫词 \(controller.issues.filter { $0.category == .hesitation }.count)", systemImage: "ellipsis")
                }
            }
        }
        .font(.caption)
        .foregroundStyle(ETColor.secondaryText)
    }

    private var transcript: some View {
        VStack(alignment: .leading, spacing: 12) {
            if controller.confirmedSegments.isEmpty && controller.partialTranscript.isEmpty {
                Text(controller.isPreparing ? "正在准备语音资源…" : "开始说话后，字幕会出现在这里。")
                    .foregroundStyle(ETColor.secondaryText)
                    .frame(maxWidth: .infinity, minHeight: 220, alignment: .center)
            }
            ForEach(Array(controller.confirmedSegments.enumerated()), id: \.offset) { _, text in
                Text(text)
                    .font(.title3)
                    .lineSpacing(7)
                    .padding(15)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(ETColor.surface, in: RoundedRectangle(cornerRadius: 13))
            }
            if !controller.partialTranscript.isEmpty {
                Text(controller.partialTranscript)
                    .font(.title3)
                    .foregroundStyle(ETColor.secondaryText)
                    .italic()
                    .padding(15)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(ETColor.surface.opacity(0.55), in: RoundedRectangle(cornerRadius: 13))
                    .accessibilityLabel("识别中：\(controller.partialTranscript)")
            }
            if let error = controller.errorMessage {
                Label(error, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(ETColor.amber)
                    .expressionCard(padding: 12)
            }
        }
    }

    private var controls: some View {
        HStack(spacing: 24) {
            Button {
                controller.lifecycle.state == .paused ? controller.resume() : controller.pause()
            } label: {
                controlCircle(
                    symbol: controller.lifecycle.state == .paused ? "play.fill" : "pause.fill",
                    label: controller.lifecycle.state == .paused ? "继续" : "暂停",
                    tint: ETColor.surfaceElevated
                )
            }
            .disabled(controller.lifecycle.state != .recording && controller.lifecycle.state != .paused)

            Button { showingEndConfirmation = true } label: {
                controlCircle(symbol: "stop.fill", label: "结束", tint: ETColor.orange)
            }
            .disabled(controller.lifecycle.state != .recording && controller.lifecycle.state != .paused)
        }
        .frame(maxWidth: .infinity)
    }

    private func controlCircle(symbol: String, label: String, tint: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.title2)
                .frame(width: 68, height: 68)
                .background(tint, in: Circle())
                .foregroundStyle(.white)
            Text(label).font(.caption).foregroundStyle(ETColor.secondaryText)
        }
    }

    private var durationText: String {
        let seconds = Int(controller.elapsed)
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }

    private var stateTitle: String {
        switch controller.lifecycle.state {
        case .preparing: "准备中"
        case .recording: "录音中"
        case .paused: "已暂停"
        case .finishing: "正在收尾"
        case .interrupted: "已中断"
        default: "训练"
        }
    }

    private var stateSymbol: String {
        controller.lifecycle.state == .paused ? "pause.circle.fill" : "record.circle"
    }

    private var stateColor: Color {
        controller.lifecycle.state == .paused ? ETColor.amber : ETColor.orange
    }
}
