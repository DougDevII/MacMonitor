// Copyright © 2026 Douglas Almeida dos Santos. Todos os direitos reservados.
import Foundation

/// A bounded streaming transfer. Chunks are counted and discarded, never retained.
/// Every delegate/timer/cancellation access to state is protected by the same lock.
final class TransferProbe: NSObject, URLSessionDataDelegate, @unchecked Sendable {
    enum Direction: Sendable { case download, upload }
    private let direction: Direction
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Double, Error>?
    private var session: URLSession?
    private var timeout: DispatchWorkItem?
    private var startedAt = 0.0
    private var byteCount: Int64 = 0
    private var validResponse = false
    private var cancelled = false

    init(direction: Direction) { self.direction = direction }

    func measure(request: URLRequest) async throws -> Double {
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                lock.lock()
                guard !cancelled else {
                    lock.unlock()
                    continuation.resume(throwing: CancellationError())
                    return
                }
                self.continuation = continuation
                startedAt = ProcessInfo.processInfo.systemUptime
                let config = URLSessionConfiguration.ephemeral
                config.urlCache = nil
                config.httpCookieStorage = nil
                config.urlCredentialStorage = nil
                config.timeoutIntervalForRequest = 12
                config.timeoutIntervalForResource = 15
                config.waitsForConnectivity = false
                let queue = OperationQueue()
                queue.maxConcurrentOperationCount = 1
                queue.qualityOfService = .utility
                let session = URLSession(configuration: config, delegate: self, delegateQueue: queue)
                self.session = session
                let task = session.dataTask(with: request)
                let deadline = DispatchWorkItem { [weak self] in self?.finish(error: nil, timedSample: true) }
                timeout = deadline
                lock.unlock()
                task.resume()
                // A slow connection returns its observed rate, instead of requiring
                // the entire payload to finish. A stalled connection yields an error.
                DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 8, execute: deadline)
            }
        } onCancel: {
            lock.lock(); cancelled = true; lock.unlock()
            finish(error: CancellationError())
        }
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask,
                    didReceive response: URLResponse,
                    completionHandler: @escaping @Sendable (URLSession.ResponseDisposition) -> Void) {
        let valid = (response as? HTTPURLResponse).map { (200..<300).contains($0.statusCode) } ?? false
        lock.lock(); validResponse = valid; lock.unlock()
        completionHandler(valid ? .allow : .cancel)
        if !valid { finish(error: URLError(.badServerResponse)) }
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        guard direction == .download else { return }
        lock.lock(); byteCount += Int64(data.count); lock.unlock()
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64,
                    totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
        guard direction == .upload else { return }
        lock.lock(); byteCount = totalBytesSent; lock.unlock()
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        finish(error: error)
    }

    private func finish(error: Error?, timedSample: Bool = false) {
        lock.lock()
        guard let continuation else { lock.unlock(); return }
        self.continuation = nil
        let count = byteCount
        let duration = ProcessInfo.processInfo.systemUptime - startedAt
        let valid = validResponse || (timedSample && direction == .upload && count > 0)
        let session = session
        self.session = nil
        timeout?.cancel(); timeout = nil
        lock.unlock()
        session?.invalidateAndCancel()
        if let error { continuation.resume(throwing: error) }
        else if count > 0, duration > 0, valid {
            continuation.resume(returning: Double(count) / duration)
        } else { continuation.resume(throwing: URLError(.timedOut)) }
    }
}
