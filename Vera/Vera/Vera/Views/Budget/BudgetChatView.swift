import SwiftUI

struct BudgetChatView: View {
    @Binding var messages: [ChatMessage]
    @Binding var inputText: String
    let onFinalize: (Budget) -> Void
    @FocusState private var isTextFieldFocused: Bool
    @StateObject private var lfm2Manager = LFM2Manager.shared
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
                TextField("Help me create a monthly budget...", text: $inputText)
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
            
            if messages.count > 3 {
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
        isProcessing = true
        errorMessage = nil
        
        Task {
            do {
                let aiResponse = try await lfm2Manager.negotiateBudget(messageContent, context: messages)
                await MainActor.run {
                    messages.append(ChatMessage(
                        id: UUID(),
                        content: aiResponse,
                        isUser: false,
                        timestamp: Date()
                    ))
                    isProcessing = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to generate response: \(error.localizedDescription)"
                    isProcessing = false
                }
            }
        }
    }
    
    
    private func createBudget() {
        isProcessing = true
        errorMessage = nil
        
        Task {
            do {
                // Create a summary prompt for budget generation
                let chatSummary = messages.map { msg in
                    "\(msg.isUser ? "User" : "Assistant"): \(msg.content)"
                }.joined(separator: "\n")
                
                // Get current spending data from DataManager
                let currentMonth = Date()
                let transactions = DataManager.shared.fetchTransactions(for: currentMonth)
                
                // Calculate spending by category
                var categorySpending: [String: Double] = [:]
                for transaction in transactions where transaction.amount < 0 {
                    let category = transaction.category ?? "Other"
                    categorySpending[category, default: 0] += abs(transaction.amount)
                }
                
                // Use LFM2 to generate a budget based on the chat context
                let budgetPrompt = """
                Based on the following budget negotiation chat and current spending patterns, generate a monthly budget.
                
                Chat History:
                \(chatSummary)
                
                Current Monthly Spending:
                \(categorySpending.map { "\($0.key): $\(String(format: "%.2f", $0.value))" }.joined(separator: "\n"))
                
                Generate a JSON budget with:
                - monthlyTarget: total monthly budget amount
                - categories: array of {name, amount, percentage}
                - changes: array of recommended changes from current spending
                
                Return ONLY valid JSON.
                """
                
                let response = try await LFM2Service.shared.inference(budgetPrompt, type: "BudgetGenerator")
                
                // Parse the JSON response
                let budget = try parseBudgetFromResponse(response)
                
                await MainActor.run {
                    isProcessing = false
                    onFinalize(budget)
                }
            } catch {
                await MainActor.run {
                    isProcessing = false
                    errorMessage = "Failed to generate budget: \(error.localizedDescription)"
                    
                    // Fallback to a default budget if generation fails
                    let defaultBudget = Budget(
                        id: UUID(),
                        monthlyTarget: 5000,
                        categories: [
                            Budget.CategoryAllocation(name: "Housing", amount: 1500, percentage: 30),
                            Budget.CategoryAllocation(name: "Food & Dining", amount: 600, percentage: 12),
                            Budget.CategoryAllocation(name: "Transportation", amount: 400, percentage: 8),
                            Budget.CategoryAllocation(name: "Utilities", amount: 200, percentage: 4),
                            Budget.CategoryAllocation(name: "Shopping", amount: 300, percentage: 6),
                            Budget.CategoryAllocation(name: "Healthcare", amount: 250, percentage: 5),
                            Budget.CategoryAllocation(name: "Entertainment", amount: 250, percentage: 5),
                            Budget.CategoryAllocation(name: "Savings", amount: 1500, percentage: 30)
                        ],
                        changes: ["Budget generated from default template due to processing error"],
                        createdDate: Date()
                    )
                    onFinalize(defaultBudget)
                }
            }
        }
    }
    
    private func parseBudgetFromResponse(_ response: String) throws -> Budget {
        // Extract JSON from response
        var jsonString = response
        if let startIndex = response.firstIndex(of: "{"),
           let endIndex = response.lastIndex(of: "}") {
            jsonString = String(response[startIndex...endIndex])
        }
        
        guard let data = jsonString.data(using: .utf8) else {
            throw NSError(domain: "BudgetParsing", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid response format"])
        }
        
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        
        let monthlyTarget = json["monthlyTarget"] as? Double ?? 5000
        let categoriesArray = json["categories"] as? [[String: Any]] ?? []
        let changes = json["changes"] as? [String] ?? []
        
        let categories = categoriesArray.map { cat in
            Budget.CategoryAllocation(
                name: cat["name"] as? String ?? "Unknown",
                amount: cat["amount"] as? Double ?? 0,
                percentage: Double(cat["percentage"] as? Int ?? 0)
            )
        }
        
        return Budget(
            id: UUID(),
            monthlyTarget: monthlyTarget,
            categories: categories.isEmpty ? getDefaultCategories(for: monthlyTarget) : categories,
            changes: changes.isEmpty ? ["Budget optimized based on your spending patterns"] : changes,
            createdDate: Date()
        )
    }
    
    private func getDefaultCategories(for total: Double) -> [Budget.CategoryAllocation] {
        return [
            Budget.CategoryAllocation(name: "Housing", amount: total * 0.30, percentage: 30),
            Budget.CategoryAllocation(name: "Food & Dining", amount: total * 0.12, percentage: 12),
            Budget.CategoryAllocation(name: "Transportation", amount: total * 0.08, percentage: 8),
            Budget.CategoryAllocation(name: "Savings", amount: total * 0.30, percentage: 30),
            Budget.CategoryAllocation(name: "Other", amount: total * 0.20, percentage: 20)
        ]
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