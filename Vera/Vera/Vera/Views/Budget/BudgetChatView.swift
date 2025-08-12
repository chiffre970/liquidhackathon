import SwiftUI

struct BudgetChatView: View {
    @Binding var messages: [ChatMessage]
    @Binding var inputText: String
    @EnvironmentObject var csvProcessor: CSVProcessor
    let onFinalize: (Budget) -> Void
    @FocusState private var isTextFieldFocused: Bool
    @State private var isProcessing = false
    @State private var errorMessage: String?
    
    var body: some View {
        VStack(spacing: 0) {
            Text("Budget")
                .font(.veraTitle())
                .foregroundColor(.black)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 20)
            
            ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(messages) { message in
                            ChatBubble(message: message)
                                .id(message.id)
                        }
                    }
                    .padding(.bottom, 10)
                }
                .onChange(of: messages.count) { _, _ in
                    withAnimation {
                        proxy.scrollTo(messages.last?.id, anchor: .bottom)
                    }
                }
            }
            
            HStack(spacing: 12) {
                TextField("Set budget targets for your categories...", text: $inputText)
                    .font(.veraBodySmall())
                    .padding(12)
                    .background(Color.veraWhite)
                    .cornerRadius(20)
                    .focused($isTextFieldFocused)
                
                Button(action: sendMessage) {
                    if isProcessing {
                        ProgressView()
                            .scaleEffect(0.8)
                            .frame(width: 40, height: 40)
                    } else {
                        Image(systemName: "paperplane.fill")
                            .font(.custom("Inter", size: 16))
                            .foregroundColor(.veraWhite)
                            .rotationEffect(.degrees(45))
                            .padding(12)
                            .background(inputText.isEmpty ? Color.veraGrey : Color.veraLightGreen)
                            .clipShape(Circle())
                    }
                }
                .disabled(inputText.isEmpty || isProcessing)
            }
            .padding(.top, 12)
            
            if let error = errorMessage {
                Text(error)
                    .font(.veraCaption())
                    .foregroundColor(.red)
                    .padding(.top, 8)
            }
            
            if messages.count > 2 {
                VButton(title: "Finalize Budget", style: .primary, isFullWidth: true) {
                    createBudget()
                }
                .padding(.top, 12)
            }
        }
    }
    
    private func sendMessage() {
        guard !inputText.isEmpty else { return }
        
        let userMessage = ChatMessage(
            id: UUID(),
            content: inputText,
            isUser: true,
            timestamp: Date()
        )
        
        messages.append(userMessage)
        let messageContent = inputText
        inputText = ""
        
        // Generate a simple response based on CSV categories
        let response = generateBudgetResponse(for: messageContent)
        
        messages.append(ChatMessage(
            id: UUID(),
            content: response,
            isUser: false,
            timestamp: Date()
        ))
    }
    
    private func generateBudgetResponse(for message: String) -> String {
        let categories = csvProcessor.uniqueCategories.sorted()
        let categoryTotals = csvProcessor.categoryTotals
        
        if categories.isEmpty {
            return "Please upload and analyze your CSV files first to see your spending categories."
        }
        
        // Simple response generation based on message content
        let messageLower = message.lowercased()
        
        if messageLower.contains("categor") || messageLower.contains("what") || messageLower.contains("show") {
            var response = "Based on your CSV data, you have the following categories:\n\n"
            for category in categories {
                let amount = categoryTotals[category] ?? 0
                response += "• \(category): $\(String(format: "%.2f", abs(amount)))\n"
            }
            response += "\nWould you like to set budget targets for these categories?"
            return response
        }
        
        if messageLower.contains("recommend") || messageLower.contains("suggest") {
            var response = "Based on your current spending patterns, here are suggested budget targets:\n\n"
            for category in categories {
                let currentAmount = abs(categoryTotals[category] ?? 0)
                let suggested = currentAmount * 0.9 // Suggest 10% reduction
                response += "• \(category): $\(String(format: "%.2f", suggested)) (currently $\(String(format: "%.2f", currentAmount)))\n"
            }
            response += "\nThese targets aim for a 10% reduction in spending."
            return response
        }
        
        if messageLower.contains("save") || messageLower.contains("saving") {
            let totalExpenses = categoryTotals.values.filter { $0 < 0 }.reduce(0) { $0 + abs($1) }
            let suggestedSavings = totalExpenses * 0.2
            return """
            To build healthy savings, I recommend targeting 20% of your expenses.
            
            Based on your total expenses of $\(String(format: "%.2f", totalExpenses)), you should aim to save $\(String(format: "%.2f", suggestedSavings)) per month.
            
            You can achieve this by reducing spending across your categories proportionally.
            """
        }
        
        // Default response
        return """
        I can help you create a budget based on your \(categories.count) spending categories.
        
        You can:
        • Review your current spending by category
        • Get recommended budget targets
        • Set custom limits for each category
        
        What would you like to focus on?
        """
    }
    
    private func createBudget() {
        isProcessing = true
        errorMessage = nil
        
        // Get current spending data from CSV processor
        let categories = csvProcessor.uniqueCategories.sorted()
        let categoryTotals = csvProcessor.categoryTotals
        
        if categories.isEmpty {
            errorMessage = "No categories found. Please upload CSV files first."
            isProcessing = false
            return
        }
        
        // Calculate total spending
        let totalExpenses = categoryTotals.values.filter { $0 < 0 }.reduce(0) { $0 + abs($1) }
        let totalIncome = categoryTotals.values.filter { $0 > 0 }.reduce(0) { $0 + $1 }
        
        // Create budget allocations based on actual categories
        var budgetCategories: [Budget.CategoryAllocation] = []
        
        for category in categories {
            let amount = abs(categoryTotals[category] ?? 0)
            let percentage = totalExpenses > 0 ? (amount / totalExpenses) * 100 : 0
            
            // Apply slight reduction for budget targets (encourage saving)
            let targetAmount = amount * 0.95
            
            budgetCategories.append(Budget.CategoryAllocation(
                name: category,
                amount: targetAmount,
                percentage: percentage
            ))
        }
        
        // Add savings category if not present
        if !categories.contains("Savings") && !categories.contains("savings") {
            let savingsAmount = totalExpenses * 0.1 // Target 10% savings
            budgetCategories.append(Budget.CategoryAllocation(
                name: "Savings",
                amount: savingsAmount,
                percentage: 10
            ))
        }
        
        // Sort by amount
        budgetCategories.sort { $0.amount > $1.amount }
        
        // Generate changes/recommendations
        var changes: [String] = []
        
        // Find categories with highest spending
        if let topCategory = budgetCategories.first {
            changes.append("Consider reducing \(topCategory.name) spending by 5-10%")
        }
        
        // Add general recommendations
        if totalIncome > totalExpenses {
            let surplus = totalIncome - totalExpenses
            changes.append("You have a surplus of $\(String(format: "%.2f", surplus)) - consider increasing savings")
        } else if totalExpenses > totalIncome {
            let deficit = totalExpenses - totalIncome
            changes.append("You're overspending by $\(String(format: "%.2f", deficit)) - reduce expenses")
        }
        
        changes.append("Budget based on \(categories.count) categories from your CSV data")
        
        let budget = Budget(
            id: UUID(),
            monthlyTarget: budgetCategories.reduce(0) { $0 + $1.amount },
            categories: budgetCategories,
            changes: changes,
            createdDate: Date()
        )
        
        isProcessing = false
        onFinalize(budget)
    }
}

struct ChatBubble: View {
    let message: ChatMessage
    
    var body: some View {
        HStack {
            if message.isUser { Spacer() }
            
            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .font(.veraBodySmall())
                    .foregroundColor(message.isUser ? .white : .black)
                    .padding(12)
                    .background(message.isUser ? Color.veraLightGreen : Color.veraWhite)
                    .cornerRadius(16)
                    .cornerRadius(4, corners: message.isUser ? [.bottomRight] : [.bottomLeft])
                
                Text(message.timestamp, style: .time)
                    .font(.veraCaption())
                    .foregroundColor(.black.opacity(0.5))
            }
            .frame(maxWidth: 280, alignment: message.isUser ? .trailing : .leading)
            
            if !message.isUser { Spacer() }
        }
    }
}

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}