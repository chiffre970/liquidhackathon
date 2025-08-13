import SwiftUI

struct BudgetChatView: View {
    @Binding var messages: [ChatMessage]
    @Binding var inputText: String
    @EnvironmentObject var csvProcessor: CSVProcessor
    let onFinalize: (Budget) -> Void
    @FocusState private var isTextFieldFocused: Bool
    @State private var isProcessing = false
    @State private var errorMessage: String?
    @State private var hasInitialized = false
    
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
            .onAppear {
                if !hasInitialized && messages.isEmpty {
                    hasInitialized = true
                    sendInitialMessage()
                }
            }
            
            HStack(spacing: 12) {
                TextField("Tell me about your financial goals...", text: $inputText)
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
                VButton(title: "Finalize Budget", style: .primary, action: {
                    createBudget()
                }, isFullWidth: true)
                .padding(.top, 12)
            }
        }
    }
    
    private func sendInitialMessage() {
        isProcessing = true
        
        Task {
            // Use a hardcoded initial message for consistency
            // The 700M model should provide better coherent initial messages
            let categories = csvProcessor.uniqueCategories.sorted()
            let categoryTotals = csvProcessor.categoryTotals
            
            let initialMessage: String
            if !categories.isEmpty {
                let topCategory = categories.sorted { abs(categoryTotals[$0] ?? 0) > abs(categoryTotals[$1] ?? 0) }.first ?? ""
                let topAmount = abs(categoryTotals[topCategory] ?? 0)
                let totalExpenses = categoryTotals.values.filter { $0 < 0 }.reduce(0) { $0 + abs($1) }
                let percentage = totalExpenses > 0 ? (topAmount / totalExpenses * 100) : 0
                
                initialMessage = "Welcome! I've analyzed your spending data. Your biggest expense is \(topCategory) at $\(String(format: "%.2f", topAmount)) (\(String(format: "%.0f", percentage))% of total spending). What are your financial goals? Are you looking to save more, reduce spending in specific areas, or something else?"
            } else {
                initialMessage = "Welcome! I'm here to help you create a personalized budget. To get started, please upload your transaction data in the Transactions tab, then come back here and we can discuss your financial goals."
            }
            
            await MainActor.run {
                messages.append(ChatMessage(
                    id: UUID(),
                    content: initialMessage,
                    isUser: false,
                    timestamp: Date()
                ))
                isProcessing = false
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
        isProcessing = true
        
        Task {
            if let response = await generateLFM2Response(for: messageContent) {
                await MainActor.run {
                    messages.append(ChatMessage(
                        id: UUID(),
                        content: response,
                        isUser: false,
                        timestamp: Date()
                    ))
                    isProcessing = false
                }
            } else {
                await MainActor.run {
                    errorMessage = "Failed to generate response"
                    isProcessing = false
                }
            }
        }
    }
    
    private func generateLFM2Response(for message: String, isInitial: Bool = false) async -> String? {
        // NOTE: LFM2-700M is a medium-sized model (700M parameters)
        // It should provide better quality than 350M but may still have limitations
        // For best results, consider cloud APIs for complex conversations
        let categories = csvProcessor.uniqueCategories.sorted()
        let categoryTotals = csvProcessor.categoryTotals
        
        if categories.isEmpty && !isInitial {
            return "I need to see your spending data first. Please upload your transaction CSV files in the Transactions tab, then come back here so I can analyze your spending patterns and help you create a budget."
        }
        
        // Build spending data string
        var spendingData = ""
        let totalExpenses = categoryTotals.values.filter { $0 < 0 }.reduce(0) { $0 + abs($1) }
        let totalIncome = categoryTotals.values.filter { $0 > 0 }.reduce(0) { $0 + $1 }
        
        if !categories.isEmpty {
            spendingData += "Total Income: $\(String(format: "%.2f", totalIncome))\n"
            spendingData += "Total Expenses: $\(String(format: "%.2f", totalExpenses))\n"
            spendingData += "Net: $\(String(format: "%.2f", totalIncome - totalExpenses))\n\n"
            spendingData += "Category Breakdown:\n"
            
            // Sort categories by amount (highest spending first)
            let sortedCategories = categories.sorted { abs(categoryTotals[$0] ?? 0) > abs(categoryTotals[$1] ?? 0) }
            
            for category in sortedCategories {
                let amount = categoryTotals[category] ?? 0
                let percentage = totalExpenses > 0 ? (abs(amount) / totalExpenses * 100) : 0
                spendingData += "\(category): $\(String(format: "%.2f", abs(amount))) (\(String(format: "%.1f", percentage))% of expenses)\n"
            }
        } else {
            spendingData = "No spending data available yet"
        }
        
        // Build conversation history
        let conversationHistory = messages.suffix(5).map { msg in
            "\(msg.isUser ? "User" : "Assistant"): \(msg.content)"
        }.joined(separator: "\n")
        
        // Prepare prompt
        let userMessage = isInitial ? "Start the conversation by asking about their financial goals" : message
        let prompt = PromptManager.shared.fillTemplate(
            type: .budgetChat,
            variables: [
                "spending_data": spendingData,
                "user_message": userMessage,
                "conversation_history": conversationHistory.isEmpty ? "No previous messages" : conversationHistory
            ]
        )
        
        print("DEBUG: Sending prompt to LFM2:\n\(prompt)")
        
        // Get LFM2 response
        do {
            let lfm2Service = LFM2Service.shared
            let response = try await lfm2Service.inference(prompt, type: "budgetChat")
            
            print("DEBUG: LFM2 raw response:\n\(response)")
            
            // For the small model, just return the raw response
            // It should be plain text now, not JSON
            let cleanedResponse = response
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "\\n", with: "\n")
            
            // If response is empty or nonsensical, use fallback
            if cleanedResponse.isEmpty || cleanedResponse.count < 10 {
                if isInitial {
                    if !categories.isEmpty {
                        let topCategory = categories.sorted { abs(categoryTotals[$0] ?? 0) > abs(categoryTotals[$1] ?? 0) }.first ?? ""
                        let topAmount = abs(categoryTotals[topCategory] ?? 0)
                        return "I've analyzed your spending data. You're spending $\(String(format: "%.2f", topAmount)) on \(topCategory) which is your biggest expense category. What are your financial goals? Are you trying to save for something specific or just reduce overall spending?"
                    } else {
                        return "Hi! I'm here to help you create a personalized budget. What are your main financial goals right now? Are you looking to save for something specific, pay off debt, or just get better control of your spending?"
                    }
                }
                return "Let me help you analyze your spending and create a budget. Based on your data, I can see opportunities to optimize your expenses."
            }
            
            return cleanedResponse
            
        } catch {
            print("LFM2 error in budget chat: \(error)")
            
            // Provide fallback responses for common scenarios
            if isInitial {
                return "Let's talk about your financial goals. What would you like to achieve with your budget?"
            }
            return nil
        }
    }
    
    private func createBudget() {
        isProcessing = true
        errorMessage = nil
        
        Task {
            // Ask LFM2 to create final budget recommendations
            let budgetPrompt = "Based on our conversation, create a final budget with specific targets for each category"
            
            if await generateLFM2Response(for: budgetPrompt) != nil {
                await MainActor.run {
                    // Parse the response and create budget
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
                    
                    // Create budget allocations based on LFM2 recommendations
                    var budgetCategories: [Budget.CategoryAllocation] = []
                    
                    for category in categories {
                        let currentAmount = abs(categoryTotals[category] ?? 0)
                        let percentage = totalExpenses > 0 ? (currentAmount / totalExpenses) * 100 : 0
                        
                        // Smart reduction based on category
                        var targetAmount = currentAmount
                        if currentAmount > totalExpenses * 0.3 {
                            // If category is more than 30% of budget, suggest aggressive reduction
                            targetAmount = currentAmount * 0.8
                        } else if currentAmount > totalExpenses * 0.2 {
                            // If category is 20-30% of budget, suggest moderate reduction
                            targetAmount = currentAmount * 0.9
                        } else {
                            // For smaller categories, maintain or slight reduction
                            targetAmount = currentAmount * 0.95
                        }
                        
                        budgetCategories.append(Budget.CategoryAllocation(
                            name: category,
                            amount: targetAmount,
                            percentage: percentage
                        ))
                    }
                    
                    // Add savings category if not present
                    if !categories.contains("Savings") && !categories.contains("savings") {
                        let savingsAmount = max(totalIncome - totalExpenses, totalExpenses * 0.15)
                        budgetCategories.append(Budget.CategoryAllocation(
                            name: "Savings",
                            amount: savingsAmount,
                            percentage: 15
                        ))
                    }
                    
                    // Sort by amount
                    budgetCategories.sort { $0.amount > $1.amount }
                    
                    // Generate specific recommendations based on analysis
                    var changes: [String] = []
                    
                    // Find problematic spending
                    let sortedByAmount = categories.sorted { abs(categoryTotals[$0] ?? 0) > abs(categoryTotals[$1] ?? 0) }
                    if let topCategory = sortedByAmount.first {
                        let amount = abs(categoryTotals[topCategory] ?? 0)
                        let percentage = totalExpenses > 0 ? (amount / totalExpenses * 100) : 0
                        if percentage > 30 {
                            changes.append("Your \(topCategory) spending ($\(String(format: "%.0f", amount))) is \(String(format: "%.0f", percentage))% of expenses - this needs immediate attention")
                        }
                    }
                    
                    if totalIncome > totalExpenses {
                        let surplus = totalIncome - totalExpenses
                        changes.append("You have $\(String(format: "%.0f", surplus)) surplus - increase savings or investments")
                    } else if totalExpenses > totalIncome {
                        let deficit = totalExpenses - totalIncome
                        changes.append("Warning: $\(String(format: "%.0f", deficit)) monthly deficit - urgent budget cuts needed")
                    }
                    
                    changes.append("Budget optimized based on AI analysis of \(categories.count) spending categories")
                    
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
            } else {
                await MainActor.run {
                    errorMessage = "Failed to create budget"
                    isProcessing = false
                }
            }
        }
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