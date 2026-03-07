import SwiftUI

// MARK: - ButtonEditorView

struct ButtonEditorView: View {
    enum Mode {
        case add
        case edit(DeskButton)
    }

    let mode: Mode
    let onSave: (DeskButton) -> Void

    @StateObject private var viewModel: ButtonEditorViewModel
    @Environment(\.dismiss) private var dismiss

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
                // MARK: Preview
                Section {
                    HStack {
                        Spacer()
                        VStack(spacing: 8) {
                            Image(systemName: viewModel.icon)
                                .font(.system(size: 36, weight: .medium))
                                .foregroundStyle(.white)
                            Text(viewModel.title.isEmpty ? "Button" : viewModel.title)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white)
                        }
                        .frame(width: 90, height: 90)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(Color(hex: viewModel.colorHex) ?? .blue)
                        )
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                }

                // MARK: Title
                Section("Label") {
                    TextField("Button Title", text: $viewModel.title)
                }

                // MARK: Icon
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

                // MARK: Color
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

                // MARK: Action
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

                    // URL input
                    if case .openURL = viewModel.selectedAction {
                        TextField("https://example.com", text: $viewModel.urlText)
                            .keyboardType(.URL)
                            .autocorrectionDisabled()
                    }

                    // Deep link input
                    if case .openDeepLink = viewModel.selectedAction {
                        TextField("app://path", text: $viewModel.urlText)
                            .keyboardType(.URL)
                            .autocorrectionDisabled()
                    }

                    // Text input
                    if case .sendText = viewModel.selectedAction {
                        TextField("Text to send", text: $viewModel.textPayload)
                    }

                    // Keyboard shortcut input
                    if case .keyboardShortcut = viewModel.selectedAction {
                        TextField("Key (e.g. c, space, return)", text: $viewModel.shortcutKey)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                        Text("Modifiers: \(viewModel.shortcutModifiers.isEmpty ? "None" : viewModel.shortcutModifiers.joined(separator: "+"))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                // MARK: Icon URL
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
                                            image
                                                .resizable()
                                                .aspectRatio(contentMode: .fit)
                                                .allowsHitTesting(false)
                                        case .failure:
                                            Image(systemName: "exclamationmark.triangle")
                                                .foregroundStyle(.orange)
                                        default:
                                            ProgressView()
                                        }
                                    }
                                }
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            Spacer()
                        }
                    }
                }

                // MARK: Options
                Section("Options") {
                    Toggle("Haptic Feedback", isOn: $viewModel.hapticFeedback)
                    Toggle("Enabled", isOn: $viewModel.isEnabled)
                }
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
}

// MARK: - ActionPickerView

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
                Button {
                    selectedAction = .openURL(url: "")
                    dismiss()
                } label: {
                    HStack {
                        Image(systemName: ButtonAction.openURL(url: "").systemImage)
                            .foregroundStyle(.blue).frame(width: 28)
                        Text("Open URL")
                            .foregroundStyle(.primary)
                    }
                }
                Button {
                    selectedAction = .sendText(text: "")
                    dismiss()
                } label: {
                    HStack {
                        Image(systemName: ButtonAction.sendText(text: "").systemImage)
                            .foregroundStyle(.blue).frame(width: 28)
                        Text("Send Text")
                            .foregroundStyle(.primary)
                    }
                }
                Button {
                    selectedAction = .openDeepLink(url: "")
                    dismiss()
                } label: {
                    HStack {
                        Image(systemName: ButtonAction.openDeepLink(url: "").systemImage)
                            .foregroundStyle(.blue).frame(width: 28)
                        Text("Open Deep Link")
                            .foregroundStyle(.primary)
                    }
                }
                Button {
                    selectedAction = .keyboardShortcut(modifiers: [], key: "")
                    dismiss()
                } label: {
                    HStack {
                        Image(systemName: ButtonAction.keyboardShortcut(modifiers: [], key: "").systemImage)
                            .foregroundStyle(.blue).frame(width: 28)
                        Text("Keyboard Shortcut")
                            .foregroundStyle(.primary)
                    }
                }
            }
        }
        .navigationTitle("Choose Action")
    }
}