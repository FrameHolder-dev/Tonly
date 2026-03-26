import SwiftUI
import CoreImage.CIFilterBuiltins

struct ReceiveView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var store = WalletStore.shared
    @State private var copied = false
    @State private var qrImage: UIImage?

    var body: some View {
        NavigationStack {
            VStack(spacing: 28) {
                Spacer()

                if let address = store.activeAddress {
                    if let qr = qrImage {
                        Image(uiImage: qr)
                            .interpolation(.none)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 200, height: 200)
                            .padding(24)
                            .background(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                    } else {
                        ProgressView()
                            .frame(width: 200, height: 200)
                    }

                    VStack(spacing: 6) {
                        Text("Your TON Address")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(TonlyTheme.textSecondary)

                        Text(address)
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(TonlyTheme.textPrimary)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .padding(.horizontal, 40)
                    }

                    HStack(spacing: 12) {
                        Button {
                            UIPasteboard.general.string = address
                            copied = true
                            HapticService.notification(.success)
                            Task {
                                try? await Task.sleep(for: .seconds(2))
                                copied = false
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: copied ? "checkmark" : "doc.on.doc")
                                Text(copied ? "Copied" : "Copy")
                            }
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(TonlyTheme.accent)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: TonlyTheme.cornerRadius))
                        }

                        ShareLink(item: address) {
                            HStack(spacing: 8) {
                                Image(systemName: "square.and.arrow.up")
                                Text("Share")
                            }
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(TonlyTheme.surface)
                            .foregroundStyle(TonlyTheme.textPrimary)
                            .clipShape(RoundedRectangle(cornerRadius: TonlyTheme.cornerRadius))
                        }
                    }
                    .padding(.horizontal, TonlyTheme.padding)
                }

                Spacer()
            }
            .background(TonlyTheme.background)
            .navigationTitle("Receive")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(TonlyTheme.textSecondary)
                    }
                }
            }
            .onAppear {
                if let address = store.activeAddress {
                    qrImage = generateQR(for: address)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func generateQR(for string: String) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage,
              let cgImage = context.createCGImage(output, from: output.extent) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }
}
