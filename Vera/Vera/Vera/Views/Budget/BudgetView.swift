import SwiftUI

struct BudgetView: View {
    @State private var budgetMode: BudgetMode = .chat
    @State private var messages: [ChatMessage] = []
    @State private var inputText = ""
    @State private var finalizedBudget: Budget?
    
    enum BudgetMode {
        case chat
        case summary
    }
    
    var body: some View {
        VContainer {
            switch budgetMode {
            case .chat:
                BudgetChatView(
                    messages: $messages,
                    inputText: $inputText,
                    onFinalize: finalizeBudget
                )
            case .summary:
                BudgetSummaryView(
                    budget: finalizedBudget,
                    onNewBudget: startNewBudget
                )
            }
        }
        .onAppear {
            if messages.isEmpty {
                messages.append(ChatMessage(
                    id: UUID(),
                    content: "Hello! I'm here to help you create a personalized budget. Let's start by understanding your financial goals. What are you hoping to achieve with your budget?",
                    isUser: false,
                    timestamp: Date()
                ))
            }
        }
    }
    
    private func finalizeBudget(_ budget: Budget) {
        finalizedBudget = budget
        withAnimation(DesignSystem.Animation.medium) {
            budgetMode = .summary
        }
    }
    
    private func startNewBudget() {
        messages = []
        finalizedBudget = nil
        withAnimation(DesignSystem.Animation.medium) {
            budgetMode = .chat
        }
    }
}