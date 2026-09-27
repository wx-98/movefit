import SwiftUI

struct HealthSectionHeader: View {
    let title: String
    var detail: String?
    var symbol: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: AppSpacing.small) {
            if let symbol {
                Image(systemName: symbol)
                    .font(.subheadline.bold())
                    .foregroundColor(AppColor.primary)
            }
            Text(title).font(.title3.bold())
            Spacer()
            if let detail {
                Text(detail)
                    .font(.caption.weight(.medium))
                    .foregroundColor(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

struct HealthMetricCard: View {
    let title: String
    let value: String
    let detail: String
    let symbol: String
    let tint: Color

    var body: some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppSpacing.small) {
                HStack {
                    Image(systemName: symbol)
                        .font(.subheadline.bold())
                        .foregroundColor(tint)
                        .frame(width: 30, height: 30)
                        .background(tint.opacity(0.12))
                        .clipShape(Circle())
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                }
                Text(title).font(.caption.weight(.medium)).foregroundColor(.secondary)
                Text(value)
                    .font(.title2.bold().monospacedDigit())
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.62)
                Text(detail).font(.caption2).foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct HealthStatusPill: View {
    let title: String
    let tint: Color

    var body: some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundColor(tint)
            .padding(.horizontal, AppSpacing.small)
            .padding(.vertical, AppSpacing.tiny)
            .background(tint.opacity(0.12))
            .clipShape(Capsule())
    }
}

struct HealthSettingsRow<Destination: View>: View {
    let title: String
    let detail: String?
    let symbol: String
    let tint: Color
    let destination: Destination

    init(
        title: String,
        detail: String? = nil,
        symbol: String,
        tint: Color = AppColor.primary,
        @ViewBuilder destination: () -> Destination
    ) {
        self.title = title
        self.detail = detail
        self.symbol = symbol
        self.tint = tint
        self.destination = destination()
    }

    var body: some View {
        NavigationLink(destination: destination) {
            HStack(spacing: AppSpacing.medium) {
                Image(systemName: symbol)
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                    .frame(width: 30, height: 30)
                    .background(tint)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.tiny, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).foregroundColor(.primary)
                    if let detail {
                        Text(detail).font(.caption).foregroundColor(.secondary)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundColor(AppColor.separator)
            }
            .padding(.vertical, AppSpacing.small)
        }
        .buttonStyle(.plain)
    }
}
