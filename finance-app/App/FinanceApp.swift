import SwiftUI
import SwiftData

@main
struct FinanceApp: App {
    let storageManager = StorageManager.shared
    @StateObject private var settings = AppSettings()
    @StateObject private var security = AppSecurityManager()
    
    var body: some Scene {
        WindowGroup {
            AppContentView(storageManager: storageManager)
                .environmentObject(settings)
                .environmentObject(security)
                .environment(\.locale, settings.language.locale)
                .preferredColorScheme(settings.theme.colorScheme)
        }
        .modelContainer(storageManager.swiftDataContainer)
    }
}

private struct AppContentView: View {
    @StateObject private var viewModel: AppLaunchViewModel
    @EnvironmentObject private var security: AppSecurityManager
    @Environment(\.scenePhase) private var scenePhase

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
                if security.isLocked {
                    AppLockView()
                } else {
                    FinanceAppView()
                        .networkErrorAlert()
                }
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
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                security.unlockWithBiometricsIfPossible()
            case .background:
                security.lockIfNeeded()
            default:
                break
            }
        }
    }
}
