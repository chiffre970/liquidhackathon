import SwiftUI

struct BudgetChatView: View {
    @Binding var messages: [ChatMessage]
    @Binding var inputText: String
    let onFinalize: (Budget) -> Void
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            Text("Budget")
                .font(.veraTitle())
                .foregroundColor(.veraDarkGreen)
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
                    Image(systemName: "paperplane.fill")
                        .font(.custom("Inter", size: 16))
                        .foregroundColor(.veraWhite)
                        .rotationEffect(.degrees(45))
                        .padding(12)
                        .background(inputText.isEmpty ? Color.veraGrey : Color.veraLightGreen)
                        .clipShape(Circle())
                }
                .disabled(inputText.isEmpty)
            }
            .padding(.top, 12)
            
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
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            let aiResponse = generateAIResponse(for: messageContent)
            messages.append(ChatMessage(
                id: UUID(),
                content: aiResponse,
                isUser: false,
                timestamp: Date()
            ))
        }
    }
    
    private func generateAIResponse(for message: String) -> String {
        let responses = [
            "That's a great goal! Based on your spending history, I can see opportunities to optimize your budget. Would you like to focus on reducing discretionary spending or increasing savings?",
            "I understand. Let me analyze your transaction patterns to create a realistic budget. Your current spending shows room for improvement in entertainment and shopping categories.",
            "Excellent choice! I'll create a budget that allocates 20% to savings while maintaining your essential expenses. This should help you reach your goals faster.",
            "Based on our discussion, I've prepared a budget that balances your needs with your financial goals. Ready to review it?"
        ]
        
        return responses[min(messages.filter { $0.isUser }.count, responses.count - 1)]
    }
    
    private func createBudget() {
        let budget = Budget(
            id: UUID(),
            monthlyTarget: 7000,
            categories: [
                Budget.CategoryAllocation(name: "Housing", amount: 2400, percentage: 34),
                Budget.CategoryAllocation(name: "Food", amount: 700, percentage: 10),
                Budget.CategoryAllocation(name: "Transportation", amount: 450, percentage: 6),
                Budget.CategoryAllocation(name: "Entertainment", amount: 280, percentage: 4),
                Budget.CategoryAllocation(name: "Shopping", amount: 420, percentage: 6),
                Budget.CategoryAllocation(name: "Healthcare", amount: 350, percentage: 5),
                Budget.CategoryAllocation(name: "Savings", amount: 2400, percentage: 35)
            ],
            changes: [
                "Reduced entertainment spending by $120/month",
                "Decreased shopping budget by $180/month",
                "Increased savings allocation by $400/month"
            ],
            createdDate: Date()
        )
        
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
                    .foregroundColor(message.isUser ? .white : .veraDarkGreen)
                    .padding(12)
                    .background(message.isUser ? Color.veraLightGreen : Color.veraWhite)
                    .cornerRadius(16)
                    .cornerRadius(4, corners: message.isUser ? [.bottomRight] : [.bottomLeft])
                
                Text(message.timestamp, style: .time)
                    .font(.veraCaption())
                    .foregroundColor(.veraDarkGreen.opacity(0.5))
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