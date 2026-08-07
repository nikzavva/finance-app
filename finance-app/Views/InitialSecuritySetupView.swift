import SwiftUI

struct InitialSecuritySetupView: View {
    @EnvironmentObject private var security: AppSecurityManager
    @State private var pin = ""
    @State private var showValidationError = false
    @State private var isPINConfirmed = false

    var body: some View {
        VStack {
            Spacer()

            Image(systemName: "lock.fill")
                .font(.largeTitle)
                .foregroundStyle(.tint)

            Text(
                isPINConfirmed
                    ? "Подключите биометрический вход".appLocalized
                    : "Защитите приложение PIN-кодом".appLocalized
            )
                .font(.title3.weight(.semibold))
                .padding(.top)

            if isPINConfirmed {
                if security.isBiometricsAvailable {
                    Button(
                        String(
                            format: "Использовать %@".appLocalized,
                            security.biometryName
                        )
                    ) {
                        Task {
                            guard await security.authenticateInitialBiometrics() else { return }
                            if !security.completeInitialSetup(pin: pin, useBiometrics: true) {
                                showValidationError = true
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                }

                Button("Продолжить без биометрии") {
                    if !security.completeInitialSetup(pin: pin, useBiometrics: false) {
                        showValidationError = true
                    }
                }
                .buttonStyle(.plain)
                .padding(.top)
            } else {
                SecureField("PIN-код", text: $pin)
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)
                    .multilineTextAlignment(.center)
                    .font(.title2.monospacedDigit())
                    .padding()
                    .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                    .onChange(of: pin) { _, value in
                        pin = String(value.filter(\.isNumber).prefix(4))
                    }

                Button("Продолжить") {
                    if pin.count == 4, pin.allSatisfy(\.isNumber) {
                        isPINConfirmed = true
                    } else {
                        showValidationError = true
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                .padding(.top)
            }

            Spacer()
        }
        .padding()
        .alert("PIN-код должен содержать 4 цифры", isPresented: $showValidationError) {
            Button("ОК", role: .cancel) {}
        }
    }
}
