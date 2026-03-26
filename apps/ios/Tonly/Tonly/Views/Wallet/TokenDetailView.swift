import SwiftUI

struct ChartResponse: Codable {
    let points: [[Double]]
}

struct TokenDetailView: View {
    let token: Token
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPeriod = "1M"
    @State private var priceChange: Double = 0
    @State private var chartData: [CGFloat] = []
    @State private var isLoadingChart = false
    @State private var showSend = false
    @State private var showReceive = false
    @State private var showSwap = false

    private let periods = ["1H", "1D", "1W", "1M", "6M", "1Y"]
    private let periodAPI = ["1H": "1h", "1D": "24h", "1W": "7d", "1M": "30d", "6M": "180d", "1Y": "1y"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    headerSection
                    actionButtons
                    priceSection
                    chartSection
                    historySection
                }
                .padding(.top, 8)
            }
            .background(TonlyTheme.background)
            .navigationTitle(token.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(TonlyTheme.textPrimary)
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
        .task {
            await fetchChart()
        }
    }

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(token.formattedBalance) \(token.symbol)")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(TonlyTheme.textPrimary)

                Text(token.usdValue.usdFormatted)
                    .font(.title3)
                    .foregroundStyle(TonlyTheme.textSecondary)
            }

            Spacer()

            AsyncImage(url: token.iconURL) { image in
                image.resizable().scaledToFit()
            } placeholder: {
                Circle().fill(TonlyTheme.accent)
                    .overlay {
                        Text(String(token.symbol.prefix(1)))
                            .font(.title2.weight(.bold))
                            .foregroundStyle(.white)
                    }
            }
            .frame(width: 64, height: 64)
            .clipShape(Circle())
        }
        .padding(.horizontal, TonlyTheme.padding)
    }

    private var actionButtons: some View {
        HStack(spacing: 16) {
            tokenAction(icon: "arrow.up", title: "Send") { showSend = true }
            tokenAction(icon: "arrow.down", title: "Receive") { showReceive = true }
            tokenAction(icon: "arrow.up.arrow.down", title: "Swap") { showSwap = true }
        }
        .padding(.horizontal, TonlyTheme.padding)
        .sheet(isPresented: $showSend) { SendView() }
        .sheet(isPresented: $showReceive) { ReceiveView() }
        .sheet(isPresented: $showSwap) { SwapView() }
    }

    private func tokenAction(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .frame(width: 48, height: 48)
                    .background(TonlyTheme.accent.opacity(0.15))
                    .foregroundStyle(TonlyTheme.accent)
                    .clipShape(Circle())

                Text(title)
                    .font(.caption)
                    .foregroundStyle(TonlyTheme.textSecondary)
            }
        }
        .buttonStyle(.plain)
    }

    private var priceSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(token.usdPrice > 0 ? "$\(String(format: "%.4f", token.usdPrice))" : "$0.00")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(TonlyTheme.textPrimary)

            HStack(spacing: 6) {
                Text("\(priceChange >= 0 ? "+" : "")\(String(format: "%.2f", priceChange))%")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(priceChange >= 0 ? TonlyTheme.success : TonlyTheme.destructive)
            }

            Text("Price")
                .font(.caption)
                .foregroundStyle(TonlyTheme.textSecondary)
        }
        .padding(.horizontal, TonlyTheme.padding)
    }

    private var chartSection: some View {
        Group {
            if isLoadingChart && chartData.isEmpty {
                ProgressView()
                    .tint(TonlyTheme.textSecondary)
                    .frame(height: 180)
                    .frame(maxWidth: .infinity)
            } else {
                ChartView(data: chartData, color: priceChange >= 0 ? TonlyTheme.success : TonlyTheme.destructive)
                    .frame(height: 180)
                    .padding(.horizontal, 4)
            }
        }
    }

    private var periodSelector: some View {
        HStack(spacing: 0) {
            ForEach(periods, id: \.self) { period in
                Button {
                    guard selectedPeriod != period else { return }
                    selectedPeriod = period
                    HapticService.selection()
                    Task { await fetchChart() }
                } label: {
                    Text(period)
                        .font(.subheadline.weight(.medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(selectedPeriod == period ? TonlyTheme.surfaceLight : Color.clear)
                        .foregroundStyle(selectedPeriod == period ? TonlyTheme.textPrimary : TonlyTheme.textSecondary)
                        .clipShape(Capsule())
                }
            }
        }
        .padding(.horizontal, TonlyTheme.padding)
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("History")
                .font(.headline)
                .foregroundStyle(TonlyTheme.textPrimary)
                .padding(.horizontal, TonlyTheme.padding)

            let txs = WalletStore.shared.transactions
            if txs.isEmpty {
                Text("No transactions yet")
                    .font(.subheadline)
                    .foregroundStyle(TonlyTheme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
            } else {
                ForEach(txs.prefix(10)) { tx in
                    TransactionRowView(transaction: tx)
                }
            }
        }
    }

    private func fetchChart() async {
        isLoadingChart = true
        let apiPeriod = periodAPI[selectedPeriod] ?? "30d"

        do {
            let response: ChartResponse = try await APIClient.shared.request(
                .chart(token: "ton", currency: "usd", period: apiPeriod)
            )

            var prices = response.points.compactMap { point -> CGFloat? in
                guard point.count >= 2 else { return nil }
                return CGFloat(point[1])
            }

            prices.reverse()

            guard prices.count >= 2 else {
                isLoadingChart = false
                return
            }

            let first = Double(prices.first ?? 0)
            let last = Double(prices.last ?? 0)
            if first > 0 {
                priceChange = (last - first) / first * 100
            }

            withAnimation(.easeInOut(duration: 0.3)) {
                chartData = prices
            }
        } catch {
            withAnimation {
                chartData = []
            }
        }
        isLoadingChart = false
    }
}

struct ChartView: View {
    let data: [CGFloat]
    let color: Color

    var body: some View {
        GeometryReader { geo in
            if data.count > 1 {
                let minVal = data.min() ?? 0
                let maxVal = data.max() ?? 1
                let range = max(maxVal - minVal, 0.0001)
                let stepX = geo.size.width / CGFloat(data.count - 1)

                ZStack {
                    linePath(geo: geo, minVal: minVal, range: range, stepX: stepX)
                        .stroke(color, lineWidth: 1.5)

                    fillPath(geo: geo, minVal: minVal, range: range, stepX: stepX)
                        .fill(
                            LinearGradient(
                                colors: [color.opacity(0.3), color.opacity(0)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
            }
        }
    }

    private func linePath(geo: GeometryProxy, minVal: CGFloat, range: CGFloat, stepX: CGFloat) -> Path {
        Path { path in
            for (i, val) in data.enumerated() {
                let x = CGFloat(i) * stepX
                let y = geo.size.height - ((val - minVal) / range) * geo.size.height
                if i == 0 {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
        }
    }

    private func fillPath(geo: GeometryProxy, minVal: CGFloat, range: CGFloat, stepX: CGFloat) -> Path {
        Path { path in
            for (i, val) in data.enumerated() {
                let x = CGFloat(i) * stepX
                let y = geo.size.height - ((val - minVal) / range) * geo.size.height
                if i == 0 {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
            path.addLine(to: CGPoint(x: geo.size.width, y: geo.size.height))
            path.addLine(to: CGPoint(x: 0, y: geo.size.height))
            path.closeSubpath()
        }
    }
}
