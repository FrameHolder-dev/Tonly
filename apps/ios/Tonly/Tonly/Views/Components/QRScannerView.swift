import SwiftUI
import AVFoundation

struct QRScannerView: View {
    let onScan: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var torchOn = false
    @State private var permissionDenied = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if permissionDenied {
                VStack(spacing: 16) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(TonlyTheme.textSecondary)
                    Text("Camera access required")
                        .font(.headline)
                        .foregroundStyle(TonlyTheme.textPrimary)
                    Text("Go to Settings to allow camera access")
                        .font(.subheadline)
                        .foregroundStyle(TonlyTheme.textSecondary)
                    Button("Open Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                    .font(.headline)
                    .foregroundStyle(TonlyTheme.accent)
                }
            } else {
                CameraPreview(onScan: { value in
                    HapticService.notification(.success)
                    onScan(value)
                })
                .ignoresSafeArea()
            }

            VStack {
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)

                Spacer()

                Text("Scan QR Code")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)

                Spacer()

                RoundedRectangle(cornerRadius: 24)
                    .stroke(.white.opacity(0.6), lineWidth: 3)
                    .frame(width: 260, height: 260)

                Spacer()

                Button {
                    torchOn.toggle()
                    toggleTorch(torchOn)
                } label: {
                    Image(systemName: torchOn ? "flashlight.on.fill" : "flashlight.off.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(.white)
                        .frame(width: 56, height: 56)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                }
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            switch AVCaptureDevice.authorizationStatus(for: .video) {
            case .denied, .restricted:
                permissionDenied = true
            case .notDetermined:
                AVCaptureDevice.requestAccess(for: .video) { granted in
                    if !granted { permissionDenied = true }
                }
            default: break
            }
        }
    }

    private func toggleTorch(_ on: Bool) {
        guard let device = AVCaptureDevice.default(for: .video), device.hasTorch else { return }
        try? device.lockForConfiguration()
        device.torchMode = on ? .on : .off
        device.unlockForConfiguration()
    }
}

struct CameraPreview: UIViewRepresentable {
    let onScan: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onScan: onScan)
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        let session = AVCaptureSession()
        context.coordinator.session = session

        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device) else { return view }

        session.addInput(input)

        let output = AVCaptureMetadataOutput()
        session.addOutput(output)
        output.setMetadataObjectsDelegate(context.coordinator, queue: .main)
        output.metadataObjectTypes = [.qr]

        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = .resizeAspectFill
        preview.frame = UIScreen.main.bounds
        view.layer.addSublayer(preview)

        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
        }

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}

    class Coordinator: NSObject, AVCaptureMetadataOutputObjectsDelegate {
        let onScan: (String) -> Void
        var session: AVCaptureSession?
        var scanned = false

        init(onScan: @escaping (String) -> Void) {
            self.onScan = onScan
        }

        func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
            guard !scanned,
                  let obj = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
                  let value = obj.stringValue else { return }
            scanned = true
            session?.stopRunning()
            onScan(value)
        }
    }
}
