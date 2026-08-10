import SwiftUI
import UIKit

extension View {
    @ViewBuilder
    func adaptivePresentationDetents(
        iPhone: Set<PresentationDetent>,
        iPad: Set<PresentationDetent>
    ) -> some View {
        if UIDevice.current.userInterfaceIdiom == .pad {
            presentationDetents(iPad)
        } else {
            presentationDetents(iPhone)
        }
    }
}
