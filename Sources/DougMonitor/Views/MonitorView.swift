// Copyright © 2026 Douglas Almeida dos Santos. Todos os direitos reservados.
import SwiftUI
import MonitorCore

struct MonitorView: View {
    @ObservedObject var store: MonitorStore
    @ObservedObject var speedTest: SpeedTestStore
    let quit: () -> Void
    @State private var showAuthor = false

    private var snapshot: MetricSnapshot { store.snapshot }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Image(systemName: "gauge.with.dots.needle.33percent")
                    .font(.system(size: 21, weight: .medium)).foregroundStyle(.blue)
                    .frame(width: 34, height: 34)
                    .background(.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Monitor").font(.system(size: 14, weight: .semibold))
                    Text("Seu Mac, em tempo real").font(.system(size: 10)).foregroundStyle(.secondary)
                }
                Spacer()
                Circle().fill(.green).frame(width: 5, height: 5)
                    .accessibilityLabel("Monitor ativo")
            }

            ResourceRow(title: "CPU", symbol: "cpu", fraction: snapshot.cpu,
                        detail: "Uso total do processador", tint: .blue)

            ResourceRow(title: "RAM", symbol: "memorychip", fraction: snapshot.memoryFraction,
                        detail: memoryDetail, tint: .purple)

            Divider()

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("REDE AGORA").font(.system(size: 9, weight: .semibold)).tracking(0.8)
                        .foregroundStyle(.secondary)
                    Spacer()
                    HStack(spacing: 4) {
                        Image(systemName: snapshot.networkAvailable ? "wifi" : "wifi.slash")
                        Text(snapshot.connection)
                    }
                    .font(.system(size: 10)).foregroundStyle(.secondary)
                    .help("Uma rota de rede está disponível. Isso não garante acesso à internet; o teste manual verifica a transferência.")
                }
                HStack(alignment: .top, spacing: 0) {
                    rateColumn("Download", symbol: "arrow.down", value: snapshot.rate.download, tint: .blue)
                    Spacer(minLength: 15)
                    rateColumn("Upload", symbol: "arrow.up", value: snapshot.rate.upload, tint: .teal)
                }
                NetworkHistoryView(samples: store.history)
                Text("Tráfego atual · atualiza a cada 2 s")
                    .font(.system(size: 9)).foregroundStyle(.tertiary)
            }

            Divider()
            SpeedTestView(test: speedTest, available: snapshot.networkAvailable)
            Divider()

            HStack {
                Button {
                    showAuthor.toggle()
                } label: {
                    Label("Sobre", systemImage: "info.circle")
                        .font(.system(size: 10))
                }
                .buttonStyle(.plain).foregroundStyle(.secondary)
                Spacer()
                Button(action: quit) {
                    Label("Sair", systemImage: "power").font(.system(size: 10))
                }
                .buttonStyle(.plain).foregroundStyle(.secondary)
                .keyboardShortcut("q")
            }
            if showAuthor {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Douglas Almeida dos Santos").font(.system(size: 11, weight: .medium))
                    Text("Monitor 1.0 · © 2026\nCPU, RAM e rede. Feito para o seu Mac.")
                        .font(.system(size: 10)).foregroundStyle(.secondary)
                }
            }
        }
        .padding(18)
        .frame(width: 310)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var memoryDetail: String {
        guard let used = snapshot.memoryUsed else { return "Lendo memória…" }
        return "\(MetricFormat.gigabytes(used)) de \(MetricFormat.gigabytes(snapshot.memoryTotal)) GB em uso"
    }

    private func rateColumn(_ title: String, symbol: String, value: Double, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: symbol)
                .font(.system(size: 10, weight: .medium)).foregroundStyle(tint)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(MetricFormat.megabits(value))
                    .font(.system(size: 25, weight: .semibold, design: .rounded)).monospacedDigit()
                Text("Mbps").font(.system(size: 10)).foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title), \(MetricFormat.megabits(value)) megabits por segundo")
    }
}
