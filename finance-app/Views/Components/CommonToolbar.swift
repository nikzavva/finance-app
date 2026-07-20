import SwiftUI

struct CommonToolbar: ToolbarContent {
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
            .popover(isPresented: $showDatePicker, attachmentAnchor: .point(.bottom)) {
                DatePicker("Выберите дату", selection: $selectedDate, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .frame(minWidth: UIConstants.Sizes.datePickerMinWidth)
                    .presentationCompactAdaptation(.none)
            }
        }
        
        ToolbarItem(placement: .navigationBarTrailing) {
            NavigationLink(value: AppRoute.analytics) {
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
