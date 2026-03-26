import SwiftUI

struct AccountSwitcherView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var store = WalletStore.shared
    @State private var accounts: [SavedAccount] = []
    @State private var showAddWallet = false
    @State private var editingAccount: SavedAccount?
    @State private var editName = ""
    @State private var showDeleteConfirm = false
    @State private var accountToDelete: SavedAccount?

    struct SavedAccount: Identifiable {
        let id: String
        var name: String
        let address: String
        var isActive: Bool
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(accounts) { account in
                    Button {
                        switchTo(account)
                    } label: {
                        HStack(spacing: 12) {
                            Circle()
                                .fill(TonlyTheme.accent.opacity(0.15))
                                .frame(width: 44, height: 44)
                                .overlay {
                                    Text(String(account.name.prefix(1)))
                                        .font(.headline)
                                        .foregroundStyle(TonlyTheme.accent)
                                }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(account.name)
                                    .font(.body.weight(.medium))
                                    .foregroundStyle(TonlyTheme.textPrimary)

                                Text(account.address.shortAddress)
                                    .font(.caption)
                                    .foregroundStyle(TonlyTheme.textSecondary)
                            }

                            Spacer()

                            Button {
                                editingAccount = account
                                editName = account.name
                                HapticService.selection()
                            } label: {
                                Image(systemName: "pencil")
                                    .font(.system(size: 14))
                                    .foregroundStyle(TonlyTheme.textSecondary)
                                    .frame(width: 32, height: 32)
                            }

                            if account.isActive {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(TonlyTheme.accent)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            accountToDelete = account
                            showDeleteConfirm = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    .listRowBackground(TonlyTheme.surface)
                }

                Button {
                    showAddWallet = true
                } label: {
                    HStack(spacing: 12) {
                        Circle()
                            .fill(TonlyTheme.surfaceLight)
                            .frame(width: 44, height: 44)
                            .overlay {
                                Image(systemName: "plus")
                                    .font(.headline)
                                    .foregroundStyle(TonlyTheme.accent)
                            }

                        Text("Add Wallet")
                            .font(.body.weight(.medium))
                            .foregroundStyle(TonlyTheme.textPrimary)

                        Spacer()
                    }
                }
                .buttonStyle(.plain)
                .listRowBackground(TonlyTheme.surface)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(TonlyTheme.background)
            .navigationTitle("Wallets")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(TonlyTheme.textSecondary)
                }
            }
        }
        .presentationDetents([.medium])
        .preferredColorScheme(.dark)
        .onAppear { loadAccounts() }
        .sheet(isPresented: $showAddWallet) {
            AddWalletSheet()
        }
        .onChange(of: showAddWallet) { _, isPresented in
            if !isPresented { loadAccounts() }
        }
        .alert("Delete Wallet?", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) { accountToDelete = nil }
            Button("Delete", role: .destructive) {
                if let account = accountToDelete {
                    TONWalletManager.deleteWallet(id: account.id)
                    let defaults = UserDefaults.standard
                    var ids = defaults.stringArray(forKey: "wallet_ids") ?? []
                    ids.removeAll { $0 == account.id }
                    defaults.set(ids, forKey: "wallet_ids")
                    if account.isActive, let nextId = ids.first {
                        store.switchWallet(id: nextId)
                    } else if ids.isEmpty {
                        store.wallet = nil
                    }
                    loadAccounts()
                    HapticService.notification(.success)
                }
                accountToDelete = nil
            }
        } message: {
            Text("This wallet will be removed. Make sure you have backed up your seed phrase.")
        }
        .alert("Rename Wallet", isPresented: Binding(
            get: { editingAccount != nil },
            set: { if !$0 { editingAccount = nil } }
        )) {
            TextField("Wallet name", text: $editName)
            Button("Save") {
                if let account = editingAccount, !editName.isEmpty {
                    TONWalletManager.setWalletName(id: account.id, name: editName)
                    if account.isActive {
                        store.wallet?.name = editName
                    }
                    loadAccounts()
                }
                editingAccount = nil
            }
            Button("Cancel", role: .cancel) { editingAccount = nil }
        }
    }

    private func loadAccounts() {
        let activeId = TONWalletManager.getActiveWalletId() ?? ""
        let ids = TONWalletManager.getAllWalletIds()

        accounts = ids.compactMap { id in
            guard let data = TONWalletManager.getStoredWallet(id: id) else { return nil }
            return SavedAccount(
                id: id,
                name: TONWalletManager.getWalletName(id: id),
                address: data.address,
                isActive: id == activeId
            )
        }
    }

    private func switchTo(_ account: SavedAccount) {
        guard !account.isActive else {
            dismiss()
            return
        }
        store.switchWallet(id: account.id)
        HapticService.impact()
        dismiss()
    }
}
