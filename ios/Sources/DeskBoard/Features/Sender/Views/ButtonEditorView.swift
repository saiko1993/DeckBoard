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
        .onChange(of: viewModel.selectedAction) { action in
            if action.isDangerousAction {
                viewModel.confirmBeforeExecute = true
            }
            if case .openApp(let selectedAppID) = action, !selectedAppID.trimmed.isEmpty {
                viewModel.appID = selectedAppID
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
                    Group {
                        switch viewModel.buttonShape {
                        case .roundedRectangle:
                            RoundedRectangle(cornerRadius: viewModel.cornerRadius, style: .continuous)
                                .fill(Color(hex: viewModel.colorHex) ?? .blue)
                        case .capsule:
                            Capsule()
                                .fill(Color(hex: viewModel.colorHex) ?? .blue)
                        case .circle:
                            Circle()
                                .fill(Color(hex: viewModel.colorHex) ?? .blue)
                        }
                    }
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
                ActionPickerView(
                    selectedAction: $viewModel.selectedAction,
                    onAutoFill: { appID in
                        viewModel.autoFillFromApp(appID: appID)
                    }
                )
            } label: {
                HStack {
                    Image(systemName: viewModel.selectedAction.systemImage)
                        .foregroundStyle(.blue)
                        .frame(width: 24)
                    Text(viewModel.selectedAction.displayName)
                }
            }

            HStack(spacing: 8) {
                Image(systemName: viewModel.selectedAction.requiresForegroundOnIOSReceiver
                      ? "exclamationmark.triangle.fill"
                      : "checkmark.shield.fill")
                    .foregroundStyle(viewModel.selectedAction.requiresForegroundOnIOSReceiver ? .orange : .green)
                Text(viewModel.selectedAction.backgroundExecutionHint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 2)
            if viewModel.selectedAction.requiresForegroundOnIOSReceiver {
                HStack(spacing: 8) {
                    Image(systemName: "desktopcomputer.and.arrow.down")
                        .foregroundStyle(.blue)
                    Text("Tip: Enable Mac Receiver Relay for reliable background execution.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
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

            if case .typeText = viewModel.selectedAction {
                TextField("Text to type on Mac", text: $viewModel.textPayload, axis: .vertical)
                    .lineLimit(1...4)
            }

            if case .openApp = viewModel.selectedAction {
                TextField("App ID (example: xcode)", text: $viewModel.appID)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Text("You can enter app IDs from the Mac catalog or bundle/app names the relay can open.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if case .runShortcut = viewModel.selectedAction {
                TextField("Shortcut Name", text: $viewModel.shortcutName)
                    .autocorrectionDisabled()
            }

            if case .runScript = viewModel.selectedAction {
                TextField("Script / Shortcut Name", text: $viewModel.shortcutName)
                    .autocorrectionDisabled()
            }

            if case .keyboardShortcut = viewModel.selectedAction {
                TextField("Key (example: k)", text: $viewModel.shortcutKey)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                HStack {
                    Text("Modifiers")
                    Spacer()
                    modifierToggle("cmd")
                    modifierToggle("shift")
                    modifierToggle("option")
                    modifierToggle("ctrl")
                }
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
            Picker("Button Shape", selection: $viewModel.buttonShape) {
                ForEach(DeskButtonShape.allCases, id: \.self) { shape in
                    Text(shape.title).tag(shape)
                }
            }

            Picker("Size Preset", selection: $viewModel.sizePreset) {
                ForEach(DeskButtonSizePreset.allCases, id: \.self) { preset in
                    Text(preset.title).tag(preset)
                }
            }

            Picker("Target Policy", selection: $viewModel.targetPolicy) {
                ForEach(ActionTargetPolicy.allCases, id: \.self) { policy in
                    Text(policy.title).tag(policy)
                }
            }

            Picker("Background Fallback", selection: $viewModel.backgroundFallback) {
                ForEach(BackgroundFallbackPolicy.allCases, id: \.self) { policy in
                    Text(policy.title).tag(policy)
                }
            }

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

            HStack {
                Text("Retry Count")
                Spacer()
                Text("\(Int(viewModel.retryCount.rounded()))")
                    .foregroundStyle(.secondary)
                    .frame(width: 30)
            }
            Slider(value: $viewModel.retryCount, in: 0...3, step: 1)

            HStack {
                Text("Timeout")
                Spacer()
                Text("\(Int(viewModel.timeoutSeconds.rounded()))s")
                    .foregroundStyle(.secondary)
                    .frame(width: 40)
            }
            Slider(value: $viewModel.timeoutSeconds, in: 5...30, step: 1)

            Toggle("Confirm Before Execute", isOn: $viewModel.confirmBeforeExecute)
            Toggle("Lock Drag in Freeform", isOn: $viewModel.dragLocked)
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
        let action = viewModel.resolvedAction
        Task {
            let result = await ActionEngine.shared.executeLocal(action: action)
            testResult = result.isSuccess ? "✓ OK" : "⚠ \(result.displayText)"
        }
    }

    @ViewBuilder
    private func modifierToggle(_ modifier: String) -> some View {
        let isSelected = viewModel.shortcutModifiers.contains(modifier)
        Button {
            if isSelected {
                viewModel.shortcutModifiers.removeAll { $0 == modifier }
            } else {
                viewModel.shortcutModifiers.append(modifier)
            }
        } label: {
            Text(modifier.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(isSelected ? .white : .primary)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(isSelected ? Color.blue : Color(.secondarySystemFill))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - ActionPickerView

struct ActionPickerView: View {
    @Binding var selectedAction: ButtonAction
    var onAutoFill: ((String) -> Void)?
    @Environment(\.dismiss) private var dismiss
    @State private var searchText: String = ""
    @StateObject private var catalog = ActionCatalogViewModel()

    var body: some View {
        List {
            if searchText.isEmpty {
                quickActionsSection
                capabilitySections
                appsSection
                advancedSection
            } else {
                filteredResults
            }
        }
        .searchable(text: $searchText, prompt: "Search actions & apps")
        .navigationTitle("Choose Action")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await catalog.refresh()
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if catalog.isLoading {
                    ProgressView()
                } else {
                    Button {
                        Task { await catalog.refresh() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var quickActionsSection: some View {
        Section {
            actionRow(for: .init(action: .none, source: .local, isRelayAdvertised: true), customTitle: "No Action")
            if let relaySummary = catalog.relaySummaryText {
                Text(relaySummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var capabilitySections: some View {
        ForEach(ButtonAction.ActionCategory.allCases, id: \.self) { category in
            let entries = catalog.templatesForCategory(category, includeDangerous: false)
            if !entries.isEmpty {
                Section(category.rawValue) {
                    ForEach(entries) { entry in
                        actionRow(for: entry, customTitle: nil)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var advancedSection: some View {
        let dangerous = catalog.dangerousTemplates
        if !dangerous.isEmpty {
            Section {
                ForEach(dangerous) { entry in
                    actionRow(for: entry, customTitle: nil)
                }
            } header: {
                Text("Advanced Actions")
            } footer: {
                Text("Dangerous actions always default to confirmation.")
            }
        }
    }

    @ViewBuilder
    private var appsSection: some View {
        Section("Open App") {
            ForEach(AppCategory.allCases, id: \.self) { category in
                let apps = AppCatalog.apps(for: category)
                if !apps.isEmpty {
                    NavigationLink {
                        AppCategoryPickerView(
                            category: category,
                            apps: apps,
                            selectedAction: $selectedAction,
                            onAutoFill: onAutoFill
                        )
                    } label: {
                        Label(category.rawValue, systemImage: category.systemImage)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var filteredResults: some View {
        let matchingActions = catalog.templates.filter { $0.title.localizedStandardContains(searchText) }
        let matchingApps = AppCatalog.search(searchText)

        if !matchingActions.isEmpty {
            Section("Actions") {
                ForEach(matchingActions) { entry in
                    actionRow(for: entry, customTitle: nil)
                }
            }
        }

        if !matchingApps.isEmpty {
            Section("Apps") {
                ForEach(matchingApps) { app in
                    appRow(app)
                }
            }
        }

        if matchingActions.isEmpty && matchingApps.isEmpty {
            Section {
                VStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    Text("No results for \"\(searchText)\"")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .listRowBackground(Color.clear)
            }
        }
    }

    private func actionRow(for entry: ActionTemplateEntry, customTitle: String?) -> some View {
        let action = entry.action
        return Button {
            selectedAction = action
            dismiss()
        } label: {
            HStack {
                Image(systemName: action.systemImage)
                    .foregroundStyle(.blue)
                    .frame(width: 28)
                Text(customTitle ?? entry.title)
                    .foregroundStyle(.primary)
                Spacer()
                if entry.source == .relay {
                    badge("Relay", color: .blue)
                } else if action.isSupportedOnIOS {
                    badge("iOS", color: .green)
                }
                if action.requiresForegroundOnIOSReceiver {
                    badge("FG", color: .orange)
                }
                if selectedAction.relayKind == action.relayKind {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.blue)
                }
            }
        }
    }

    private func badge(_ title: String, color: Color) -> some View {
        Text(title)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }

    private func appRow(_ app: AppShortcut) -> some View {
        Button {
            selectedAction = .openApp(appID: app.id)
            onAutoFill?(app.id)
            dismiss()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: app.icon)
                    .font(.body)
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color(hex: app.colorHex) ?? .blue)
                )
                Text(app.name)
                    .foregroundStyle(.primary)
                Spacer()
                badge("FG", color: .orange)
                if case .openApp(let id) = selectedAction, id == app.id {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.blue)
                }
            }
        }
    }
}

// MARK: - AppCategoryPickerView

private struct AppCategoryPickerView: View {
    let category: AppCategory
    let apps: [AppShortcut]
    @Binding var selectedAction: ButtonAction
    var onAutoFill: ((String) -> Void)?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            ForEach(apps) { app in
                Button {
                    selectedAction = .openApp(appID: app.id)
                    onAutoFill?(app.id)
                    dismiss()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: app.icon)
                            .font(.body)
                            .foregroundStyle(.white)
                            .frame(width: 36, height: 36)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(Color(hex: app.colorHex) ?? .blue)
                            )
                        VStack(alignment: .leading, spacing: 2) {
                            Text(app.name)
                                .font(.body)
                                .foregroundStyle(.primary)
                            Text(app.urlScheme)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("FG")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.orange)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.12))
                            .clipShape(Capsule())
                        if case .openApp(let id) = selectedAction, id == app.id {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.blue)
                        }
                    }
                }
            }
        }
        .navigationTitle(category.rawValue)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Action Catalog

private struct ActionTemplateEntry: Identifiable, Hashable {
    let id: String
    let action: ButtonAction
    let title: String
    let source: ActionTemplateSource
    let isRelayAdvertised: Bool
    let isDangerous: Bool

    init(
        action: ButtonAction,
        source: ActionTemplateSource,
        isRelayAdvertised: Bool,
        title: String? = nil,
        isDangerous: Bool? = nil
    ) {
        self.id = "\(action.relayKind)|\(source.rawValue)"
        self.action = action
        self.title = title ?? action.displayName
        self.source = source
        self.isRelayAdvertised = isRelayAdvertised
        self.isDangerous = isDangerous ?? action.isDangerousAction
    }
}

private enum ActionTemplateSource: String {
    case relay
    case local
}

private struct RelayCapabilitiesPayload: Codable {
    let ok: Bool
    let service: String?
    let serviceVersion: String?
    let protocolVersion: Int?
    let capabilities: [String]
    let metadata: [String: RelayCapabilityMetadata]?
}

private struct RelayCapabilityMetadata: Codable {
    let category: String?
    let foregroundRequired: Bool?
    let dangerLevel: String?
}

@MainActor
private final class ActionCatalogViewModel: ObservableObject {
    @Published private(set) var templates: [ActionTemplateEntry] = []
    @Published private(set) var isLoading = false
    @Published private(set) var relaySummaryText: String?

    init() {
        templates = Self.fallbackTemplates()
    }

    var dangerousTemplates: [ActionTemplateEntry] {
        templates
            .filter { $0.isDangerous && $0.action.relayKind != "none" }
            .sorted { $0.title < $1.title }
    }

    func templatesForCategory(
        _ category: ButtonAction.ActionCategory,
        includeDangerous: Bool
    ) -> [ActionTemplateEntry] {
        templates
            .filter {
                $0.action.category == category &&
                $0.action.relayKind != "none" &&
                (includeDangerous || !$0.isDangerous)
            }
            .sorted { $0.title < $1.title }
    }

    func refresh() async {
        let fallback = Self.fallbackTemplates()
        guard AppConfiguration.backgroundRelayEnabled,
              let relayURL = AppConfiguration.backgroundRelayBaseURL else {
            templates = fallback
            relaySummaryText = "Using local catalog (relay not configured)."
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            var request = URLRequest(url: relayURL.appendingPathComponent("v1/capabilities"))
            request.httpMethod = "GET"
            if let key = AppConfiguration.backgroundRelayAPIKey?.trimmed, !key.isEmpty {
                request.setValue(key, forHTTPHeaderField: "x-deskboard-key")
            }

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                templates = fallback
                relaySummaryText = "Using local catalog (relay unavailable)."
                return
            }

            let payload = try JSONDecoder().decode(RelayCapabilitiesPayload.self, from: data)
            let mapped = Self.templatesFromRelayCapabilities(payload.capabilities, metadata: payload.metadata)
            templates = Self.mergeTemplates(local: fallback, relay: mapped)
            relaySummaryText = "Relay online: \(payload.capabilities.count) capabilities"
        } catch {
            templates = fallback
            relaySummaryText = "Using local catalog (relay request failed)."
        }
    }

    private static func mergeTemplates(
        local: [ActionTemplateEntry],
        relay: [ActionTemplateEntry]
    ) -> [ActionTemplateEntry] {
        var map: [String: ActionTemplateEntry] = [:]
        for entry in local {
            map[entry.action.relayKind] = entry
        }
        for entry in relay {
            map[entry.action.relayKind] = entry
        }
        return map.values.sorted { $0.title < $1.title }
    }

    private static func templatesFromRelayCapabilities(
        _ capabilities: [String],
        metadata: [String: RelayCapabilityMetadata]?
    ) -> [ActionTemplateEntry] {
        capabilities.compactMap { capabilityKind in
            guard let action = relayKindToAction(capabilityKind) else { return nil }
            let dangerFromMetadata: Bool? = {
                guard let raw = metadata?[capabilityKind]?.dangerLevel?.lowercased() else { return nil }
                return raw == "high" || raw == "dangerous" || raw == "critical"
            }()
            return ActionTemplateEntry(
                action: action,
                source: .relay,
                isRelayAdvertised: true,
                isDangerous: dangerFromMetadata
            )
        }
    }

    private static func fallbackTemplates() -> [ActionTemplateEntry] {
        let actions: [ButtonAction] = [
            .none,
            .openURL(url: ""),
            .openDeepLink(url: ""),
            .sendText(text: ""),
            .typeText(text: ""),
            .openApp(appID: ""),
            .mediaPlay,
            .mediaPause,
            .mediaPlayPause,
            .mediaNext,
            .mediaPrevious,
            .mediaVolumeUp,
            .mediaVolumeDown,
            .mediaMute,
            .brightnessUp,
            .brightnessDown,
            .presentationNext,
            .presentationPrevious,
            .presentationStart,
            .presentationEnd,
            .runShortcut(name: ""),
            .runScript(name: ""),
            .keyboardShortcut(modifiers: ["cmd"], key: ""),
            .openTerminal,
            .toggleDarkMode,
            .screenshot,
            .screenRecord,
            .toggleDoNotDisturb,
            .sleepDisplay,
            .lockScreen,
            .forceQuitApp,
            .emptyTrash,
            .appSwitchNext,
            .appSwitchPrevious,
            .closeWindow,
            .quitFrontApp,
            .minimizeWindow,
            .missionControl,
            .showDesktop,
            .moveSpaceLeft,
            .moveSpaceRight
        ]
        return actions.map { ActionTemplateEntry(action: $0, source: .local, isRelayAdvertised: false) }
    }

    private static func relayKindToAction(_ kind: String) -> ButtonAction? {
        switch kind {
        case "open_url":
            return .openURL(url: "")
        case "open_deep_link":
            return .openDeepLink(url: "")
        case "send_text":
            return .sendText(text: "")
        case "type_text":
            return .typeText(text: "")
        case "open_app":
            return .openApp(appID: "")
        case "run_shortcut":
            return .runShortcut(name: "")
        case "run_script":
            return .runScript(name: "")
        case "keyboard_shortcut":
            return .keyboardShortcut(modifiers: ["cmd"], key: "")
        case "toggle_dark_mode":
            return .toggleDarkMode
        case "screenshot":
            return .screenshot
        case "screen_record":
            return .screenRecord
        case "sleep_display":
            return .sleepDisplay
        case "lock_screen":
            return .lockScreen
        case "open_terminal":
            return .openTerminal
        case "force_quit_app":
            return .forceQuitApp
        case "empty_trash":
            return .emptyTrash
        case "toggle_dnd":
            return .toggleDoNotDisturb
        case "presentation_next":
            return .presentationNext
        case "presentation_previous":
            return .presentationPrevious
        case "presentation_start":
            return .presentationStart
        case "presentation_end":
            return .presentationEnd
        case "media_play":
            return .mediaPlay
        case "media_pause":
            return .mediaPause
        case "media_play_pause":
            return .mediaPlayPause
        case "media_next":
            return .mediaNext
        case "media_previous":
            return .mediaPrevious
        case "media_volume_up":
            return .mediaVolumeUp
        case "media_volume_down":
            return .mediaVolumeDown
        case "media_mute":
            return .mediaMute
        case "app_switch_next":
            return .appSwitchNext
        case "app_switch_previous":
            return .appSwitchPrevious
        case "close_window":
            return .closeWindow
        case "quit_front_app":
            return .quitFrontApp
        case "minimize_window":
            return .minimizeWindow
        case "mission_control":
            return .missionControl
        case "show_desktop":
            return .showDesktop
        case "move_space_left":
            return .moveSpaceLeft
        case "move_space_right":
            return .moveSpaceRight
        case "macro":
            return .macro(actions: [])
        default:
            return nil
        }
    }
}
