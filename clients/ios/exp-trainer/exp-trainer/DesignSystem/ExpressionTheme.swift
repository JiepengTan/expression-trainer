import SwiftUI

enum ETColor {
    static let background = Color(hex: 0x0D0F0E)
    static let surface = Color(hex: 0x1A1D1B)
    static let surfaceElevated = Color(hex: 0x232724)
    static let border = Color(hex: 0x363B37)
    static let orange = Color(hex: 0xE86F25)
    static let orangeBright = Color(hex: 0xFF7A1A)
    static let amber = Color(hex: 0xFFB547)
    static let teal = Color(hex: 0x27C2A0)
    static let ivory = Color(hex: 0xF4F0E8)
    static let secondaryText = Color(hex: 0xAAA79F)
    static let destructive = Color(hex: 0xFF5C5C)
}

enum ETSpacing {
    static let xs: CGFloat = 6
    static let sm: CGFloat = 10
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
}

extension Color {
    init(hex: UInt, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}

struct ScreenBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .foregroundStyle(ETColor.ivory)
            .background(ETColor.background.ignoresSafeArea())
    }
}

extension View {
    func expressionScreen() -> some View { modifier(ScreenBackground()) }

    func expressionCard(padding: CGFloat = ETSpacing.md) -> some View {
        self
            .padding(padding)
            .background(ETColor.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(ETColor.border, lineWidth: 1)
            }
    }
}

struct PrimaryActionButton: View {
    let title: String
    var symbol: String?
    var isEnabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                if let symbol { Image(systemName: symbol) }
                Text(title).font(.headline)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 54)
            .foregroundStyle(.white)
            .background(
                LinearGradient(
                    colors: [ETColor.orangeBright, ETColor.orange],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            .opacity(isEnabled ? 1 : 0.45)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }
}

struct VoiceRibbon: View {
    var height: CGFloat = 54
    var active = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: reduceMotion || !active ? 1 : 1 / 24)) { timeline in
            Canvas { context, size in
                let time = reduceMotion || !active ? 0 : timeline.date.timeIntervalSinceReferenceDate
                drawWave(in: &context, size: size, amplitude: 14, frequency: 2.3, phase: time * 1.6, color: ETColor.orange)
                drawWave(in: &context, size: size, amplitude: 10, frequency: 3.1, phase: -time * 1.2 + 1.7, color: ETColor.amber.opacity(0.8))
                drawWave(in: &context, size: size, amplitude: 7, frequency: 1.8, phase: time + 3.2, color: ETColor.teal.opacity(0.75))
            }
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }

    private func drawWave(
        in context: inout GraphicsContext,
        size: CGSize,
        amplitude: CGFloat,
        frequency: CGFloat,
        phase: Double,
        color: Color
    ) {
        var path = Path()
        let steps = max(2, Int(size.width / 4))
        for index in 0...steps {
            let x = size.width * CGFloat(index) / CGFloat(steps)
            let fade = max(0.08, 1 - x / size.width)
            let y = size.height / 2 + sin((x / size.width) * .pi * 2 * frequency + phase) * amplitude * fade
            index == 0 ? path.move(to: CGPoint(x: x, y: y)) : path.addLine(to: CGPoint(x: x, y: y))
        }
        context.stroke(path, with: .color(color), lineWidth: 2)
    }
}

struct GoalChip: View {
    let goal: TrainingGoal
    var selected = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: goal.symbol)
                    .foregroundStyle(selected ? .white : semanticColor)
                Text(goal.title)
                    .font(.body.weight(.semibold))
                Spacer()
                if selected { Image(systemName: "checkmark.circle.fill") }
            }
            .padding(18)
            .foregroundStyle(selected ? .white : ETColor.ivory)
            .background(selected ? ETColor.orange : ETColor.surface, in: RoundedRectangle(cornerRadius: 14))
            .overlay {
                RoundedRectangle(cornerRadius: 14).stroke(selected ? ETColor.orange : ETColor.border)
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var semanticColor: Color {
        switch goal {
        case .conclusionFirst: ETColor.orange
        case .fewerFillers: ETColor.amber
        case .decisiveLanguage: ETColor.amber
        case .clearerExpression: ETColor.teal
        }
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let detail: String?
    var tint = ETColor.amber

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.caption).foregroundStyle(ETColor.secondaryText)
            Text(value).font(.title2.monospacedDigit().weight(.semibold)).foregroundStyle(tint)
            if let detail { Text(detail).font(.caption2).foregroundStyle(ETColor.secondaryText) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .expressionCard(padding: 14)
        .accessibilityElement(children: .combine)
    }
}

struct CoachBanner: View {
    let message: String
    var isAI = false

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: isAI ? "sparkles" : "bubble.left.and.text.bubble.right")
                .foregroundStyle(isAI ? ETColor.teal : ETColor.orange)
            Text(message).font(.subheadline.weight(.medium))
            Spacer(minLength: 0)
            Text(isAI ? "AI" : "本地")
                .font(.caption2.bold())
                .padding(.horizontal, 7)
                .padding(.vertical, 4)
                .background((isAI ? ETColor.teal : ETColor.orange).opacity(0.16), in: Capsule())
        }
        .expressionCard(padding: 13)
        .accessibilityElement(children: .combine)
    }
}

struct SessionCard: View {
    let session: TrainingSessionRecord
    var action: () -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(session.topic.isEmpty ? "自由表达" : session.topic)
                            .font(.headline)
                            .foregroundStyle(ETColor.ivory)
                        Text(session.createdAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption)
                            .foregroundStyle(ETColor.secondaryText)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").foregroundStyle(ETColor.secondaryText)
                }
                Group {
                    if dynamicTypeSize.isAccessibilitySize {
                        VStack(alignment: .leading, spacing: 8) {
                            Label(session.goal.title, systemImage: session.goal.symbol)
                            Label("\(Int(session.effectiveDuration)) 秒", systemImage: "timer")
                            Label("问题 \(session.issueCount) 次", systemImage: "waveform.path")
                        }
                    } else {
                        HStack(spacing: 16) {
                            Label(session.goal.title, systemImage: session.goal.symbol)
                            Label("\(Int(session.effectiveDuration)) 秒", systemImage: "timer")
                            Label("\(session.issueCount)", systemImage: "waveform.path")
                        }
                    }
                }
                .font(.caption)
                .foregroundStyle(ETColor.secondaryText)
            }
            .expressionCard()
        }
        .buttonStyle(.plain)
    }
}
