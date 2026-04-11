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
            ScrollView {
                VStack(spacing: 8) {
                    VStack(spacing: 0) {
                        ForEach(Array(accounts.enumerated()), id: \.element.id) { index, account in
                            accountRow(account)
                            if index < accounts.count - 1 {
                                Divider()
                                    .background(TonlyTheme.surfaceLight)
                                    .padding(.leading, 72)
                            }
                        }
                    }
                    .background(TonlyTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: TonlyTheme.cornerRadius))
                    .padding(.horizontal, TonlyTheme.padding)
                    .padding(.top, 8)

                    addWalletButton
                        .padding(.horizontal, TonlyTheme.padding)
                }
            }
            .background(TonlyTheme.background)
            .navigationTitle("Wallets")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(TonlyTheme.textSecondary)
                    }
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
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

    private func accountRow(_ account: SavedAccount) -> some View {
        Button {
            switchTo(account)
        } label: {
            HStack(spacing: 12) {
                Circle()
                    .fill(TonlyTheme.accent.opacity(0.15))
                    .frame(width: 40, height: 40)
                    .overlay {
                        Text(String(account.name.prefix(1)).uppercased())
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(TonlyTheme.accent)
                    }

                VStack(alignment: .leading, spacing: 2) {
                    Text(account.name)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(TonlyTheme.textPrimary)
                    Text(account.address.shortAddress)
                        .font(.caption2)
                        .foregroundStyle(TonlyTheme.textSecondary)
                }

                Spacer()

                Button {
                    editingAccount = account
                    editName = account.name
                    HapticService.selection()
                } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 13))
                        .foregroundStyle(TonlyTheme.textSecondary)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)

                if accounts.count > 1 {
                    Button {
                        accountToDelete = account
                        showDeleteConfirm = true
                        HapticService.selection()
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 13))
                            .foregroundStyle(TonlyTheme.destructive.opacity(0.8))
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(.plain)
                }

                if account.isActive {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(TonlyTheme.accent)
                        .frame(width: 20)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var addWalletButton: some View {
        Button {
            showAddWallet = true
            HapticService.selection()
        } label: {
            HStack(spacing: 12) {
                Circle()
                    .fill(TonlyTheme.accent.opacity(0.15))
                    .frame(width: 40, height: 40)
                    .overlay {
                        Image(systemName: "plus")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(TonlyTheme.accent)
                    }

                Text("Add Wallet")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(TonlyTheme.textPrimary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(TonlyTheme.textSecondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(TonlyTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: TonlyTheme.cornerRadius))
        }
        .buttonStyle(.plain)
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
