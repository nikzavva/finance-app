import SwiftUI

enum PINCodeMode: Equatable {
    case setup
    case unlock
    case change
}

struct PINCodeView: View {
    let mode: PINCodeMode

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var security: AppSecurityManager
    @EnvironmentObject private var settings: AppSettings
    @State private var pin = ""
    @State private var showError = false
    @State private var isPINConfirmed = false

    var body: some View {
        Group {
            if mode == .change {
                NavigationStack {
                    pinContent
                        .navigationTitle("PIN-код".appLocalized(for: settings.language))
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button(action: { dismiss() }) {
                                    Image(systemName: "xmark")
                                        .font(.body)
                                        .foregroundStyle(.primary)
                                }
                                .tint(.primary)
                            }
                        }
                }
            } else {
                pinContent
            }
        }
        .adaptivePresentationDetents(
            iPhone: mode == .change ? [.medium] : [.large],
            iPad: [.large]
        )
        .alert(errorTitle, isPresented: $showError) {
            Button("ОК", role: .cancel) {}
        }
    }

    private var pinContent: some View {
        VStack {
            Spacer()

            Image(systemName: "lock.fill")
                .font(.largeTitle)
                .foregroundStyle(.tint)

            Text(title)
                .font(.title3.weight(.semibold))
                .multilineTextAlignment(.center)
                .padding(.top)

            if mode == .setup && isPINConfirmed {
                biometricsOffer
            } else {
                pinField
                primaryButton

                if mode == .unlock {
                    unlockActions
                }
            }

            Spacer()
        }
        .padding()
    }

    private var pinField: some View {
        SecureField("PIN-код".appLocalized(for: settings.language), text: $pin)
            .keyboardType(.numberPad)
            .textContentType(.oneTimeCode)
            .multilineTextAlignment(.center)
            .font(.title2.monospacedDigit())
            .padding()
            .background(
                Color(uiColor: .secondarySystemBackground),
                in: RoundedRectangle(cornerRadius: UIConstants.CornerRadius.medium)
            )
            .onChange(of: pin) { _, value in
                let filteredPIN = String(value.filter(\.isNumber).prefix(4))
                if pin != filteredPIN {
                    pin = filteredPIN
                }
                if mode == .unlock && filteredPIN.count == 4 {
                    showError = !security.unlock(with: filteredPIN)
                    if showError {
                        pin = ""
                    }
                }
            }
    }

    @ViewBuilder
    private var primaryButton: some View {
        switch mode {
        case .setup:
            Button("Продолжить".appLocalized(for: settings.language)) {
                guard isValidPIN else {
                    showError = true
                    return
                }
                isPINConfirmed = true
            }
            .buttonStyle(.borderedProminent)
            .tint(.accentColor)
            .padding(.top)
        case .unlock:
            EmptyView()
        case .change:
            Button("Сохранить".appLocalized(for: settings.language)) {
                if security.setPIN(pin) {
                    HapticsManager.shared.play(.confirmation)
                    dismiss()
                } else {
                    showError = true
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.accentColor)
            .padding(.top)
        }
    }

    private var unlockActions: some View {
        VStack {
            if security.useBiometrics && security.isBiometricsAvailable {
                Button(
                    String(
                        format: "Войти с %@".appLocalized(for: settings.language),
                        security.biometryName
                    )
                ) {
                    security.unlockWithBiometricsIfPossible()
                }
                .buttonStyle(.bordered)
                .disabled(security.isAuthenticatingBiometrics)
            }

            DeleteAllDataButton()
                .padding(.top)
        }
    }

    private var biometricsOffer: some View {
        VStack {
            if security.isBiometricsAvailable {
                Button(
                    String(
                        format: "Использовать %@".appLocalized(for: settings.language),
                        security.biometryName
                    )
                ) {
                    Task {
                        guard await security.authenticateInitialBiometrics() else { return }
                        completeInitialSetup(useBiometrics: true)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.accentColor)
            }

            Button("Продолжить без биометрии".appLocalized(for: settings.language)) {
                completeInitialSetup(useBiometrics: false)
            }
            .buttonStyle(.plain)
            .padding(.top)
        }
    }

    private var title: String {
        switch mode {
        case .setup:
            return isPINConfirmed
                ? "Подключите биометрический вход".appLocalized(for: settings.language)
                : "Защитите приложение PIN-кодом".appLocalized(for: settings.language)
        case .unlock:
            return "Введите PIN-код".appLocalized(for: settings.language)
        case .change:
            return security.hasPIN
                ? "Введите новый PIN-код".appLocalized(for: settings.language)
                : "Задайте PIN-код".appLocalized(for: settings.language)
        }
    }

    private var errorTitle: String {
        switch mode {
        case .unlock:
            return "Неверный PIN-код".appLocalized(for: settings.language)
        case .setup, .change:
            return "PIN-код должен содержать 4 цифры".appLocalized(for: settings.language)
        }
    }

    private var isValidPIN: Bool {
        pin.count == 4 && pin.allSatisfy(\.isNumber)
    }

    private func completeInitialSetup(useBiometrics: Bool) {
        if security.completeInitialSetup(pin: pin, useBiometrics: useBiometrics) {
            HapticsManager.shared.play(.confirmation)
        } else {
            showError = true
        }
    }
}
