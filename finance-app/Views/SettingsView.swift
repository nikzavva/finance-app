import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = SettingsViewModel()
    
    var body: some View {
        Form {
            Section("Хранилище данных") {
                Toggle("Использовать CoreData", isOn: $viewModel.useCoreData)
                    .disabled(viewModel.isMigrating)
                    .onChange(of: viewModel.useCoreData) { _, newValue in
                        viewModel.requestStorageChange(to: newValue)
                    }
                
                if viewModel.isMigrating {
                    HStack {
                        ProgressView()
                        Text("Миграция данных...")
                            .foregroundColor(.secondary)
                    }
                }
                
                Text("Текущее: \(viewModel.useCoreData ? "CoreData" : "SwiftData")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Section("О приложении") {
                LabeledContent("Версия", value: "1.0")
            }
        }
        .navigationTitle("Настройки")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Ошибка миграции", isPresented: $viewModel.showMigrationError) {
            Button("ОК", role: .cancel) {}
        } message: {
            Text(viewModel.migrationErrorMessage)
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.body)
                        .foregroundColor(.primary)
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { dismiss() }) {
                    Image(systemName: "checkmark")
                        .font(.body)
                        .foregroundColor(.accentColor)
                }
            }
        }
    }
}
