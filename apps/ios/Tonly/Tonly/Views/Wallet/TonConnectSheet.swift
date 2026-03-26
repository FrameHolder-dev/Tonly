import SwiftUI

struct TonConnectSheet: View {
    let request: TonConnectRequest
    let onDismiss: () -> Void
    @State private var appName = ""
    @State private var appIcon: URL?
    @State private var isConnecting = false
    @State private var error: String?
    @State private var store = WalletStore.shared

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                if let icon = appIcon {
                    AsyncImage(url: icon) { img in
                        img.resizable().scaledToFit()
                    } placeholder: {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(TonlyTheme.surfaceLight)
                    }
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }

                VStack(spacing: 8) {
                    Text("Connect to \(appName.isEmpty ? "dApp" : appName)")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(TonlyTheme.textPrimary)

                    Text(request.manifestURL)
                        .font(.caption)
                        .foregroundStyle(TonlyTheme.textSecondary)
                        .lineLimit(1)
                }

                VStack(spacing: 12) {
                    infoRow("Wallet", value: store.activeAddress?.shortAddress ?? "")
                    infoRow("Network", value: "TON Mainnet")

                    if request.items.contains(where: { $0.name == "ton_proof" }) {
                        infoRow("Proof", value: "Signature required")
                    }
                }
                .padding(16)
                .background(TonlyTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: TonlyTheme.cornerRadius))
                .padding(.horizontal, TonlyTheme.padding)

                if let error {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(TonlyTheme.destructive)
                }

                Spacer()

                VStack(spacing: 12) {
                    Button {
                        connect()
                    } label: {
                        Group {
                            if isConnecting {
                                ProgressView().tint(.white)
                            } else {
                                Text("Connect")
                                    .font(.headline)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(TonlyTheme.accent)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: TonlyTheme.cornerRadius))
                    }
                    .disabled(isConnecting)

                    Button {
                        onDismiss()
                    } label: {
                        Text("Cancel")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(TonlyTheme.surface)
                            .foregroundStyle(TonlyTheme.textPrimary)
                            .clipShape(RoundedRectangle(cornerRadius: TonlyTheme.cornerRadius))
                    }
                }
                .padding(.horizontal, TonlyTheme.padding)
                .padding(.bottom, 16)
            }
            .background(TonlyTheme.background)
            .navigationTitle("TON Connect")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { onDismiss() } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(TonlyTheme.textSecondary)
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
        .task {
            await loadManifest()
        }
    }

    private func loadManifest() async {
        guard let url = URL(string: request.manifestURL) else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                appName = json["name"] as? String ?? ""
                if let iconStr = json["iconUrl"] as? String {
                    appIcon = URL(string: iconStr)
                }
            }
        } catch {}
    }

    private func connect() {
        isConnecting = true
        error = nil
        HapticService.impact()

        Task {
            let auth = await BiometricService.authenticate(reason: "Connect to \(appName)")
            guard auth else {
                error = "Authentication failed"
                isConnecting = false
                return
            }

            do {
                let response = try TonConnectManager.buildResponse(request: request)
                let responseData = try JSONSerialization.data(withJSONObject: response)
                let responseString = String(data: responseData, encoding: .utf8) ?? ""

                let bridgeURL = "https://api.tonly.one/api/v1/bridge?client_id=tonly&to=\(request.clientID)"
                var req = URLRequest(url: URL(string: bridgeURL)!)
                req.httpMethod = "POST"
                req.setValue("application/json", forHTTPHeaderField: "Content-Type")
                req.httpBody = try JSONSerialization.data(withJSONObject: [
                    "from": "tonly",
                    "message": responseString
                ])

                let (_, resp) = try await URLSession.shared.data(for: req)
                if let http = resp as? HTTPURLResponse, http.statusCode == 200 {
                    HapticService.notification(.success)
                    onDismiss()
                } else {
                    error = "Failed to send response"
                }
            } catch {
                self.error = "Connection failed: \(error.localizedDescription)"
            }

            isConnecting = false
        }
    }

    private func infoRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(TonlyTheme.textSecondary)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(TonlyTheme.textPrimary)
        }
    }
}
