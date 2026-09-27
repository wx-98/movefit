import SwiftUI

struct WorkoutSessionView: View {
    @EnvironmentObject private var model: AppModel
    let type: WorkoutType
    @State private var elapsed = 0
    @State private var running = false
    @State private var timer: Timer?

    var body: some View {
        VStack(spacing: 28) {
            Image(systemName: type.symbol)
                .font(.system(size: 64))
                .foregroundColor(AppColor.primary)
            Text(type.rawValue).font(.largeTitle.bold())
            Text(timeText)
                .font(.system(size: 52, weight: .semibold, design: .rounded))
                .monospacedDigit()
            if let distance = model.workoutDistance {
                Text(AppFormat.distance(distance))
                    .font(.title2.bold())
                    .foregroundColor(AppColor.exercise)
            }
            Text(locationMessage)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            HStack {
                Button(running ? "暂停" : (elapsed == 0 ? "开始" : "继续")) {
                    toggle()
                }
                .buttonStyle(.borderedProminent)
                .tint(AppColor.exercise)

                Button("结束") {
                    Task { await finish() }
                }
                .buttonStyle(.bordered)
                .disabled(elapsed == 0)
            }
        }
        .padding()
        .navigationTitle("运动中")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { model.prepare(type) }
        .onDisappear {
            timer?.invalidate()
            running = false
            model.abandonSession()
        }
    }

    private var timeText: String {
        String(format: "%02d:%02d", elapsed / 60, elapsed % 60)
    }

    private var locationMessage: String {
        switch model.locationAuthorizationStatus {
        case .denied, .restricted:
            return "定位权限不可用，本次仍会保存真实运动时长，但不会生成路线与距离。"
        default:
            return "户外运动会在获得使用期间定位权限后记录真实路线与距离。"
        }
    }

    private func toggle() {
        if running {
            timer?.invalidate()
            running = false
            model.pauseSession(elapsed: TimeInterval(elapsed))
            return
        }

        let didStart = elapsed == 0
            ? model.startSession(type: type)
            : model.resumeSession()
        guard didStart else { return }
        running = true
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            Task { @MainActor in
                elapsed += 1
                model.refreshWorkoutLocation()
            }
        }
    }

    private func finish() async {
        timer?.invalidate()
        running = false
        _ = await model.completeSession(type: type, duration: TimeInterval(elapsed))
    }
}
