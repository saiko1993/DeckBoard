import SwiftUI

struct DownloadItemRow: View {
    let item: DownloadItem
    let onRetry: () -> Void
    let onRemove: () -> Void
    let onShare: (URL) -> Void

    var body: some View {
        HStack(spacing: 14) {
            thumbnailView

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)

                if let duration = item.duration {
                    Text(duration)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                statusView
            }

            Spacer(minLength: 0)

            actionButton
        }
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var thumbnailView: some View {
        if let url = item.thumbnailURL {
            Color(.secondarySystemBackground)
                .frame(width: 80, height: 56)
                .overlay {
                    AsyncImage(url: url) { phase in
                        if let image = phase.image {
                            image.resizable().aspectRatio(contentMode: .fill)
                                .allowsHitTesting(false)
                        }
                    }
                }
                .clipShape(.rect(cornerRadius: 8))
        } else {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.tertiarySystemBackground))
                .frame(width: 80, height: 56)
                .overlay {
                    Image(systemName: "music.note")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
        }
    }

    @ViewBuilder
    private var statusView: some View {
        switch item.status {
        case .idle:
            Text("Waiting...")
                .font(.caption)
                .foregroundStyle(.secondary)
        case .extracting:
            HStack(spacing: 6) {
                ProgressView()
                    .controlSize(.mini)
                Text("Extracting audio...")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        case .downloading(let progress):
            VStack(alignment: .leading, spacing: 2) {
                ProgressView(value: progress)
                    .tint(.blue)
                Text("Downloading \(Int(progress * 100))%")
                    .font(.caption)
                    .foregroundStyle(.blue)
            }
        case .converting:
            HStack(spacing: 6) {
                ProgressView()
                    .controlSize(.mini)
                Text("Converting to MP3...")
                    .font(.caption)
                    .foregroundStyle(.purple)
            }
        case .completed:
            Label("Complete", systemImage: "checkmark.circle.fill")
                .font(.caption.weight(.medium))
                .foregroundStyle(.green)
        case .failed(let message):
            Text(message)
                .font(.caption)
                .foregroundStyle(.red)
                .lineLimit(2)
        }
    }

    @ViewBuilder
    private var actionButton: some View {
        switch item.status {
        case .completed(let fileURL):
            HStack(spacing: 12) {
                Button { onShare(fileURL) } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.body.weight(.medium))
                        .foregroundStyle(.blue)
                }
                Button(role: .destructive) { onRemove() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
            }
        case .failed:
            HStack(spacing: 12) {
                Button { onRetry() } label: {
                    Image(systemName: "arrow.clockwise.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.orange)
                }
                Button(role: .destructive) { onRemove() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
            }
        case .idle, .extracting, .downloading, .converting:
            EmptyView()
        }
    }
}
