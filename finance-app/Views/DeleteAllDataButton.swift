import SwiftUI

struct DeleteAllDataButton: View {
    @EnvironmentObject private var security: AppSecurityManager
    @EnvironmentObject private var settings: AppSettings
    @State private var isDeleting = false
    @State private var showConfirmation = false
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        Button(role: .destructive) {
            showConfirmation = true
        } label: {
            HStack {
                if isDeleting {
                    ProgressView()
                }
                Text("Удалить все данные".appLocalized(for: settings.language))
            }
            .foregroundStyle(.red)
            .padding(.vertical)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isDeleting)
        .confirmationDialog(
            "Удалить все данные?".appLocalized(for: settings.language),
            isPresented: $showConfirmation,
            titleVisibility: .visible
        ) {
            Button("Удалить все данные".appLocalized(for: settings.language), role: .destructive) {
                deleteAllData()
            }
            Button("Отмена".appLocalized(for: settings.language), role: .cancel) {}
        } message: {
            Text(
                "Все счета и операции будут безвозвратно удалены с сервера и этого устройства."
                    .appLocalized(for: settings.language)
            )
        }
        .alert("Не удалось удалить данные".appLocalized(for: settings.language), isPresented: $showError) {
            Button("ОК".appLocalized(for: settings.language), role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }

    private func deleteAllData() {
        guard !isDeleting else { return }
        isDeleting = true
        Task {
            do {
                try await DataResetService().deleteAllUserData()
                security.resetSecurity()
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
            isDeleting = false
        }
    }
}
