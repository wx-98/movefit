import SwiftUI

struct ECGWaveformChart: View {
    let waveform: ECGWaveform

    var body: some View {
        GeometryReader { proxy in
            let values = waveform.samplesInMicrovolts
            let range = max((values.max() ?? 1) - (values.min() ?? 0), 1)
            Path { path in
                for (index, value) in values.enumerated() {
                    let x = proxy.size.width * CGFloat(index) / CGFloat(max(values.count - 1, 1))
                    let y = proxy.size.height * CGFloat(1 - (value - (values.min() ?? 0)) / range)
                    index == 0 ? path.move(to: CGPoint(x: x, y: y)) : path.addLine(to: CGPoint(x: x, y: y))
                }
            }
            .stroke(AppColor.move, style: StrokeStyle(lineWidth: 1.5, lineJoin: .round))
            .background(AppColor.move.opacity(0.06))
        }
        .accessibilityLabel("心电图历史波形，仅供查看，不构成诊断")
    }
}
