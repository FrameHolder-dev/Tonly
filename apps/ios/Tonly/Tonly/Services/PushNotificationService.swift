import Foundation
import UserNotifications
import UIKit

struct PushNotificationService {
    static func requestPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            if granted {
                await MainActor.run {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
            return granted
        } catch {
            return false
        }
    }

    static func registerToken(_ deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        UserDefaults.standard.set(token, forKey: "apns_token")
        sendTokenToServer(token)
    }

    static var currentToken: String? {
        UserDefaults.standard.string(forKey: "apns_token")
    }

    static func sendTokenToServer(_ token: String) {
        let address = WalletStore.shared.activeAddress ?? ""
        guard !token.isEmpty else { return }

        Task {
            struct Response: Decodable { let status: String }
            let _: Response? = try? await APIClient.shared.request(
                Endpoint(
                    path: "/push/register",
                    method: .post,
                    body: ["token": token, "address": address]
                )
            )
        }
    }
}
