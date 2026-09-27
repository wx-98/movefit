import SwiftUI

struct ManualWorkoutView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var type = WorkoutType.running
    @State private var duration = 30
    @State private var distance = ""
    var body: some View { Form {
        Section("运动信息") { Picker("类型", selection: $type) { ForEach(WorkoutType.allCases) { Text($0.rawValue).tag($0) } }; Stepper("时长：\(duration) 分钟", value: $duration, in: 1...600); TextField("距离（公里，可选）", text: $distance).keyboardType(.decimalPad) }
        Section { Button("保存记录") { Task { if await model.saveManual(type: type, durationMinutes: duration, distanceKilometers: Double(distance)) { dismiss() } } } }
    }.navigationTitle("手动添加").accessibilityIdentifier("manualWorkoutForm") }
}
