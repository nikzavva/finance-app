import SwiftUI

struct CommonToolbar: ToolbarContent {
    let direction: Direction
    @Binding var selectedDate: Date
    @Binding var showDatePicker: Bool
    @Binding var showSettings: Bool
    
    var body: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            Button(action: { showDatePicker = true }) {
                HStack {
                    Image(systemName: "calendar")
                    Text(selectedDate, format: .dateTime.day().month(.wide))
                }
                .font(.callout)
                .foregroundColor(.primary)
            }
            .sheet(isPresented: $showDatePicker) {
                DatePicker("Выберите дату", selection: $selectedDate, in: ...Date(), displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .adaptivePresentationDetents(iPhone: [.medium], iPad: [.large])
            }
        }
        
        ToolbarItem(placement: .navigationBarTrailing) {
            NavigationLink(value: AppRoute.analytics(direction)) {
                Image(systemName: "chart.pie")
                    .font(.title3)
                    .foregroundColor(.primary)
            }
            .buttonStyle(.plain)
        }
        
        if #available(iOS 26, *) {
            ToolbarSpacer(.fixed, placement: .navigationBarTrailing)
        }
        
        ToolbarItem(placement: .navigationBarTrailing) {
            Button(action: { showSettings = true }) {
                Image(systemName: "slider.horizontal.3")
                    .font(.title3)
                    .foregroundColor(.primary)
            }
        }
    }
}

struct AccountsToolbar: ToolbarContent {
    @Binding var showSettings: Bool

    var body: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Button(action: { showSettings = true }) {
                Image(systemName: "slider.horizontal.3")
                    .font(.title3)
                    .foregroundColor(.primary)
            }
        }
    }
}
