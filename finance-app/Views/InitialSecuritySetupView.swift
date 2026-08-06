import SwiftUI

struct InitialSecuritySetupView: View {
    @EnvironmentObject private var security: AppSecurityManager
    @State private var pin = ""
    @State private var showValidationError = false

    var body: some View {
        VStack {
            Spacer()

            Image(systemName: "lock.fill")
                .font(.largeTitle)
                .foregroundStyle(.tint)

            Text("Защитите приложение PIN-кодом")
                .font(.title3.weight(.semibold))
                .padding(.top)

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
                if security.setPIN(pin) {
                    security.disableBiometrics()
                } else {
                    showValidationError = true
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.blue)
            .padding(.top)

            Spacer()
        }
        .padding()
        .alert("PIN-код должен содержать 4 цифры", isPresented: $showValidationError) {
            Button("ОК", role: .cancel) {}
        }
    }
}
