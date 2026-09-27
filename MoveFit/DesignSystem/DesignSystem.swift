import SwiftUI

enum AppColor {
    static let pageBackground = Color(.systemGroupedBackground)
    static let primary = Color(red: 0.73, green: 0, blue: 0.2)
    static let move = Color(red: 0.95, green: 0.02, blue: 0.25)
    static let exercise = Color(red: 0.13, green: 0.78, blue: 0.28)
    static let stand = Color(red: 0.12, green: 0.66, blue: 0.95)
    static let sleep = Color(red: 0.35, green: 0.27, blue: 0.88)
    static let challenge = Color(red: 0.58, green: 0.25, blue: 0.87)
    static let orange = Color(red: 0.96, green: 0.48, blue: 0.12)
    static let teal = Color(red: 0.03, green: 0.62, blue: 0.57)
    static let surface = Color(.secondarySystemGroupedBackground)
    static let raisedSurface = Color(.tertiarySystemGroupedBackground)
    static let separator = Color(.separator)

    static func tint(_ tint: ChallengeTint) -> Color {
        switch tint {
        case .rose: return move
        case .blue: return stand
        case .green: return exercise
        case .purple: return challenge
        case .orange: return orange
        }
    }
}

enum AppSpacing {
    static let tiny: CGFloat = 4
    static let small: CGFloat = 8
    static let medium: CGFloat = 16
    static let large: CGFloat = 24
    static let section: CGFloat = 32
}

enum AppRadius {
    static let tiny: CGFloat = 8
    static let small: CGFloat = 12
    static let card: CGFloat = 20
    static let hero: CGFloat = 28
}

struct AppCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(AppSpacing.medium)
            .background(AppColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                    .stroke(Color.primary.opacity(0.035), lineWidth: 1)
            )
    }
}

struct GradientCard<Content: View>: View {
    let colors: [Color]
    let content: Content

    init(colors: [Color], @ViewBuilder content: () -> Content) {
        self.colors = colors
        self.content = content()
    }

    var body: some View {
        content
            .padding(AppSpacing.large)
            .background(
                LinearGradient(
                    colors: colors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.hero, style: .continuous))
            .shadow(color: (colors.first ?? .clear).opacity(0.2), radius: 14, y: 8)
    }
}

struct MetricView: View {
    let title: String
    let value: String
    let detail: String
    var alignment = HorizontalAlignment.leading

    var body: some View {
        VStack(alignment: alignment, spacing: 6) {
            Text(title).font(.caption).foregroundColor(.secondary)
            Text(value).font(.title2.bold()).minimumScaleFactor(0.7)
            Text(detail).font(.caption).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: alignment == .center ? .center : .leading)
    }
}

struct ActivityRingMetric: Identifiable {
    let id: String
    let title: String
    let displayValue: String
    let goalText: String
    let progress: Double?
    let color: Color
}

struct ActivityRingsView: View {
    let metrics: [ActivityRingMetric]

    var body: some View {
        ZStack {
            ForEach(Array(metrics.prefix(3).enumerated()), id: \.element.id) { index, metric in
                Circle()
                    .stroke(metric.color.opacity(0.16), lineWidth: 14)
                    .padding(CGFloat(index * 23))
                if let progress = metric.progress {
                    Circle()
                        .trim(from: 0, to: min(max(progress, 0.015), 1))
                        .stroke(
                            AngularGradient(
                                colors: [metric.color.opacity(0.75), metric.color],
                                center: .center
                            ),
                            style: StrokeStyle(lineWidth: 14, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .padding(CGFloat(index * 23))
                        .shadow(color: metric.color.opacity(0.25), radius: 3)
                }
            }
            VStack(spacing: AppSpacing.tiny) {
                Image(systemName: "figure.run.circle.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(AppColor.move, AppColor.surface)
                Text("MOVEFIT").font(.caption2.bold()).foregroundColor(.secondary)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            metrics.map { "\($0.title) \($0.displayValue)，目标 \($0.goalText)" }.joined(separator: "；")
        )
    }
}

struct TrendBarChart: View {
    let points: [HealthTrendPoint]
    let color: Color
    var showsLabels = true

    var body: some View {
        GeometryReader { proxy in
            let values = points.compactMap(\.value)
            let maximum = max(values.max() ?? 0, 1)
            HStack(alignment: .bottom, spacing: points.count > 31 ? 1 : 5) {
                ForEach(Array(points.enumerated()), id: \.element.id) { index, point in
                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(point.value == nil ? Color.secondary.opacity(0.12) : color)
                            .frame(
                                height: point.value.map {
                                    max(3, CGFloat($0 / maximum) * (proxy.size.height - (showsLabels ? 22 : 0)))
                                } ?? 2
                            )
                        if showsLabels && shouldShowLabel(at: index) {
                            Text(point.date, format: .dateTime.weekday(.narrow))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        } else if showsLabels {
                            Text(" ").font(.caption2)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("健康趋势柱状图，共 \(points.compactMap(\.value).count) 个有效数据点")
    }

    private func shouldShowLabel(at index: Int) -> Bool {
        points.count <= 7 || index == 0 || index == points.count - 1
    }
}

struct MiniBarChart: View {
    let values: [Double]

    var body: some View {
        HStack(alignment: .bottom, spacing: 10) {
            ForEach(Array(values.enumerated()), id: \.offset) { _, value in
                Capsule()
                    .fill(AppColor.exercise)
                    .frame(maxWidth: .infinity)
                    .frame(height: CGFloat(max(value, 0.05) * 110))
            }
        }
        .frame(height: 120)
    }
}

enum AppFormat {
    static func distance(_ value: Measurement<UnitLength>?) -> String {
        guard let value else { return "—" }
        return String(format: "%.1f 公里", value.converted(to: .kilometers).value)
    }

    static func duration(_ seconds: TimeInterval) -> String {
        let totalMinutes = Int(seconds) / 60
        if totalMinutes >= 60 {
            return "\(totalMinutes / 60) 小时 \(totalMinutes % 60) 分钟"
        }
        return "\(totalMinutes) 分钟"
    }

    static func decimal(_ value: Double?, digits: Int = 0) -> String {
        guard let value else { return "—" }
        return String(format: "%.*f", digits, value)
    }
}
