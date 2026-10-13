// Copyright © 2026 Douglas Almeida dos Santos. Todos os direitos reservados.
import SwiftUI
import MonitorCore

struct NetworkHistoryView: View {
    let samples: [NetworkRate]
    var body: some View {
        VStack(spacing: 5) {
            Canvas { context, size in
                let maximum = max(125_000, samples.map { max($0.download, $0.upload) }.max() ?? 0)
                let base = size.height - 1
                var guide = Path()
                for fraction in [0.0, 0.5, 1.0] {
                    let y = base * fraction
                    guide.move(to: CGPoint(x: 0, y: y))
                    guide.addLine(to: CGPoint(x: size.width, y: y))
                }
                context.stroke(guide, with: .color(.secondary.opacity(0.12)),
                               style: StrokeStyle(lineWidth: 0.5, dash: [2, 3]))
                for (download, color) in [(true, Color.blue), (false, Color.teal)] {
                    var path = Path()
                    let padded = Array(repeating: NetworkRate(), count: max(0, 30 - samples.count)) + samples
                    for (index, sample) in padded.enumerated() {
                        let value = download ? sample.download : sample.upload
                        let point = CGPoint(x: Double(index) / 29 * size.width,
                                            y: base - value / maximum * (base - 3))
                        if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
                    }
                    context.stroke(path, with: .color(color),
                                   style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
                }
            }
            .frame(height: 40)
            HStack {
                Text("Último minuto")
                Spacer()
                Text("Agora")
            }
            .font(.system(size: 9)).foregroundStyle(.tertiary)
        }
        .accessibilityLabel("Histórico de upload e download no último minuto")
    }
}
