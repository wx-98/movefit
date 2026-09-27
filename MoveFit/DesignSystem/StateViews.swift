import SwiftUI

struct PageContainer<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.large) {
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
    }
}

struct LoadingStateView: View {
    var body: some View {
        VStack(spacing: AppSpacing.medium) {
            ProgressView()
            Text("正在加载本地数据…")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 180)
        .accessibilityElement(children: .combine)
    }
}

struct EmptyStateView: View {
    let title: String
    let message: String
    let symbol: String

    var body: some View {
        VStack(spacing: AppSpacing.medium) {
            Image(systemName: symbol)
                .font(.largeTitle)
                .foregroundColor(AppColor.primary)
            Text(title).font(.headline)
            Text(message)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 180)
        .padding()
    }
}

struct ErrorStateView: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        VStack(spacing: AppSpacing.medium) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.largeTitle)
                .foregroundColor(AppColor.stand)
            Text("数据暂不可用").font(.headline)
            Text(message)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            Button("重试", action: retry)
                .buttonStyle(.borderedProminent)
                .tint(AppColor.primary)
        }
        .frame(maxWidth: .infinity, minHeight: 180)
        .padding()
    }
}
