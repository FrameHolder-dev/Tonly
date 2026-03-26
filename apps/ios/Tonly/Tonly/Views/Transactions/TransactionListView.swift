import SwiftUI

struct TransactionListView: View {
    @State private var store = WalletStore.shared
    @State private var selectedTx: Transaction?
    @State private var filter: TxFilter = .all

    enum TxFilter: String, CaseIterable {
        case all = "All"
        case sent = "Sent"
        case received = "Received"
    }

    var filteredTransactions: [Transaction] {
        let txs = store.transactions.filter { $0.amount >= 0.001 }
        switch filter {
        case .all: return txs
        case .sent: return txs.filter { !$0.isIncoming }
        case .received: return txs.filter { $0.isIncoming }
        }
    }

    var groupedTransactions: [(String, [Transaction])] {
        let grouped = Dictionary(grouping: filteredTransactions) { tx -> String in
            let calendar = Calendar.current
            if calendar.isDateInToday(tx.timestamp) { return "Today" }
            if calendar.isDateInYesterday(tx.timestamp) { return "Yesterday" }
            let formatter = DateFormatter()
            formatter.dateFormat = "MMMM d"
            return formatter.string(from: tx.timestamp)
        }
        return grouped.sorted { group1, group2 in
            guard let d1 = group1.value.first?.timestamp, let d2 = group2.value.first?.timestamp else { return false }
            return d1 > d2
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                filterBar
                    .padding(.top, 4)

                if store.isLoading && store.transactions.isEmpty {
                    ScrollView {
                        ForEach(0..<6, id: \.self) { _ in
                            SkeletonRow()
                        }
                    }
                } else if filteredTransactions.isEmpty {
                    Spacer()
                    emptyState
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(groupedTransactions, id: \.0) { group in
                                Section {
                                    ForEach(group.1) { tx in
                                        TransactionRowView(transaction: tx)
                                            .contentShape(Rectangle())
                                            .onTapGesture {
                                                selectedTx = tx
                                                HapticService.selection()
                                            }
                                    }
                                } header: {
                                    Text(group.0)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(TonlyTheme.textSecondary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.horizontal, 16)
                                        .padding(.top, 16)
                                        .padding(.bottom, 8)
                                }
                            }
                        }
                    }
                }
            }
            .background(TonlyTheme.background)
            .navigationTitle("Activity")
            .toolbarColorScheme(.dark, for: .navigationBar)
            .refreshable {
                await store.loadTransactions()
            }
            .sheet(item: $selectedTx) { tx in
                TransactionDetailView(transaction: tx)
            }
        }
        .preferredColorScheme(.dark)
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(TxFilter.allCases, id: \.self) { f in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            filter = f
                        }
                        HapticService.selection()
                    } label: {
                        Text(f.rawValue)
                            .font(.subheadline.weight(.medium))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(filter == f ? TonlyTheme.surfaceLight : TonlyTheme.surface)
                            .foregroundStyle(filter == f ? TonlyTheme.textPrimary : TonlyTheme.textSecondary)
                            .clipShape(Capsule())
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Text(filter == .all ? "Your history will\nappear here" : "No \(filter.rawValue.lowercased())\ntransactions")
                .font(.title2.weight(.bold))
                .foregroundStyle(TonlyTheme.textPrimary)
                .multilineTextAlignment(.center)

            if filter == .all {
                Text("Make your first transaction!")
                    .font(.subheadline)
                    .foregroundStyle(TonlyTheme.textSecondary)
            }
        }
    }
}
