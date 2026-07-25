import SwiftUI
import SwiftData

@main
struct FinanceApp: App {
    let storageManager = StorageManager.shared
    
    var body: some Scene {
        WindowGroup {
            FinanceAppView()
        }
        .modelContainer(storageManager.container)
    }
}
