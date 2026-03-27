import SwiftUI

struct NearbyDevicesView: View {
    let peers: [DiscoveredPeer]
    let onConnect: (DiscoveredPeer) -> Void

    var body: some View {
        if peers.isEmpty {
            HStack {
                ProgressView()
                    .scaleEffect(0.8)
                Text("Searching for receivers…")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 8)
        } else {
            ForEach(peers) { peer in
                Button {
                    onConnect(peer)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: peer.role?.systemImage ?? "iphone")
                            .foregroundStyle(.blue)
                            .frame(width: 28)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(peer.displayName)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.primary)
                            Text(peer.role?.title ?? "Unknown role")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }
}