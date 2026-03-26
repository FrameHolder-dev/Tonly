import SwiftUI

@main
struct TonlyApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @State private var connectRequest: TonConnectRequest?
    @State private var showConnect = false

    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(.dark)
                .task {
                    _ = await PushNotificationService.requestPermission()
                }
                .onOpenURL { url in
                    handleDeeplink(url)
                }
                .sheet(isPresented: $showConnect) {
                    if let request = connectRequest {
                        TonConnectSheet(request: request) {
                            showConnect = false
                        }
                    }
                }
        }
    }

    private func handleDeeplink(_ url: URL) {
        if let request = TonConnectManager.parseURL(url) {
            connectRequest = request
            showConnect = true
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        PushNotificationService.registerToken(deviceToken)
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {}
}
