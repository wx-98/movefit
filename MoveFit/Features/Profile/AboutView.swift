import SwiftUI

struct AboutView: View {
    var body: some View {
        List {
            Section {
                VStack(spacing: AppSpacing.medium) {
                    Image("MoveFitLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 96, height: 96)
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
                    Text("MoveFit").font(.title.bold())
                    Text(versionText).font(.caption).foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical)
            }
            Section("技术与数据") {
                Label("SwiftUI · iOS 15+", systemImage: "swift")
                Label("HealthKit · Core Data · Core Location", systemImage: "heart.text.square")
                Label("无第三方运行时依赖", systemImage: "shippingbox")
            }
            Section("内容声明") {
                Text("训练与睡眠评分仅作一般健康和运动信息展示，不构成医疗诊断。动作基础数据参考可在公共领域使用的 exercises.json 结构，但发布内容经过本地中文化和安全说明补充。")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("关于 MoveFit")
    }

    private var versionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
        return "版本 \(version)（\(build)）"
    }
}
