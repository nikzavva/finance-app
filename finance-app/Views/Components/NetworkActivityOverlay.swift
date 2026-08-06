import SwiftUI

private struct NetworkLoadingOverlay: ViewModifier {
    @ObservedObject private var viewModel = NetworkPresentationViewModel.shared

    func body(content: Content) -> some View {
        content
            .overlay {
                if viewModel.isLoading {
                    ZStack {
                        Color.black.opacity(0.2)
                            .ignoresSafeArea()
                        ProgressView("Загрузка...")
                            .padding()
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
    }
}

private struct NetworkErrorAlert: ViewModifier {
    @ObservedObject private var viewModel = NetworkPresentationViewModel.shared

    func body(content: Content) -> some View {
        content
            .alert(
                "Ошибка",
                isPresented: Binding(
                    get: { viewModel.isShowingError },
                    set: { if !$0 { viewModel.dismissError() } }
                )
            ) {
                Button("ОК") {
                    viewModel.dismissError()
                }
            } message: {
                Text(viewModel.errorMessage)
            }
    }
}

extension View {
    func networkLoadingOverlay() -> some View {
        modifier(NetworkLoadingOverlay())
    }

    func networkErrorAlert() -> some View {
        modifier(NetworkErrorAlert())
    }
}
