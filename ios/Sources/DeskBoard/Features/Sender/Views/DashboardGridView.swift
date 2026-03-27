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
    @State private var confirmAction: DeskButton?
    @State private var showKnobEditor = false
    @State private var transientFrames: [UUID: DeckButtonFrame] = [:]

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 12), count: page.layoutColumns)
    }

    var body: some View {
        Group {
            if page.layoutMode == .grid {
                gridContent
            } else {
                freeformContent
            }
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

                    Menu("Layout Mode") {
                        ForEach(DashboardLayoutMode.allCases, id: \.self) { mode in
                            Button {
                                viewModel.setLayoutMode(mode, for: page, in: dashboard)
                            } label: {
                                HStack {
                                    Text(mode.title)
                                    if page.layoutMode == mode {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    }

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
                        showKnobEditor = true
                    } label: {
                        Label("Knob Controls", systemImage: "dial.medium")
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
        .sheet(isPresented: $showKnobEditor) {
            KnobEditorSheet(page: page) { knobs in
                viewModel.updateKnobs(knobs, for: page, in: dashboard)
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
        .onChange(of: page.id) { _ in
            transientFrames.removeAll()
        }
    }

    private var gridContent: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(page.buttons.sorted(by: { $0.position < $1.position })) { button in
                    DeskButtonView(
                        button: button,
                        isEditMode: isEditMode,
                        executionState: viewModel.stateFor(button.id)
                    ) {
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
    }

    private var freeformContent: some View {
        FreeformCanvasView(
            page: page,
            isEditMode: isEditMode,
            showAddButton: {
                showAddButton = true
            },
            stateForButton: { buttonID in
                viewModel.stateFor(buttonID)
            },
            frameForButton: { button, index in
                frameForButton(button, index: index)
            },
            onTap: { button in
                handleButtonTap(button)
            },
            onEdit: { button in
                buttonToEdit = button
            },
            onDelete: { button in
                buttonToDelete = button
            },
            onFrameUpdate: { button, frame, commit in
                transientFrames[button.id] = frame
                if commit {
                    viewModel.updateButtonFrame(frame, for: button, in: page, dashboard: dashboard)
                }
            }
        )
    }

    private func frameForButton(_ button: DeskButton, index: Int) -> DeckButtonFrame {
        if let cached = transientFrames[button.id] {
            return cached
        }
        if let existing = button.buttonFrame {
            return existing
        }

        let columns = max(2, page.layoutColumns)
        let spacing: Double = 16
        let size: Double
        switch button.sizePreset {
        case .small:
            size = 82
        case .medium:
            size = 100
        case .large:
            size = 128
        case .extraLarge:
            size = 152
        case .custom:
            size = 110
        }
        let row = index / columns
        let col = index % columns
        return DeckButtonFrame(
            x: Double(col) * (size + spacing) + spacing,
            y: Double(row) * (size + spacing) + spacing,
            width: size,
            height: size,
            zIndex: Double(index)
        )
    }

    private func handleButtonTap(_ button: DeskButton) {
        if button.config.confirmBeforeExecute {
            confirmAction = button
        } else {
            viewModel.tap(button: button)
        }
    }
}

private struct FreeformCanvasView: View {
    let page: DashboardPage
    let isEditMode: Bool
    let showAddButton: () -> Void
    let stateForButton: (UUID) -> ButtonExecutionState
    let frameForButton: (DeskButton, Int) -> DeckButtonFrame
    let onTap: (DeskButton) -> Void
    let onEdit: (DeskButton) -> Void
    let onDelete: (DeskButton) -> Void
    let onFrameUpdate: (DeskButton, DeckButtonFrame, Bool) -> Void

    private var sortedButtons: [DeskButton] {
        page.buttons.sorted { lhs, rhs in
            let lf = lhs.buttonFrame?.zIndex ?? Double(lhs.position)
            let rf = rhs.buttonFrame?.zIndex ?? Double(rhs.position)
            return lf < rf
        }
    }

    private var canvasSize: CGSize {
        let baseWidth: Double = 1200
        let baseHeight: Double = 860
        let maxX = sortedButtons.enumerated().map { index, button in
            let frame = frameForButton(button, index)
            return frame.x + frame.width
        }.max() ?? 0
        let maxY = sortedButtons.enumerated().map { index, button in
            let frame = frameForButton(button, index)
            return frame.y + frame.height
        }.max() ?? 0
        return CGSize(width: max(baseWidth, maxX + 120), height: max(baseHeight, maxY + 140))
    }

    var body: some View {
        ScrollView([.vertical, .horizontal]) {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(Color.secondary.opacity(0.25), style: StrokeStyle(lineWidth: 1.2, dash: [5]))
                    )

                ForEach(Array(sortedButtons.enumerated()), id: \.element.id) { index, button in
                    let frame = frameForButton(button, index)
                    FreeformButtonNode(
                        button: button,
                        frame: frame,
                        isEditMode: isEditMode,
                        executionState: stateForButton(button.id),
                        onTap: {
                            onTap(button)
                        },
                        onEdit: {
                            onEdit(button)
                        },
                        onDelete: {
                            onDelete(button)
                        },
                        onFrameUpdate: { nextFrame, commit in
                            onFrameUpdate(button, nextFrame, commit)
                        }
                    )
                    .zIndex(frame.zIndex)
                }

                if isEditMode {
                    AddFreeformButton {
                        showAddButton()
                    }
                    .position(x: 96, y: 96)
                }
            }
            .frame(width: canvasSize.width, height: canvasSize.height, alignment: .topLeading)
            .padding(.bottom, 26)
        }
    }
}

private struct FreeformButtonNode: View {
    let button: DeskButton
    let frame: DeckButtonFrame
    let isEditMode: Bool
    let executionState: ButtonExecutionState
    let onTap: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onFrameUpdate: (DeckButtonFrame, Bool) -> Void

    @State private var dragStartFrame: DeckButtonFrame?
    @State private var resizeStartFrame: DeckButtonFrame?

    var body: some View {
        DeskButtonView(
            button: button,
            isEditMode: isEditMode,
            executionState: executionState,
            enforceAspectRatio: false,
            onTap: onTap,
            onEdit: onEdit,
            onDelete: onDelete
        )
        .frame(width: frame.width, height: frame.height)
        .position(x: frame.x + frame.width / 2, y: frame.y + frame.height / 2)
        .overlay(alignment: .bottomTrailing) {
            if isEditMode && !button.dragLocked {
                Circle()
                    .fill(Color.white.opacity(0.9))
                    .frame(width: 16, height: 16)
                    .overlay(
                        Circle()
                            .strokeBorder(Color.blue, lineWidth: 2)
                    )
                    .padding(2)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                if resizeStartFrame == nil {
                                    resizeStartFrame = frame
                                }
                                let base = resizeStartFrame ?? frame
                                let next = DeckButtonFrame(
                                    x: base.x,
                                    y: base.y,
                                    width: max(60, base.width + value.translation.width),
                                    height: max(60, base.height + value.translation.height),
                                    zIndex: base.zIndex
                                )
                                onFrameUpdate(next, false)
                            }
                            .onEnded { value in
                                let base = resizeStartFrame ?? frame
                                let final = DeckButtonFrame(
                                    x: base.x,
                                    y: base.y,
                                    width: max(60, base.width + value.translation.width),
                                    height: max(60, base.height + value.translation.height),
                                    zIndex: base.zIndex
                                )
                                onFrameUpdate(final, true)
                                resizeStartFrame = nil
                            }
                    )
            }
        }
        .overlay(alignment: .topLeading) {
            if button.dragLocked && isEditMode {
                Image(systemName: "lock.fill")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(6)
                    .background(Color.black.opacity(0.6))
                    .clipShape(Capsule())
                    .padding(5)
            }
        }
        .gesture(
            DragGesture(minimumDistance: isEditMode && !button.dragLocked ? 0 : 9999)
                .onChanged { value in
                    guard isEditMode, !button.dragLocked else { return }
                    if dragStartFrame == nil {
                        dragStartFrame = frame
                    }
                    let base = dragStartFrame ?? frame
                    let next = DeckButtonFrame(
                        x: max(0, base.x + value.translation.width),
                        y: max(0, base.y + value.translation.height),
                        width: base.width,
                        height: base.height,
                        zIndex: base.zIndex
                    )
                    onFrameUpdate(next, false)
                }
                .onEnded { value in
                    guard isEditMode, !button.dragLocked else { return }
                    let base = dragStartFrame ?? frame
                    let final = DeckButtonFrame(
                        x: max(0, base.x + value.translation.width),
                        y: max(0, base.y + value.translation.height),
                        width: base.width,
                        height: base.height,
                        zIndex: base.zIndex
                    )
                    onFrameUpdate(final, true)
                    dragStartFrame = nil
                }
        )
    }
}

private struct AddFreeformButton: View {
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
            .frame(width: 120, height: 120)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.secondary.opacity(0.3), style: StrokeStyle(lineWidth: 1.5, dash: [6]))
            )
        }
        .buttonStyle(.plain)
    }
}

