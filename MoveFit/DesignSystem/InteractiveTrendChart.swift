import SwiftUI

struct InteractiveTrendChart: View {
    let buckets: [HistoryTrendBucket]
    let color: Color
    let average: Double?
    let today: Date
    let calendar: Calendar
    @Binding var selectedBucketID: Date?

    var body: some View {
        GeometryReader { proxy in
            let maximum = max(buckets.compactMap(\.value).max() ?? 0, average ?? 0, 1)
            let chartHeight = max(proxy.size.height - 34, 1)
            VStack(spacing: AppSpacing.tiny) {
                HStack(alignment: .top, spacing: AppSpacing.tiny) {
                    axisLabel("\(Int(maximum.rounded()).formatted())")
                    ZStack(alignment: .bottom) {
                        gridLines
                        if let average {
                            averageLine(value: average, maximum: maximum, height: chartHeight)
                        }
                        HStack(alignment: .bottom, spacing: max(2, 16 / CGFloat(max(buckets.count, 1)))) {
                            ForEach(buckets) { bucket in
                                bar(
                                    bucket: bucket,
                                    maximum: maximum,
                                    height: chartHeight
                                )
                            }
                        }
                    }
                    .frame(height: chartHeight)
                }
                HStack(spacing: AppSpacing.tiny) {
                    axisLabel("0")
                    HStack(spacing: max(2, 16 / CGFloat(max(buckets.count, 1)))) {
                        ForEach(Array(buckets.enumerated()), id: \.element.id) { index, bucket in
                            Text(shouldShowLabel(index: index) ? bucket.label : " ")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("可交互步数趋势图")
    }

    private var gridLines: some View {
        VStack(spacing: 0) {
            Divider().opacity(0.32)
            Spacer()
            Divider().opacity(0.2)
            Spacer()
            Divider().opacity(0.32)
        }
    }

    private func bar(bucket: HistoryTrendBucket, maximum: Double, height: CGFloat) -> some View {
        let isSelected = selectedBucketID == bucket.id
        let isToday = calendar.isDate(today, inSameDayAs: bucket.startDate)
            || (today >= bucket.startDate && today < bucket.endDate)
        let value = bucket.value ?? 0
        return Button {
            selectedBucketID = bucket.id
        } label: {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(bucket.value == nil ? Color.secondary.opacity(0.12) : color.opacity(isSelected ? 1 : 0.72))
                .overlay(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .stroke(isToday ? AppColor.move : .clear, lineWidth: isToday ? 2 : 0)
                )
                .frame(height: bucket.value == nil ? 3 : max(5, CGFloat(value / maximum) * height))
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityText(for: bucket))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func averageLine(value: Double, maximum: Double, height: CGFloat) -> some View {
        let offset = max(0, min(height, height - CGFloat(value / maximum) * height))
        return VStack {
            Capsule()
                .fill(Color.secondary.opacity(0.8))
                .frame(height: 1)
                .overlay(alignment: .trailing) {
                    Text("平均")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.trailing, 2)
                }
            Spacer()
        }
        .padding(.top, offset)
        .allowsHitTesting(false)
    }

    private func axisLabel(_ value: String) -> some View {
        Text(value)
            .font(.caption2)
            .foregroundColor(.secondary)
            .frame(width: 34, alignment: .trailing)
    }

    private func shouldShowLabel(index: Int) -> Bool {
        buckets.count <= 7 || index == 0 || index == buckets.count - 1 || index == buckets.count / 2
    }

    private func accessibilityText(for bucket: HistoryTrendBucket) -> String {
        let date = bucket.startDate.formatted(.dateTime.year().month().day())
        let value = bucket.value.map { Int($0.rounded()).formatted() } ?? "暂无"
        return "\(date)，\(value) 步"
    }
}
