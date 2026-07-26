import Foundation
import Network
import Combine

final class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    
    @Published private(set) var isConnected: Bool = true
    @Published private(set) var isOfflineMode: Bool = false
    
    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                let connected = path.status == .satisfied
                let wasOffline = !(self?.isConnected ?? true)
                self?.isConnected = connected
                
                if connected && wasOffline {
                    self?.isOfflineMode = false
                    NotificationCenter.default.post(name: .transactionsDidChange, object: nil)
                    NotificationCenter.default.post(name: .accountsDidChange, object: nil)
                } else if !connected {
                    self?.isOfflineMode = true
                }
            }
        }
        monitor.start(queue: queue)
    }
    
    func markOfflineDataUsed() {
        DispatchQueue.main.async {
            self.isOfflineMode = true
        }
    }
    
    func markDataFresh() {
        DispatchQueue.main.async {
            if self.isConnected {
                self.isOfflineMode = false
            }
        }
    }
}
