# Monitor

Aplicativo leve para macOS que acompanha o uso de CPU, RAM e rede diretamente na barra de menus.

O aplicativo fica na barra de menus e exibe somente:

- CPU: uso total do processador em porcentagem.
- RAM: porcentagem e quantidade física em uso.
- Rede: download e upload atuais em Mbps, com histórico de um minuto.
- Teste manual de internet: estimativas de download/upload e resposta HTTP ao serviço de medição.

## Abrir e usar

Abra **Monitor.app**. O painel aparece na primeira abertura. Depois, clique no indicador da barra de menus para abri-lo ou fechá-lo.

O indicador mostra `C` para CPU e `R` para RAM. O aplicativo não ocupa o Dock. Clique fora do painel ou pressione Escape para fechá-lo; **Sair** encerra o monitor. A interface acompanha a aparência e as preferências de acessibilidade do macOS.

Para gerar o aplicativo a partir deste repositório, consulte **Código editável** abaixo. Depois de compilar, arraste **Monitor.app**, da pasta `dist`, para Aplicativos. O aplicativo compilado usa os frameworks do macOS e não precisa do ambiente de desenvolvimento para executar.

O script de compilação usa assinatura ad hoc, sem certificado de distribuição ou notarização da Apple. O aplicativo compilado destina-se ao uso local. O repositório contém o código-fonte e os recursos, sem binários de distribuição.

## Tráfego atual e velocidade da internet

**Rede agora** mede os bytes efetivamente transferidos pelas interfaces físicas do Mac. Uma leitura baixa pode significar apenas que nada está sendo transferido. Inclui tráfego da rede local; não representa exclusivamente tráfego de internet, nem a velocidade contratada.

**Testar velocidade** faz uma medição sob demanda contra `speed.cloudflare.com`, com amostras de até oito segundos por direção. O limite de conteúdo é 50 MB de download e 10 MB de upload; há também cabeçalhos e pequenos pedidos para medir a resposta HTTP. O teste pode terminar antes de atingir esses limites. O upload usa dados sintéticos, e nenhum arquivo pessoal é enviado.

O resultado é uma estimativa da transferência observada nessa ocasião, não uma garantia de velocidade máxima. VPN, Wi-Fi, congestionamento e outras transferências simultâneas podem afetá-lo. **Resposta HTTP** inclui o tempo de resposta do serviço e não é ping ICMP. Não há classificação arbitrária de “internet boa” ou “ruim”.

O teste tem botão **Cancelar**. Não acontece automaticamente ao iniciar o aplicativo ou abrir o painel. A Cloudflare recebe as requisições e o endereço IP público, como em qualquer acesso HTTPS ao serviço. O aplicativo não envia os valores de CPU/RAM nem registra históricos em disco.

## Como o monitor permanece leve

- Swift, SwiftUI e AppKit, usando apenas frameworks do sistema.
- Um temporizador com atualização a cada dois segundos e tolerância de 250 ms.
- Coleta em fila de prioridade utilitária.
- Histórico limitado a 30 amostras; sem banco de dados ou logs contínuos.
- Leitura nativa de contadores; sem subprocessos, agentes privilegiados ou acesso de administrador.
- Coleta suspensa quando o Mac dorme; contadores reinicializados ao acordar.
- Nenhum teste contínuo de internet, telemetria, atualizador ou inicialização automática.
- Teste de download por streaming: os blocos recebidos são contados e descartados.

## Origem dos valores

- CPU: diferenças entre contadores `HOST_CPU_LOAD_INFO`; soma usuário, sistema e nice, em relação ao total, incluindo idle. A primeira amostra precisa estabelecer uma linha de base.
- RAM: páginas internas não purgáveis + memória wired + páginas físicas ocupadas pelo compressor, multiplicadas pelo tamanho de página e limitadas à RAM física. Cache de arquivos recuperável e volume virtual descomprimido não são contados como RAM física usada. Pequenas diferenças em relação ao Monitor de Atividade podem resultar da fórmula e dos instantes de amostragem.
- Rede: contadores de 64 bits `NET_RT_IFLIST2` de interfaces `en*` ativas. Interfaces loopback, AWDL, bridges e túneis de VPN são excluídas para evitar duplicar tráfego entre camadas. O tráfego de uma VPN ainda atravessa a interface física e aparece no total. Novas interfaces ou contadores reinicializados recebem uma nova linha de base.
- Disponibilidade: `NWPathMonitor`, da Apple. Indicar Wi-Fi/Ethernet disponível informa a existência de uma rota de rede, sem garantir que a internet esteja acessível.

## Código editável

Requisitos: macOS 14 ou superior, Swift 6 e SDK macOS instalados pelo Xcode/Command Line Tools. O projeto foi compilado e validado em Apple Silicon; Intel não foi testado.

```bash
git clone https://github.com/DougDevII/MacMonitor.git
cd MacMonitor
```

```bash
./script/build_and_run.sh
```

Esse comando compila uma versão otimizada, cria o bundle em `dist/Monitor.app`, assina localmente e abre o aplicativo.

Outros comandos:

```bash
# Apenas compilar e empacotar
./script/build_and_run.sh --build-only

# Compilar, abrir e confirmar o processo
./script/build_and_run.sh --verify

# Executar testes em pasta fora do iCloud
swift test --scratch-path /private/tmp/doug-monitor-tests

# Ler uma amostra dos contadores locais, sem abrir a interface
"dist/Monitor.app/Contents/MacOS/DougMonitor" --diagnose

# Regenerar o ícone original, se desejar
swift script/make_icon.swift Resources
```

Os arquivos são separados entre cálculos (`MonitorCore`), serviços de coleta/teste, interface e ciclo de vida do aplicativo.

## Licença

Este projeto é distribuído sob a [licença MIT](LICENSE).

## Referências de APIs

- [Network framework / NWPathMonitor — Apple](https://developer.apple.com/documentation/network/nwpathmonitor)
- [SwiftUI — Apple](https://developer.apple.com/documentation/swiftui)
- [Endpoints de medição — Cloudflare](https://github.com/cloudflare/speedtest)
