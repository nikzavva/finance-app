import SwiftUI

struct OfflineIndicator: View {
    @ObservedObject var monitor = NetworkMonitor.shared
    
    var body: some View {
        if monitor.isOfflineMode {
            VStack {
                Spacer()
                HStack {
                    Image(systemName: "wifi.slash")
                        .font(.largeTitle)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .frame(width: UIConstants.Sizes.button, height: UIConstants.Sizes.button)
                        .background(Color.orange)
                        .clipShape(Circle())
                        .allowsHitTesting(false)
                        .padding(.leading)
                        .padding(.bottom)
                    Spacer()
                }
            }
            .transition(.scale.combined(with: .opacity))
            .animation(.easeInOut, value: monitor.isOfflineMode)
        }
    }
}
