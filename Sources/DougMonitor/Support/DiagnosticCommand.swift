// Copyright © 2026 Douglas Almeida dos Santos. Todos os direitos reservados.
import Foundation

enum DiagnosticCommand {
    static func run() {
        var reader = KernelReader()
        _ = reader.sample(available: false, connection: "Diagnóstico local")
        Thread.sleep(forTimeInterval: 2)
        let sample = reader.sample(available: false, connection: "Diagnóstico local")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(sample), let text = String(data: data, encoding: .utf8) {
            print(text)
        }
    }
}
