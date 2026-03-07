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
    @State private var showColumnPicker = false
    @State private var confirmAction: DeskButton?

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 12), count: page.layoutColumns)
    }

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(page.buttons.sorted(by: { $0.position < $1.position })) { button in
                    DeskButtonView(button: button, isEditMode: isEditMode) {
                        handleButtonTap(button)
                    } onEdit: {
                        buttonToEdit = button
                    } onDelete: {
                        buttonToDelete = button
                    }
                }

                AddButtonCell {
                    showAddButton = true
                }
            }
            .padding(.bottom, 20)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button(isEditMode ? "Done Editing" : "Edit Layout") {
                        withAnimation(.spring(duration: 0.3)) {
                            isEditMode.toggle()
                        }
                    }

                    Divider()

                    Menu("Grid Columns") {
                        ForEach(2...5, id: \.self) { count in
                            Button {
                                viewModel.setColumns(count, for: page, in: dashboard)
                            } label: {
                                HStack {
                                    Text("\(count) Columns")
                                    if page.layoutColumns == count {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    }

                    Divider()

                    Button {
                        viewModel.addPage(to: dashboard)
                    } label: {
                        Label("Add Page", systemImage: "plus.rectangle")
                    }

                    if dashboard.pages.count > 1 {
                        Button {
                            viewModel.duplicatePage(page, in: dashboard)
                        } label: {
                            Label("Duplicate Page", systemImage: "plus.rectangle.on.rectangle")
                        }

                        Button(role: .destructive) {
                            viewModel.deletePage(page, from: dashboard)
                        } label: {
                            Label("Delete Page", systemImage: "trash")
                        }
                    }
                } label: {
                    Image(systemName: isEditMode ? "checkmark.circle.fill" : "ellipsis.circle")
                }
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
        .alert("Confirm Action", isPresented: Binding(
            get: { confirmAction != nil },
            set: { if !$0 { confirmAction = nil } }
        )) {
            Button("Execute") {
                if let btn = confirmAction {
                    viewModel.tap(button: btn)
                }
                confirmAction = nil
            }
            Button("Cancel", role: .cancel) { confirmAction = nil }
        } message: {
            Text("Execute \"\(confirmAction?.title ?? "")\"?")
        }
    }

    private func handleButtonTap(_ button: DeskButton) {
        if button.config.confirmBeforeExecute {
            confirmAction = button
        } else {
            viewModel.tap(button: button)
        }
    }
}

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
