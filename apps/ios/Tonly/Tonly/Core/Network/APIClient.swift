import Foundation

enum APIError: Error {
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case decodingError
    case networkError(Error)
    case serverUnavailable
}

struct HealthResponse: Decodable {
    let status: String
}

actor APIClient {
    static let shared = APIClient()

    private let host = "https://api.tonly.one"
    private let basePath = "/api/v1"
    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        self.session = URLSession(configuration: config)
    }

    func checkHealth() async -> Bool {
        guard let url = URL(string: host + "/health") else { return false }
        do {
            let (data, response) = try await session.data(for: URLRequest(url: url))
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return false }
            let health = try JSONDecoder().decode(HealthResponse.self, from: data)
            return health.status == "ok"
        } catch {
            return false
        }
    }

    func waitForAPI() async {
        for _ in 0..<5 {
            if await checkHealth() { return }
            try? await Task.sleep(for: .seconds(2))
        }
    }

    func request<T: Decodable>(_ endpoint: Endpoint) async throws -> T {
        guard let url = URL(string: host + basePath + endpoint.path) else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let body = endpoint.body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.httpError(httpResponse.statusCode)
        }

        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw APIError.decodingError
        }
    }
}
