import SwiftUI

struct ButtonEditorView: View {
    enum Mode {
        case add
        case edit(DeskButton)
    }

    let mode: Mode
    let onSave: (DeskButton) -> Void

    @StateObject private var viewModel: ButtonEditorViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var testResult: String?

    init(mode: Mode, onSave: @escaping (DeskButton) -> Void) {
        self.mode = mode
        self.onSave = onSave
        switch mode {
        case .add:
            _viewModel = StateObject(wrappedValue: ButtonEditorViewModel())
        case .edit(let button):
            _viewModel = StateObject(wrappedValue: ButtonEditorViewModel(button: button))
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                previewSection
                labelSection
                iconSection
                colorSection
                actionSection
                customIconSection
                advancedSection
                optionsSection
            }
            .navigationTitle(isAdd ? "New Button" : "Edit Button")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let button: DeskButton
                        switch mode {
                        case .add:
                            button = viewModel.buildButton()
                        case .edit(let original):
                            button = viewModel.buildUpdatedButton(from: original)
                        }
                        onSave(button)
                        dismiss()
                    }
                    .disabled(!viewModel.isValid)
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private var isAdd: Bool {
        if case .add = mode { return true }
        return false
    }

    @ViewBuilder
    private var previewSection: some View {
        Section {
            HStack {
                Spacer()
                VStack(spacing: 6) {
                    if let url = URL(string: viewModel.iconURL.trimmed), !viewModel.iconURL.trimmed.isEmpty {
                        Color.clear
                            .frame(width: 36, height: 36)
                            .overlay {
                                AsyncImage(url: url) { phase in
                                    switch phase {
                                    case .success(let image):
                                        image.resizable().aspectRatio(contentMode: .fit).allowsHitTesting(false)
                                    default:
                                        Image(systemName: viewModel.icon)
                                            .font(.system(size: 36 * viewModel.iconScale, weight: .medium))
                                            .foregroundStyle(.white)
                                    }
                                }
                            }
                            .clipShape(.rect(cornerRadius: 6))
                    } else {
                        Image(systemName: viewModel.icon)
                            .font(.system(size: 36 * viewModel.iconScale, weight: .medium))
                            .foregroundStyle(.white)
                    }
                    Text(viewModel.title.isEmpty ? "Button" : viewModel.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                    if !viewModel.subtitle.trimmed.isEmpty {
                        Text(viewModel.subtitle)
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
                .frame(width: 100, height: 100)
                .background(
                    RoundedRectangle(cornerRadius: viewModel.cornerRadius, style: .continuous)
                        .fill(Color(hex: viewModel.colorHex) ?? .blue)
                )
                Spacer()
            }
            .listRowBackground(Color.clear)
        }
    }

    @ViewBuilder
    private var labelSection: some View {
        Section("Label") {
            TextField("Button Title", text: $viewModel.title)
            TextField("Subtitle (optional)", text: $viewModel.subtitle)
        }
    }

    @ViewBuilder
    private var iconSection: some View {
        Section("Icon") {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: 12) {
                ForEach(ButtonEditorViewModel.commonIcons, id: \.self) { iconName in
                    Button {
                        viewModel.icon = iconName
                    } label: {
                        Image(systemName: iconName)
                            .font(.title3)
                            .foregroundStyle(viewModel.icon == iconName ? .white : .primary)
                            .frame(width: 36, height: 36)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(viewModel.icon == iconName
                                          ? (Color(hex: viewModel.colorHex) ?? .blue)
                                          : Color(.systemGray5))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 4)
        }
    }

    @ViewBuilder
    private var colorSection: some View {
        Section("Color") {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 12) {
                ForEach(ButtonEditorViewModel.presetColors, id: \.hex) { preset in
                    Button {
                        viewModel.colorHex = preset.hex
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color(hex: preset.hex) ?? .blue)
                                .frame(width: 44, height: 44)
                            if viewModel.colorHex == preset.hex {
                                Image(systemName: "checkmark")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.white)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 4)
        }
    }

    @ViewBuilder
    private var actionSection: some View {
        Section("Action") {
            NavigationLink {
                ActionPickerView(selectedAction: $viewModel.selectedAction)
            } label: {
                HStack {
                    Image(systemName: viewModel.selectedAction.systemImage)
                        .foregroundStyle(.blue)
                        .frame(width: 24)
                    Text(viewModel.selectedAction.displayName)
                }
            }

            if case .openURL = viewModel.selectedAction {
                TextField("https://example.com", text: $viewModel.urlText)
                    .keyboardType(.URL)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            }

            if case .openDeepLink = viewModel.selectedAction {
                TextField("app://path", text: $viewModel.urlText)
                    .keyboardType(.URL)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            }

            if case .sendText = viewModel.selectedAction {
                TextField("Text to send", text: $viewModel.textPayload)
            }

            if case .keyboardShortcut = viewModel.selectedAction {
                TextField("Key (e.g. c, space, return)", text: $viewModel.shortcutKey)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                ModifierPicker(selected: $viewModel.shortcutModifiers)
            }

            Button {
                testAction()
            } label: {
                HStack {
                    Label("Test Action", systemImage: "play.circle")
                    Spacer()
                    if let result = testResult {
                        Text(result)
                            .font(.caption)
                            .foregroundStyle(result.contains("✓") ? .green : .orange)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var customIconSection: some View {
        Section("Custom Icon URL") {
            TextField("https://example.com/icon.png", text: $viewModel.iconURL)
                .keyboardType(.URL)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            if !viewModel.iconURL.trimmed.isEmpty, let url = URL(string: viewModel.iconURL.trimmed) {
                HStack {
                    Spacer()
                    Color.clear
                        .frame(width: 48, height: 48)
                        .overlay {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .success(let image):
                                    image.resizable().aspectRatio(contentMode: .fit).allowsHitTesting(false)
                                case .failure:
                                    Image(systemName: "exclamationmark.triangle").foregroundStyle(.orange)
                                default:
                                    ProgressView()
                                }
                            }
                        }
                        .clipShape(.rect(cornerRadius: 8))
                    Spacer()
                }
            }
        }
    }

    @ViewBuilder
    private var advancedSection: some View {
        Section("Advanced") {
            HStack {
                Text("Corner Radius")
                Spacer()
                Text("\(Int(viewModel.cornerRadius))")
                    .foregroundStyle(.secondary)
                    .frame(width: 30)
            }
            Slider(value: $viewModel.cornerRadius, in: 4...30, step: 2)

            HStack {
                Text("Icon Scale")
                Spacer()
                Text(String(format: "%.1fx", viewModel.iconScale))
                    .foregroundStyle(.secondary)
                    .frame(width: 40)
            }
            Slider(value: $viewModel.iconScale, in: 0.5...2.0, step: 0.1)

            HStack {
                Text("Cooldown")
                Spacer()
                Text(viewModel.cooldownSeconds == 0 ? "Off" : String(format: "%.1fs", viewModel.cooldownSeconds))
                    .foregroundStyle(.secondary)
                    .frame(width: 40)
            }
            Slider(value: $viewModel.cooldownSeconds, in: 0...10, step: 0.5)

            Toggle("Confirm Before Execute", isOn: $viewModel.confirmBeforeExecute)
        }
    }

    @ViewBuilder
    private var optionsSection: some View {
        Section("Options") {
            Toggle("Haptic Feedback", isOn: $viewModel.hapticFeedback)
            Toggle("Enabled", isOn: $viewModel.isEnabled)
        }
    }

    private func testAction() {
        let action = viewModel.selectedAction
        Task {
            let result = await ActionEngine.shared.executeLocal(action: action)
            testResult = result.isSuccess ? "✓ OK" : "⚠ \(result.displayText)"
        }
    }
}

private struct ActionPickerView: View {
    @Binding var selectedAction: ButtonAction
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            ForEach(ButtonAction.ActionCategory.allCases, id: \.self) { category in
                let actions = ButtonAction.allSimpleActions.filter { $0.category == category }
                if !actions.isEmpty {
                    Section(category.rawValue) {
                        ForEach(actions, id: \.displayName) { action in
                            Button {
                                selectedAction = action
                                dismiss()
                            } label: {
                                HStack {
                                    Image(systemName: action.systemImage)
                                        .foregroundStyle(.blue)
                                        .frame(width: 28)
                                    Text(action.displayName)
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    if action.displayName == selectedAction.displayName {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(.blue)
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Section("Custom") {
                actionButton(.openURL(url: ""), "Open URL")
                actionButton(.sendText(text: ""), "Send Text")
                actionButton(.openDeepLink(url: ""), "Open Deep Link")
                actionButton(.keyboardShortcut(modifiers: [], key: ""), "Keyboard Shortcut")
            }
        }
        .navigationTitle("Choose Action")
    }

    private func actionButton(_ action: ButtonAction, _ title: String) -> some View {
        Button {
            selectedAction = action
            dismiss()
        } label: {
            HStack {
                Image(systemName: action.systemImage)
                    .foregroundStyle(.blue).frame(width: 28)
                Text(title)
                    .foregroundStyle(.primary)
            }
        }
    }
}

private struct ModifierPicker: View {
    @Binding var selected: [String]

    private let modifiers = ["⌘ Cmd", "⌥ Option", "⇧ Shift", "⌃ Control"]
    private let keys = ["cmd", "option", "shift", "control"]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Modifiers")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(spacing: 8) {
                ForEach(0..<modifiers.count, id: \.self) { index in
                    let key = keys[index]
                    let isSelected = selected.contains(key)
                    Button {
                        if isSelected {
                            selected.removeAll { $0 == key }
                        } else {
                            selected.append(key)
                        }
                    } label: {
                        Text(modifiers[index])
                            .font(.caption.weight(.medium))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                Capsule().fill(isSelected ? Color.blue : Color(.systemGray5))
                            )
                            .foregroundStyle(isSelected ? .white : .primary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
