import Combine
import Foundation

@MainActor
final class NetworkPresentationViewModel: ObservableObject {
    static let shared = NetworkPresentationViewModel()

    @Published private(set) var isLoading = false
    @Published private(set) var isOffline = false
    @Published private(set) var errorMessage = ""
    @Published private(set) var isShowingError = false

    private let activity: NetworkActivity

    private init(
        activity: NetworkActivity? = nil,
        monitor: NetworkMonitor? = nil
    ) {
        let activity = activity ?? NetworkActivity.shared
        let monitor = monitor ?? NetworkMonitor.shared
        self.activity = activity

        activity.$activeRequestCount
            .map { $0 > 0 }
            .removeDuplicates()
            .assign(to: &$isLoading)

        activity.$isShowingError
            .removeDuplicates()
            .assign(to: &$isShowingError)

        activity.$errorMessage
            .removeDuplicates()
            .assign(to: &$errorMessage)

        monitor.$isOfflineMode
            .removeDuplicates()
            .assign(to: &$isOffline)
    }

    func dismissError() {
        activity.dismissError()
    }
}
