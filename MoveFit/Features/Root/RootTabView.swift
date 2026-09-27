import SwiftUI

struct RootTabView: View {
    @EnvironmentObject private var model: AppModel
    let registrationViewModelFactory: RegistrationViewModelFactory

    var body: some View {
        ZStack {
            TabView {
                HomeView().tabItem { Label("首页", systemImage: "house.fill") }
                ChallengesView().tabItem { Label("挑战", systemImage: "trophy.fill") }
                WorkoutsView().tabItem { Label("运动", systemImage: "dumbbell.fill") }
                HistoryView().tabItem { Label("历史", systemImage: "chart.bar.fill") }
                ProfileView(registrationViewModelFactory: registrationViewModelFactory)
                    .tabItem { Label("我的", systemImage: "person.fill") }
            }
            if model.isLoading {
                LoadingStateView()
                    .background(.ultraThinMaterial)
            }
        }
        .accentColor(AppColor.primary)
        .task { await model.load() }
        .alert("提示", isPresented: Binding(get: { model.alertMessage != nil }, set: { if !$0 { model.alertMessage = nil } })) { Button("知道了") {} } message: { Text(model.alertMessage ?? "") }
    }
}
