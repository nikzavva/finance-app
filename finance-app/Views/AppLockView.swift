import SwiftUI

struct AppLockView: View {
    @EnvironmentObject private var security: AppSecurityManager
    @State private var pin = ""
    @State private var isInvalidPIN = false

    var body: some View {
        VStack {
            Image(systemName: "lock.fill")
                .font(.largeTitle)
                .foregroundStyle(.tint)
            Text("Введите PIN-код")
                .font(.title3.weight(.semibold))
            SecureField("PIN-код", text: $pin)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .multilineTextAlignment(.center)
                .font(.title2.monospacedDigit())
                .padding()
                .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                .onChange(of: pin) { _, value in
                    pin = String(value.filter(\.isNumber).prefix(4))
                    if pin.count == 4 {
                        isInvalidPIN = !security.unlock(with: pin)
                        if isInvalidPIN { pin = "" }
                    }
                }

            if security.useBiometrics && security.isBiometricsAvailable {
                Button(security.biometryName) {
                    security.unlockWithBiometricsIfPossible()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .alert("Неверный PIN-код", isPresented: $isInvalidPIN) {
            Button("ОК", role: .cancel) {}
        }
        .onAppear {
            security.unlockWithBiometricsIfPossible()
        }
    }
}
