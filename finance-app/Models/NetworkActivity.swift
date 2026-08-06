import Combine
import Foundation

@MainActor
final class NetworkActivity: ObservableObject {
    static let shared = NetworkActivity()

    @Published private(set) var activeRequestCount = 0
    @Published var isShowingError = false
    @Published private(set) var errorMessage = ""

    var isLoading: Bool {
        activeRequestCount > 0
    }

    private init() {}

    func beginRequest() {
        activeRequestCount += 1
    }

    func finishRequest() {
        activeRequestCount = max(0, activeRequestCount - 1)
    }

    func present(error: Error) {
        errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        isShowingError = true
    }

    func dismissError() {
        isShowingError = false
        errorMessage = ""
    }
}
