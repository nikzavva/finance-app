import SwiftUI

struct AddButton: View {
    let action: () -> Void
    
    var body: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Button {
                    HapticsManager.shared.play(.action)
                    action()
                } label: {
                    Image(systemName: "plus")
                        .font(.largeTitle)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .frame(width: UIConstants.Sizes.button, height: UIConstants.Sizes.button)
                        .background(Color.accentColor)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .padding(.trailing)
                .padding(.bottom)
            }
        }
    }
}
