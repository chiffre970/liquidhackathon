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