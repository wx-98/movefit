import SwiftUI

struct HealthMetricsFormView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var nickname = ""
    @State private var height = ""
    @State private var weight = ""
    @State private var bodyFat = ""
    @State private var validationMessage: String?

    var body: some View {
        Form {
            Section(model.localizer.text("个人资料")) {
                TextField(model.localizer.text("昵称"), text: $nickname)
                TextField(model.localizer.text("身高（厘米）"), text: $height).keyboardType(.decimalPad)
                TextField(model.localizer.text("体重（千克）"), text: $weight).keyboardType(.decimalPad)
                TextField(model.localizer.text("体脂率（%）"), text: $bodyFat).keyboardType(.decimalPad)
            }
            Section {
                Text(model.localizer.text("这些数据仅保存在本机 Core Data 中，不会上传到服务端。"))
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
            Section {
                Button(model.localizer.text("保存健康指标")) { save() }
                    .accessibilityIdentifier("saveHealthMetricsButton")
            }
        }
        .navigationTitle(model.localizer.text("健康指标"))
        .onAppear(perform: populate)
        .alert(model.localizer.text("无法保存"), isPresented: Binding(
            get: { validationMessage != nil },
            set: { if !$0 { validationMessage = nil } }
        )) {
            Button("知道了") {}
        } message: {
            Text(validationMessage ?? "")
        }
    }

    private func populate() {
        guard let profile = model.profile else { return }
        nickname = profile.nickname
        height = String(format: "%.0f", profile.height.converted(to: .centimeters).value)
        weight = String(format: "%.1f", profile.weight.converted(to: .kilograms).value)
        bodyFat = String(format: "%.1f", profile.bodyFatPercentage)
    }

    private func save() {
        guard let heightValue = Double(height),
              let weightValue = Double(weight),
              let bodyFatValue = Double(bodyFat) else {
            validationMessage = model.localizer.text("请使用数字填写身高、体重和体脂率。")
            return
        }
        Task {
            if await model.saveProfile(
                nickname: nickname,
                heightCentimeters: heightValue,
                weightKilograms: weightValue,
                bodyFatPercentage: bodyFatValue
            ) {
                dismiss()
            }
        }
    }
}
