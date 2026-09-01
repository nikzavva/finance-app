import Combine
import SwiftUI
import SwiftData
import UIKit

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
    @State private var locksOnNextActivation = false
    @EnvironmentObject private var settings: AppSettings
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
            } else if !security.hasPIN {
                PINCodeView(mode: .setup)
            } else {
                if security.isLocked {
                    PINCodeView(mode: .unlock)
                } else {
                    FinanceAppView()
                        .networkErrorAlert()
                }
            }
        }
        .onAppear {
            settings.applyThemeToWindows()
            AppPrivacyController.setProtected(
                scenePhase != .active && !security.isAuthenticatingBiometrics
            )
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
            if phase == .background {
                locksOnNextActivation = true
                if !security.isAuthenticatingBiometrics {
                    AppPrivacyController.setProtected(true)
                }
            } else if phase == .active, locksOnNextActivation {
                locksOnNextActivation = false
                security.lockIfNeeded()
                Task { @MainActor in
                    await Task.yield()
                    guard UIApplication.shared.applicationState == .active,
                          !security.isAuthenticatingBiometrics else {
                        return
                    }
                    AppPrivacyController.setProtected(false)
                }
            } else if phase == .active {
                guard !security.isAuthenticatingBiometrics else { return }
                AppPrivacyController.setProtected(false)
            } else if !security.isAuthenticatingBiometrics {
                AppPrivacyController.setProtected(true)
            }
        }
        .onChange(of: security.isAuthenticatingBiometrics) { _, isAuthenticating in
            if !isAuthenticating {
                AppPrivacyController.setProtected(scenePhase != .active)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
            guard !security.isAuthenticatingBiometrics else { return }
            AppPrivacyController.setProtected(true)
        }
    }
}
