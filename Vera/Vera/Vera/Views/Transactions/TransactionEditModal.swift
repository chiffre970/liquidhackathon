import SwiftUI

struct TransactionEditModal: View {
    @State var transaction: Transaction
    @Binding var isPresented: Bool
    let onSave: (Transaction) -> Void
    
    @State private var description: String = ""
    @State private var amount: String = ""
    @State private var selectedCategory: String = ""
    @State private var date: Date = Date()
    
    let categories = ["Housing", "Food", "Transportation", "Healthcare", 
                     "Entertainment", "Shopping", "Savings", "Other"]
    
    var body: some View {
        NavigationView {
            VContainer(backgroundColor: .veraGrey) {
                VStack(spacing: 20) {
                    VStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Description")
                                .font(.custom("Inter", size: Typography.FontSize.bodySmall).weight(Typography.FontWeight.medium))
                                .foregroundColor(.veraDarkGreen.opacity(0.7))
                            
                            TextField("Enter description", text: $description)
                                .font(.veraBody())
                                .padding(12)
                                .background(Color.veraWhite)
                                .cornerRadius(DesignSystem.tinyCornerRadius)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Amount")
                                .font(.custom("Inter", size: Typography.FontSize.bodySmall).weight(Typography.FontWeight.medium))
                                .foregroundColor(.veraDarkGreen.opacity(0.7))
                            
                            TextField("0.00", text: $amount)
                                .font(.veraBody())
                                .keyboardType(.decimalPad)
                                .padding(12)
                                .background(Color.veraWhite)
                                .cornerRadius(DesignSystem.tinyCornerRadius)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Category")
                                .font(.custom("Inter", size: Typography.FontSize.bodySmall).weight(Typography.FontWeight.medium))
                                .foregroundColor(.veraDarkGreen.opacity(0.7))
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(categories, id: \.self) { category in
                                        Button(action: { selectedCategory = category }) {
                                            Text(category)
                                                .font(.veraBodySmall())
                                                .padding(.horizontal, 16)
                                                .padding(.vertical, 8)
                                                .background(selectedCategory == category ? 
                                                          Color.veraLightGreen : Color.veraWhite)
                                                .foregroundColor(selectedCategory == category ? 
                                                               .white : .veraDarkGreen)
                                                .cornerRadius(20)
                                        }
                                    }
                                }
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Date")
                                .font(.custom("Inter", size: Typography.FontSize.bodySmall).weight(Typography.FontWeight.medium))
                                .foregroundColor(.veraDarkGreen.opacity(0.7))
                            
                            DatePicker("", selection: $date, displayedComponents: .date)
                                .datePickerStyle(CompactDatePickerStyle())
                                .labelsHidden()
                        }
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 16) {
                        Button(action: { isPresented = false }) {
                            Text("Cancel")
                                .font(.custom("Inter", size: Typography.FontSize.body).weight(Typography.FontWeight.medium))
                                .foregroundColor(.veraDarkGreen)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.veraWhite)
                                .cornerRadius(DesignSystem.smallCornerRadius)
                        }
                        
                        Button(action: saveTransaction) {
                            Text("Save")
                                .font(.custom("Inter", size: Typography.FontSize.body).weight(Typography.FontWeight.semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.veraLightGreen)
                                .cornerRadius(DesignSystem.smallCornerRadius)
                        }
                    }
                }
            }
            .navigationTitle("Edit Transaction")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button(action: { isPresented = false }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.veraDarkGreen.opacity(0.3))
                    .font(.custom("Inter", size: 24))
            })
        }
        .onAppear {
            description = transaction.description
            amount = String(format: "%.2f", abs(transaction.amount))
            selectedCategory = transaction.category ?? "Other"
            date = transaction.date
        }
    }
    
    func saveTransaction() {
        var updatedTransaction = transaction
        updatedTransaction.description = description
        updatedTransaction.amount = Double(amount) ?? 0
        updatedTransaction.category = selectedCategory
        updatedTransaction.date = date
        onSave(updatedTransaction)
        isPresented = false
    }
}