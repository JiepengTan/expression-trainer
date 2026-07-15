import SwiftUI

struct OnboardingView: View {
    @Environment(AppModel.self) private var app
    @State private var isPreparing = false
    @State private var preparationMessage = ""

    var body: some View {
        @Bindable var app = app
        VStack(spacing: 0) {
            TabView(selection: $app.onboardingPage) {
                onboardingPage(
                    eyebrow: "EXPRESSION TRAINER",
                    title: "把话说清楚，\n从一次练习开始",
                    message: "实时逐字稿与客观标记，帮你更快发现口头禅、犹豫词和笼统表达。",
                    symbol: "waveform.and.mic",
                    tint: ETColor.orange
                ).tag(0)
                onboardingPage(
                    eyebrow: "隐私优先",
                    title: "默认只在本机\n完成训练闭环",
                    message: "无需登录，不保存原始录音。逐字稿与历史默认留在设备；AI 由你明确开启。",
                    symbol: "lock.shield",
                    tint: ETColor.teal
                ).tag(1)
                onboardingPage(
                    eyebrow: "开始前准备",
                    title: "准备麦克风与\n普通话识别资源",
                    message: "系统会请求麦克风和语音识别权限，并下载 Apple 语言资源。只需准备一次。",
                    symbol: "arrow.down.circle",
                    tint: ETColor.amber
                ).tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            VStack(spacing: 18) {
                HStack(spacing: 8) {
                    ForEach(0..<3) { index in
                        Capsule()
                            .fill(index == app.onboardingPage ? ETColor.orange : ETColor.border)
                            .frame(width: index == app.onboardingPage ? 26 : 8, height: 8)
                    }
                }
                if !preparationMessage.isEmpty {
                    Text(preparationMessage)
                        .font(.caption)
                        .foregroundStyle(ETColor.secondaryText)
                        .multilineTextAlignment(.center)
                }
                PrimaryActionButton(
                    title: app.onboardingPage == 2 ? (isPreparing ? "正在准备…" : "准备并开始") : "继续",
                    symbol: app.onboardingPage == 2 ? "mic.fill" : "arrow.right",
                    isEnabled: !isPreparing
                ) {
                    if app.onboardingPage < 2 {
                        withAnimation { app.onboardingPage += 1 }
                    } else {
                        Task { await prepareAndComplete() }
                    }
                }
                if app.onboardingPage == 2 {
                    Button("稍后准备") { app.completeOnboarding() }
                        .foregroundStyle(ETColor.secondaryText)
                        .font(.subheadline)
                }
            }
            .padding(.horizontal, ETSpacing.lg)
            .padding(.bottom, ETSpacing.lg)
        }
        .expressionScreen()
        .accessibilityIdentifier("screen.onboarding.\(app.onboardingPage + 1)")
    }

    private func onboardingPage(
        eyebrow: String,
        title: String,
        message: String,
        symbol: String,
        tint: Color
    ) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                ZStack {
                    Circle().fill(tint.opacity(0.13)).frame(width: 112, height: 112)
                    Image(systemName: symbol)
                        .font(.system(size: 44, weight: .medium))
                        .foregroundStyle(tint)
                }
                VoiceRibbon(height: 60, active: false)
                Text(eyebrow)
                    .font(.caption.weight(.semibold))
                    .tracking(2)
                    .foregroundStyle(tint)
                Text(title)
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .fixedSize(horizontal: false, vertical: true)
                Text(message)
                    .font(.body)
                    .foregroundStyle(ETColor.secondaryText)
                    .lineSpacing(6)
            }
            .padding(.vertical, ETSpacing.lg)
        }
        .scrollIndicators(.hidden)
        .padding(.horizontal, ETSpacing.lg)
    }

    private func prepareAndComplete() async {
        isPreparing = true
        preparationMessage = "正在检查权限…"
        for kind in PermissionKind.allCases {
            let state = app.environment.permissions.status(for: kind)
            let result = state == .notDetermined
                ? await app.environment.permissions.request(kind)
                : state
            guard result == .granted else {
                preparationMessage = "权限未开启，可稍后在设置中继续。"
                isPreparing = false
                app.overlay = .permissionDenied
                return
            }
        }
        do {
            preparationMessage = "正在准备普通话识别资源…"
            app.overlay = .speechPreparing
            _ = try await app.environment.speechRecognition.prepare(locale: Locale(identifier: "zh-CN"))
            app.overlay = nil
            preparationMessage = "准备完成"
            app.completeOnboarding()
        } catch {
            app.overlay = nil
            preparationMessage = error.localizedDescription
        }
        isPreparing = false
    }
}
