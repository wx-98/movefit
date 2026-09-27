import SwiftUI

struct HealthDevicesView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Form {
            Section("Apple 健康") {
                HStack {
                    Label("数据状态", systemImage: "heart.text.square.fill")
                    Spacer()
                    Text(statusText).foregroundColor(.secondary)
                }
                Button("连接或刷新 Apple 健康") {
                    Task { await model.connectHealth() }
                }
                Text("读取步数、距离、活动能量、锻炼分钟、站立小时、心率、睡眠和运动样本。系统按数据类型管理授权。")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
            Section("设备") {
                Label("iPhone 健康数据库", systemImage: "iphone")
                Label("Apple Watch（通过健康同步）", systemImage: "applewatch")
                Text("MoveFit 不直接连接手表；手表记录同步到 Apple 健康后再由应用读取。来源设备的具体显示受 HealthKit 样本可用性限制。")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
            Section("定位") {
                Label("户外运动期间的前台定位", systemImage: "location.fill")
                Text("仅跑步、步行和骑行会在活动会话期间请求定位；当前不支持后台持续记录。")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("健康与设备")
    }

    private var statusText: String {
        switch model.healthStatus {
        case .notLoaded: return "未加载"
        case .unavailable: return "设备不支持"
        case .noData: return "暂无可读数据"
        case .available: return "已读取"
        case .failed: return "读取失败"
        }
    }
}
