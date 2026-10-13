// Copyright © 2026 Douglas Almeida dos Santos. Todos os direitos reservados.
import SwiftUI
import MonitorCore

struct SpeedTestView: View {
    @ObservedObject var test: SpeedTestStore
    let available: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text("VELOCIDADE DA INTERNET")
                    .font(.system(size: 9, weight: .semibold)).tracking(0.8)
                    .foregroundStyle(.secondary)
                Spacer()
                if test.isRunning {
                    Button("Cancelar") { test.cancel() }.controlSize(.mini)
                } else {
                    Button("Testar velocidade") { test.start() }
                        .controlSize(.mini).disabled(!available)
                        .help("Teste estimado pela Cloudflare. Transfere até 60 MB; não é executado automaticamente.")
                }
            }
            if test.isRunning {
                HStack(spacing: 7) {
                    ProgressView().controlSize(.mini)
                    Text(test.phase.rawValue).font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
            if let result = test.result {
                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    resultMetric("Download", value: MetricFormat.megabits(result.downloadBytesPerSecond), tint: .blue)
                    Spacer()
                    resultMetric("Upload", value: MetricFormat.megabits(result.uploadBytesPerSecond), tint: .teal)
                }
                HStack {
                    Text("Resposta HTTP: \(Int(result.httpLatencyMilliseconds.rounded())) ms")
                    Spacer()
                    Text(result.completedAt, style: .time)
                }
                .font(.system(size: 10)).foregroundStyle(.secondary)
                Text("Estimativa deste teste; pode variar com Wi-Fi, VPN e outros usos da rede.")
                    .font(.system(size: 9)).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let error = test.errorMessage {
                Text(error).font(.system(size: 10)).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text("Manual · Cloudflare · até 60 MB por teste")
                .font(.system(size: 9)).foregroundStyle(.tertiary)
        }
    }

    private func resultMetric(_ label: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.system(size: 10)).foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value).font(.system(size: 20, weight: .semibold, design: .rounded)).monospacedDigit()
                Text("Mbps").font(.system(size: 10)).foregroundStyle(.secondary)
            }
            .foregroundStyle(tint)
        }
    }
}
