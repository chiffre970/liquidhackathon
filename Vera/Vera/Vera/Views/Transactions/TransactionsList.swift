import SwiftUI

struct TransactionsList: View {
    @Binding var transactions: [Transaction]
    @State private var editingTransaction: Transaction?
    @State private var showingEditModal = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your transactions")
                .font(.custom("Inter", size: Typography.FontSize.body).weight(Typography.FontWeight.semibold))
                .foregroundColor(.veraDarkGreen.opacity(0.7))
            
            if transactions.isEmpty {
                Text("No transactions to display")
                    .font(.veraBodySmall())
                    .foregroundColor(.veraDarkGreen.opacity(0.4))
                    .padding(.vertical, 8)
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 2) {
                        ForEach(transactions) { transaction in
                            TransactionRow(
                                transaction: transaction,
                                onEdit: {
                                    editingTransaction = transaction
                                    showingEditModal = true
                                }
                            )
                        }
                    }
                }
                .background(Color.veraWhite)
                .cornerRadius(DesignSystem.smallCornerRadius)
            }
        }
        .sheet(isPresented: $showingEditModal) {
            if let transaction = editingTransaction {
                TransactionEditModal(
                    transaction: transaction,
                    isPresented: $showingEditModal,
                    onSave: { updated in
                        updateTransaction(updated)
                    }
                )
            }
        }
    }
    
    private func updateTransaction(_ updated: Transaction) {
        if let index = transactions.firstIndex(where: { $0.id == updated.id }) {
            transactions[index] = updated
        }
    }
}

struct TransactionRow: View {
    let transaction: Transaction
    let onEdit: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.description)
                    .font(.veraBodySmall())
                    .foregroundColor(.veraDarkGreen)
                    .lineLimit(1)
                
                Text(transaction.date, style: .date)
                    .font(.veraCaption())
                    .foregroundColor(.veraDarkGreen.opacity(0.6))
            }
            
            Spacer()
            
            Text(transaction.category ?? "Uncategorized")
                .font(.veraCaption())
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.veraLightGreen.opacity(0.2))
                .cornerRadius(DesignSystem.tinyCornerRadius)
            
            Text(String(format: "$%.2f", abs(transaction.amount)))
                .font(.custom("Inter", size: Typography.FontSize.bodySmall).weight(Typography.FontWeight.semibold))
                .foregroundColor(transaction.amount < 0 ? .red : .green)
                .frame(width: 80, alignment: .trailing)
            
            Button(action: onEdit) {
                Image(systemName: "pencil")
                    .font(.custom("Inter", size: 14))
                    .foregroundColor(.veraDarkGreen.opacity(0.5))
                    .frame(width: 20, height: 20)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.veraGrey.opacity(0.3))
    }
}