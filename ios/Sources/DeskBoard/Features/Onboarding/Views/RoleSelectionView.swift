import SwiftUI

struct RoleSelectionView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 32) {
            VStack(spacing: 8) {
                Text("Choose Your Role")
                    .font(.title.weight(.bold))
                Text("You can change this later in Settings.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 32)

            VStack(spacing: 16) {
                ForEach([DeviceRole.sender, DeviceRole.receiver], id: \.self) { role in
                    RoleCard(role: role) {
                        appState.setRole(role)
                    }
                }
            }
            .padding(.horizontal, 24)

            Spacer()
        }
        .navigationBarBackButtonHidden()
    }
}

// MARK: - RoleCard

private struct RoleCard: View {
    let role: DeviceRole
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(roleColor.opacity(0.15))
                        .frame(width: 56, height: 56)
                    Image(systemName: role.systemImage)
                        .font(.title2.weight(.medium))
                        .foregroundStyle(roleColor)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(role.title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(role.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
        }
        .buttonStyle(.plain)
    }

    private var roleColor: Color {
        switch role {
        case .sender:   return .blue
        case .receiver: return .green
        case .unset:    return .gray
        }
    }
}