import SwiftUI

struct AnalyticsView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Text("Экран аналитики")
            .font(.largeTitle)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden()
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        HStack {
                            Image(systemName: "chevron.left")
                        }
                        .font(.body)
                        .foregroundColor(.primary)
                    }
                }

                ToolbarItem(placement: .principal) {
                    HStack {
                        Text("Аналитика")
                            .font(.title2.bold())
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .toolbar(.hidden, for: .tabBar)
            .toolbarRole(.editor)
    }
}
