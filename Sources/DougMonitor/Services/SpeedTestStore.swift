// Copyright © 2026 Douglas Almeida dos Santos. Todos os direitos reservados.
import Combine
import Foundation

struct SpeedTestResult: Sendable {
    let downloadBytesPerSecond: Double
    let uploadBytesPerSecond: Double
    let httpLatencyMilliseconds: Double
    let completedAt: Date
}

@MainActor
final class SpeedTestStore: ObservableObject {
    enum Phase: String {
        case idle = ""
        case latency = "Verificando resposta…"
        case download = "Medindo download…"
        case upload = "Medindo upload…"
    }
    @Published private(set) var phase = Phase.idle
    @Published private(set) var result: SpeedTestResult?
    @Published private(set) var errorMessage: String?
    private var task: Task<Void, Never>?
    private var session: URLSession?
    var isRunning: Bool { phase != .idle }

    func start() {
        guard !isRunning else { return }
        result = nil
        errorMessage = nil
        phase = .latency
        let config = URLSessionConfiguration.ephemeral
        config.urlCache = nil
        config.httpCookieStorage = nil
        config.urlCredentialStorage = nil
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 45
        config.waitsForConnectivity = false
        let testSession = URLSession(configuration: config)
        session = testSession
        task = Task { [weak self] in
            guard let self else { return }
            defer {
                testSession.invalidateAndCancel()
                session = nil; phase = .idle; task = nil
            }
            do {
                // Three tiny requests warm the connection and measure HTTP round trips.
                var latencies: [Double] = []
                for _ in 0..<3 {
                    try Task.checkCancellation()
                    let start = ProcessInfo.processInfo.systemUptime
                    let (_, response) = try await testSession.data(for: Self.request(bytes: 0))
                    try Self.validate(response)
                    latencies.append((ProcessInfo.processInfo.systemUptime - start) * 1_000)
                }
                let latency = latencies.sorted()[1]
                try Task.checkCancellation()
                phase = .download
                let down = TransferProbe(direction: .download)
                let downloadRate = try await down.measure(request: Self.request(bytes: 50_000_000))
                try Task.checkCancellation()
                phase = .upload
                var upload = Self.request(bytes: nil)
                upload.httpMethod = "POST"
                upload.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
                upload.httpBody = Data(repeating: 0, count: 10_000_000)
                let up = TransferProbe(direction: .upload)
                let uploadRate = try await up.measure(request: upload)
                try Task.checkCancellation()
                result = SpeedTestResult(downloadBytesPerSecond: downloadRate,
                                         uploadBytesPerSecond: uploadRate,
                                         httpLatencyMilliseconds: latency, completedAt: Date())
            } catch {
                if Task.isCancelled || (error as? URLError)?.code == .cancelled {
                    errorMessage = "Teste cancelado."
                } else if (error as? URLError)?.code == .timedOut {
                    errorMessage = "O teste excedeu o tempo limite. Tente novamente."
                } else {
                    errorMessage = "Não foi possível concluir o teste. Verifique sua conexão e tente novamente."
                }
            }
        }
    }

    func cancel() {
        task?.cancel()
        session?.invalidateAndCancel()
    }

    private static func request(bytes: Int?) -> URLRequest {
        var components = URLComponents(string: "https://speed.cloudflare.com/\(bytes == nil ? "__up" : "__down")")!
        if let bytes { components.queryItems = [URLQueryItem(name: "bytes", value: String(bytes))] }
        var request = URLRequest(url: components.url!)
        request.setValue("identity", forHTTPHeaderField: "Accept-Encoding")
        request.setValue("no-store", forHTTPHeaderField: "Cache-Control")
        return request
    }

    private static func validate(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode)
        else { throw TestError.server }
    }

    private enum TestError: Error { case server }
}
