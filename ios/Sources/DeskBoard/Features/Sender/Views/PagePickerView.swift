import SwiftUI

struct PagePickerView: View {
    let dashboard: Dashboard
    let selectedPage: DashboardPage?
    let onSelect: (DashboardPage) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(dashboard.pages) { page in
                    Button {
                        onSelect(page)
                    } label: {
                        Text(page.title)
                            .font(.subheadline.weight(.medium))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(
                                Capsule()
                                    .fill(selectedPage?.id == page.id
                                          ? (dashboard.color)
                                          : Color(.systemGray5))
                            )
                            .foregroundStyle(selectedPage?.id == page.id ? .white : .primary)
                    }
                    .buttonStyle(.plain)
                    .animation(.spring(duration: 0.2), value: selectedPage?.id)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }
}