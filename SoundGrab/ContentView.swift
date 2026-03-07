import SwiftUI

struct ContentView: View {
    @State private var viewModel = ConverterViewModel()
    @State private var isPasting: Bool = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    headerSection
                    inputSection
                    if !viewModel.items.isEmpty {
                        queueSection
                    } else {
                        emptyStateView
                    }
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("SoundGrab")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if !viewModel.completedItems.isEmpty {
                        Button("Clear") {
                            withAnimation(.snappy) {
                                viewModel.clearCompleted()
                            }
                        }
                        .font(.subheadline)
                    }
                }
            }
            .alert("Error", isPresented: $viewModel.showingError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage)
            }
            .sheet(isPresented: $viewModel.showingShareSheet) {
                if let url = viewModel.shareURL {
                    ShareSheet(items: [url])
                }
            }
        }
    }

    private var headerSection: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.purple.opacity(0.7), Color.blue.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 64, height: 64)

                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(.white)
                    .symbolEffect(.pulse, options: .repeating, isActive: viewModel.hasActiveDownloads)
            }

            Text("YouTube to MP3")
                .font(.title3.weight(.semibold))

            Text("Paste a YouTube link to extract audio")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 12)
        .padding(.bottom, 20)
    }

    private var inputSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "link")
                    .foregroundStyle(.secondary)
                    .font(.body)

                TextField("youtube.com/watch?v=...", text: $viewModel.urlText)
                    .textContentType(.URL)
                    .keyboardType(.URL)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .submitLabel(.go)
                    .onSubmit {
                        withAnimation(.snappy) {
                            viewModel.addAndProcess()
                        }
                    }

                if !viewModel.urlText.isEmpty {
                    Button {
                        viewModel.urlText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(.rect(cornerRadius: 12))

            HStack(spacing: 10) {
                Button {
                    if let clipboardString = UIPasteboard.general.string {
                        viewModel.urlText = clipboardString
                    }
                } label: {
                    Label("Paste", systemImage: "doc.on.clipboard")
                        .font(.subheadline.weight(.medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.bordered)
                .tint(.secondary)

                Button {
                    withAnimation(.snappy) {
                        viewModel.addAndProcess()
                    }
                } label: {
                    Label("Convert", systemImage: "arrow.down.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.urlText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 24)
    }

    private var queueSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Downloads")
                .font(.headline)
                .padding(.horizontal, 16)
                .padding(.bottom, 12)

            LazyVStack(spacing: 0) {
                ForEach(viewModel.items) { item in
                    DownloadItemRow(
                        item: item,
                        onRetry: { viewModel.retryItem(item) },
                        onRemove: {
                            withAnimation(.snappy) {
                                viewModel.removeItem(item)
                            }
                        },
                        onShare: { url in viewModel.shareFile(at: url) }
                    )
                    .padding(.horizontal, 16)

                    if item.id != viewModel.items.last?.id {
                        Divider()
                            .padding(.leading, 110)
                    }
                }
            }
            .padding(.vertical, 8)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(.rect(cornerRadius: 16))
            .padding(.horizontal, 16)
        }
        .padding(.bottom, 24)
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "headphones.circle")
                .font(.system(size: 48))
                .foregroundStyle(.quaternary)

            VStack(spacing: 4) {
                Text("No Downloads Yet")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)

                Text("Enter a YouTube link above to get started")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }
}

