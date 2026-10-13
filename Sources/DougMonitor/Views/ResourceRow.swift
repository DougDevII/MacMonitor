// Copyright © 2026 Douglas Almeida dos Santos. Todos os direitos reservados.
import SwiftUI
import MonitorCore

struct ResourceRow: View {
    let title: String
    let symbol: String
    let fraction: Double?
    let detail: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 9) {
                Image(systemName: symbol)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(tint)
                    .frame(width: 18)
                Text(title).font(.system(size: 12, weight: .semibold))
                Spacer()
                Text(MetricFormat.percent(fraction))
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }
            GeometryReader { geometry in
                Capsule().fill(.primary.opacity(0.09))
                    .overlay(alignment: .leading) {
                        Capsule().fill(tint.gradient)
                            .frame(width: geometry.size.width * CGFloat(fraction ?? 0))
                    }
            }
            .frame(height: 4)
            Text(detail).font(.system(size: 10)).foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title), \(MetricFormat.percent(fraction)). \(detail)")
    }
}
