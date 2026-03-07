import SwiftUI

struct DashboardGridView: View {
    let page: DashboardPage
    let dashboard: Dashboard

    @EnvironmentObject var appState: AppState
    @EnvironmentObject var viewModel: SenderViewModel

    @State private var showAddButton = false
    @State private var buttonToEdit: DeskButton?
    @State private var buttonToDelete: DeskButton?
    @State private var isEditMode = false

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 12), count: page.layoutColumns)
    }

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(page.buttons.sorted(by: { $0.position < $1.position })) { button in
                    DeskButtonView(button: button, isEditMode: isEditMode) {
                        viewModel.tap(button: button)
                    } onEdit: {
                        buttonToEdit = button
                    } onDelete: {
                        buttonToDelete = button
                    }
                }

                // Add button cell
                AddButtonCell {
                    showAddButton = true
                }
            }
            .padding(.bottom, 20)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(isEditMode ? "Done" : "Edit") {
                    withAnimation(.spring(duration: 0.3)) {
                        isEditMode.toggle()
                    }
                }
                .fontWeight(isEditMode ? .semibold : .regular)
            }
        }
        .sheet(isPresented: $showAddButton) {
            ButtonEditorView(mode: .add) { newButton in
                viewModel.addButton(newButton, to: page, in: dashboard)
            }
        }
        .sheet(item: $buttonToEdit) { button in
            ButtonEditorView(mode: .edit(button)) { updatedButton in
                viewModel.updateButton(updatedButton, in: page, dashboard: dashboard)
            }
        }
        .alert("Delete Button", isPresented: Binding(
            get: { buttonToDelete != nil },
            set: { if !$0 { buttonToDelete = nil } }
        )) {
            Button("Delete", role: .destructive) {
                if let btn = buttonToDelete {
                    viewModel.deleteButton(btn, from: page, in: dashboard)
                }
                buttonToDelete = nil
            }
            Button("Cancel", role: .cancel) { buttonToDelete = nil }
        } message: {
            Text("Are you sure you want to delete \"\(buttonToDelete?.title ?? "")\"?")
        }
    }
}

// MARK: - AddButtonCell

private struct AddButtonCell: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.title2.weight(.medium))
                    .foregroundStyle(.tertiary)
                Text("Add")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity)
            .aspectRatio(1, contentMode: .fit)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.secondary.opacity(0.3), style: StrokeStyle(lineWidth: 1.5, dash: [6]))
            )
        }
        .buttonStyle(.plain)
    }
}