import SwiftUI

struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.large) {
                Text("MoveFit 隐私政策").font(.largeTitle.bold())
                Text("更新日期：2026 年 8 月 8 日").font(.caption).foregroundColor(.secondary)
                policySection("数据处理原则", "MoveFit 以本机处理为默认方式，只读取实现用户主动使用功能所必需的数据，不出售个人信息，不投放基于健康数据的广告。")
                policySection("Apple 健康", "经用户授权后，应用读取活动、心率、睡眠与运动样本用于界面展示和本地规则计算。原始健康样本保留在 HealthKit；当前版本不会上传到 MoveFit 服务端。")
                policySection("位置与运动", "户外运动期间可读取前台位置，用于计算距离与绘制路线。完成的 MoveFit 运动及路线保存在本机 Core Data。应用不申请始终定位。")
                policySection("身体指标与偏好", "昵称、身高、体重、体脂、挑战参与、收藏、外观、语言和隐私遮挡偏好保存在本机。敏感凭据未来只能存入 Keychain。")
                policySection("账号与第三方", "邮箱或手机号密码认证会向主业务后端发送账号标识，令牌仅存于 Keychain。Apple ID 与微信授权登录尚未在客户端启用，不会产生模拟绑定。Apple 健康数据受系统权限控制，客户端不会自动批量上传 HealthKit 样本。")
                policySection("保留与删除", "可重建缓存可在应用内清理。卸载应用会移除应用沙盒数据，但不会删除 HealthKit 中由其他应用或设备产生的样本。")
                policySection("安全与日志", "应用日志不得包含姓名、联系方式、精确位置、健康指标、访问令牌或完整服务响应。")
                policySection("联系我们", "当前版本通过项目仓库的问题渠道接收反馈。请勿在反馈中提交个人健康、账号或定位数据。")
                Text("本政策随应用发布，可离线查看。")
                    .font(.footnote.bold())
                    .foregroundColor(AppColor.primary)
            }
            .padding()
        }
        .navigationTitle("隐私政策")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func policySection(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.small) {
            Text(title).font(.title3.bold())
            Text(body).foregroundColor(.secondary)
        }
    }
}
