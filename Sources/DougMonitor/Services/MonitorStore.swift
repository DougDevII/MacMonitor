// Copyright © 2026 Douglas Almeida dos Santos. Todos os direitos reservados.
import Combine
import Foundation
import MonitorCore

@MainActor
final class MonitorStore: ObservableObject {
    @Published private(set) var snapshot = MetricSnapshot()
    @Published private(set) var history: [NetworkRate] = []
    var didSample: ((MetricSnapshot) -> Void)?
    private var sampler: SystemSampler?

    func start() {
        if sampler == nil {
            sampler = SystemSampler { [weak self] sample in
                Task { @MainActor [weak self] in self?.receive(sample) }
            }
        }
        sampler?.start()
    }

    func stop() { sampler?.stop() }

    private func receive(_ sample: MetricSnapshot) {
        snapshot = sample
        history.append(sample.rate)
        if history.count > 30 { history.removeFirst(history.count - 30) }
        didSample?(sample)
    }
}
