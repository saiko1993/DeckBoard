import SwiftUI
import CoreImage.CIFilterBuiltins

// MARK: - QRCodePairingView

struct QRCodePairingView: View {
    let pairingCode: String

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 16) {
                Text("Scan to Pair")
                    .font(.title2.weight(.bold))
                Text("Scan this QR code from the other device to pair instantly.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            if let qrImage = generateQRCode(from: pairingCode) {
                Image(uiImage: qrImage)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 220, height: 220)
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(.white)
                    )
            }

            Text(pairingCode)
                .font(.system(.title3, design: .monospaced).weight(.bold))
                .tracking(4)
                .foregroundStyle(.primary)

            Spacer()
        }
        .navigationTitle("QR Code")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - QR Code Generation

    private func generateQRCode(from string: String) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        let data = Data(string.utf8)
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("H", forKey: "inputCorrectionLevel")

        guard let outputImage = filter.outputImage else { return nil }
        let scaled = outputImage.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}

// MARK: - PairingCodeView

struct PairingCodeView: View {
    let code: String
    let onRefresh: () -> Void

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.1))
                        .frame(width: 100, height: 100)
                    Image(systemName: "number.circle.fill")
                        .font(.system(size: 52, weight: .light))
                        .foregroundStyle(.blue)
                }

                Text("Pairing Code")
                    .font(.title2.weight(.bold))
                Text("Enter this code on the other device to connect.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Text(code)
                .font(.system(size: 48, design: .monospaced).weight(.bold))
                .tracking(6)
                .kerning(4)
                .foregroundStyle(.primary)

            Button {
                onRefresh()
            } label: {
                Label("Generate New Code", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)

            Spacer()
        }
        .navigationTitle("Pairing Code")
        .navigationBarTitleDisplayMode(.inline)
    }
}