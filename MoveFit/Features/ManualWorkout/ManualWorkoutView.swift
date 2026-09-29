import SwiftUI

struct ManualWorkoutView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var type = WorkoutType.running
    @State private var duration = 30
    @State private var distance = ""
    var body: some View { Form {
        Section(model.localizer.text("运动信息")) { Picker(model.localizer.text("类型"), selection: $type) { ForEach(WorkoutType.allCases) { Text(model.localizer.text($0.rawValue)).tag($0) } }; Stepper(model.localizer.formatted("manual.duration.stepper.format", duration), value: $duration, in: 1...600); TextField(model.localizer.text("距离（公里，可选）"), text: $distance).keyboardType(.decimalPad) }
        Section { Button(model.localizer.text("保存记录")) { Task { if await model.saveManual(type: type, durationMinutes: duration, distanceKilometers: Double(distance)) { dismiss() } } } }
    }.navigationTitle(model.localizer.text("手动添加")).accessibilityIdentifier("manualWorkoutForm") }
}
