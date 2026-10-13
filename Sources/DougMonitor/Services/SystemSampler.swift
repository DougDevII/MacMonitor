// Copyright © 2026 Douglas Almeida dos Santos. Todos os direitos reservados.
import Foundation
import MonitorCore
import Network

/// Mutable sampling state is confined to a single utility queue.
final class SystemSampler: @unchecked Sendable {
    private let queue = DispatchQueue(label: "br.com.douglasalmeida.DougMonitor.sampler", qos: .utility)
    private let pathMonitor = NWPathMonitor()
    private var timer: DispatchSourceTimer?
    private var reader = KernelReader()
    private var available = false
    private var connection = "Verificando rede…"
    private let deliver: @Sendable (MetricSnapshot) -> Void

    init(deliver: @escaping @Sendable (MetricSnapshot) -> Void) {
        self.deliver = deliver
        pathMonitor.pathUpdateHandler = { [weak self] path in
            guard let self else { return }
            available = path.status == .satisfied
            if !available { connection = "Sem conexão" }
            else if path.usesInterfaceType(.wifi) { connection = "Wi-Fi" }
            else if path.usesInterfaceType(.wiredEthernet) { connection = "Ethernet" }
            else if path.usesInterfaceType(.cellular) { connection = "Rede móvel" }
            else { connection = "Rede" }
        }
        pathMonitor.start(queue: queue)
    }

    func start() {
        queue.async { [self] in
            guard timer == nil else { return }
            reader.reset()
            let source = DispatchSource.makeTimerSource(queue: queue)
            source.schedule(deadline: .now(), repeating: .seconds(2), leeway: .milliseconds(250))
            source.setEventHandler { [weak self] in
                guard let self else { return }
                deliver(reader.sample(available: available, connection: connection))
            }
            timer = source
            source.resume()
        }
    }

    func stop() {
        queue.async { [self] in timer?.cancel(); timer = nil; reader.reset() }
    }

    deinit { timer?.cancel(); pathMonitor.cancel() }
}
