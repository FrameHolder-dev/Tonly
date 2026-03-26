import Foundation

@Observable
final class WebSocketClient {
    static let shared = WebSocketClient()

    private var webSocket: URLSessionWebSocketTask?
    private let session = URLSession(configuration: .default)
    private let url = URL(string: "wss://ws.tonly.one")!

    var isConnected = false

    private init() {}

    func connect() {
        webSocket = session.webSocketTask(with: url)
        webSocket?.resume()
        isConnected = true
        listen()
    }

    func disconnect() {
        webSocket?.cancel(with: .goingAway, reason: nil)
        isConnected = false
    }

    func send(_ message: String) async throws {
        try await webSocket?.send(.string(message))
    }

    private func listen() {
        webSocket?.receive { [weak self] result in
            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    NotificationCenter.default.post(
                        name: .webSocketMessage,
                        object: nil,
                        userInfo: ["message": text]
                    )
                default:
                    break
                }
                self?.listen()
            case .failure:
                self?.isConnected = false
            }
        }
    }
}

extension Notification.Name {
    static let webSocketMessage = Notification.Name("webSocketMessage")
}
