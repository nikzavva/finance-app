import SwiftUI
import SwiftData

@main
struct FinanceApp: App {
    let storageManager = StorageManager.shared
    
    var body: some Scene {
        WindowGroup {
            AppContentView(storageManager: storageManager)
        }
        .modelContainer(storageManager.swiftDataContainer)
    }
}

private struct AppContentView: View {
    @StateObject private var viewModel: AppLaunchViewModel

    init(storageManager: StorageManager) {
        _viewModel = StateObject(
            wrappedValue: AppLaunchViewModel(storageManager: storageManager)
        )
    }

    var body: some View {
        Group {
            if !viewModel.isSplashFinished || !viewModel.isReady {
                SplashAnimationView {
                    viewModel.splashDidFinish()
                }
                .background(Color(uiColor: .systemBackground))
                .ignoresSafeArea()
            } else {
                FinanceAppView()
                    .networkErrorAlert()
            }
        }
        .task {
            await viewModel.prepare()
        }
        .alert("Ошибка миграции", isPresented: $viewModel.showMigrationError) {
            Button("ОК", role: .cancel) {}
        } message: {
            Text(viewModel.migrationErrorMessage)
        }
    }
}