private struct KnobEditorSheet: View {
    let page: DashboardPage
    let onSave: ([DeckKnobConfig]) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var knobs: [DeckKnobConfig]

    init(page: DashboardPage, onSave: @escaping ([DeckKnobConfig]) -> Void) {
        self.page = page
        self.onSave = onSave
        _knobs = State(initialValue: page.knobs)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Button {
                        knobs.append(
                            DeckKnobConfig(
                                label: "KNOB \(knobs.count + 1)",
                                size: 96,
                                stepThreshold: 14,
                                hapticStyle: .selection,
                                clockwiseAction: .mediaVolumeUp,
                                counterClockwiseAction: .mediaVolumeDown,
                                placement: .center
                            )
                        )
                    } label: {
                        Label("Add Knob", systemImage: "plus.circle.fill")
                    }
                }

                ForEach($knobs) { $knob in
                    Section(knob.label.isEmpty ? "Knob" : knob.label) {
                        TextField("Label", text: $knob.label)

                        HStack {
                            Text("Size")
                            Spacer()
                            Text("\(Int(knob.size))")
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: $knob.size, in: 72...220, step: 2)

                        HStack {
                            Text("Sensitivity")
                            Spacer()
                            Text("\(Int(knob.stepThreshold))")
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: $knob.stepThreshold, in: 8...28, step: 1)

                        Picker("Placement", selection: $knob.placement) {
                            ForEach(DeckKnobPlacement.allCases, id: \.self) { placement in
                                Text(placement.rawValue.capitalized).tag(placement)
                            }
                        }

                        Picker("Haptic", selection: $knob.hapticStyle) {
                            ForEach(DeckKnobHapticStyle.allCases, id: \.self) { style in
                                Text(style.rawValue.capitalized).tag(style)
                            }
                        }

                        KnobActionPicker(title: "Clockwise", selection: $knob.clockwiseAction)
                        KnobActionPicker(title: "Counter-Clockwise", selection: $knob.counterClockwiseAction)

                        Toggle("Visible", isOn: $knob.isVisible)

                        Button(role: .destructive) {
                            knobs.removeAll { $0.id == knob.id }
                        } label: {
                            Label("Delete Knob", systemImage: "trash")
                        }
                    }
                }
            }
            .navigationTitle("Knob Controls")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(knobs)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

private struct KnobActionPicker: View {
    let title: String
    @Binding var selection: ButtonAction

    private let options: [ButtonAction] = [
        .mediaVolumeUp,
        .mediaVolumeDown,
        .mediaNext,
        .mediaPrevious,
        .appSwitchNext,
        .appSwitchPrevious,
        .moveSpaceLeft,
        .moveSpaceRight,
        .presentationNext,
        .presentationPrevious,
        .none
    ]

    var body: some View {
        Picker(title, selection: $selection) {
            ForEach(options, id: \.self) { action in
                Label(action.displayName, systemImage: action.systemImage)
                    .tag(action)
            }
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
