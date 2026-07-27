import SwiftUI

struct SettingsView: View {
    @AppStorage("use_coredata") private var useCoreData = false
    @Environment(\.dismiss) private var dismiss
    @State private var isMigrating = false
    
    var body: some View {
        Form {
            Section("Хранилище данных") {
                Toggle("Использовать CoreData", isOn: $useCoreData)
                    .disabled(isMigrating)
                    .onChange(of: useCoreData) { _, newValue in
                        Task {
                            isMigrating = true
                            await StorageManager.shared.switchStorage(
                                to: newValue ? .coreData : .swiftData
                            )
                            NotificationCenter.default.post(name: .transactionsDidChange, object: nil)
                            NotificationCenter.default.post(name: .accountsDidChange, object: nil)
                            isMigrating = false
                        }
                    }
                
                if isMigrating {
                    HStack {
                        ProgressView()
                        Text("Миграция данных...")
                            .foregroundColor(.secondary)
                    }
                }
                
                Text("Текущее: \(useCoreData ? "CoreData" : "SwiftData")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Section("О приложении") {
                LabeledContent("Версия", value: "1.0")
            }
        }
        .navigationTitle("Настройки")
        .navigationBarTitleDisplayMode(.inline)
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
