import SwiftUI

struct TransactionsView: View {
    @EnvironmentObject var csvProcessor: CSVProcessor
    @StateObject private var dataManager = DataManager.shared
    @State private var showingFilePicker = false
    @State private var transactions: [Transaction] = []
    @State private var isLoading = false
    
    var body: some View {
        VContainer {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Text("Transactions")
                        .font(.veraTitle())
                        .foregroundColor(.black)
                    
                    Spacer()
                    
                    Button(action: { showingFilePicker = true }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.custom("Inter", size: 24))
                            .foregroundColor(.black)
                    }
                }
                
                // Show processing status if active
                if csvProcessor.isProcessing {
                    VCard {
                        VStack(spacing: 12) {
                            Text(csvProcessor.processingStep.description)
                                .font(.veraBody())
                                .foregroundColor(.black)
                            
                            ProgressView(value: csvProcessor.processingProgress)
                                .progressViewStyle(LinearProgressViewStyle(tint: .veraLightGreen))
                            
                            if !csvProcessor.processingMessage.isEmpty {
                                Text(csvProcessor.processingMessage)
                                    .font(.veraCaption())
                                    .foregroundColor(.black.opacity(0.6))
                            }
                        }
                    }
                }
                
                UploadsSection()
                    .environmentObject(csvProcessor)
                
                TransactionsList(transactions: $transactions)
                
                Spacer()
            }
        }
        .sheet(isPresented: $showingFilePicker) {
            DocumentPicker { url in
                csvProcessor.importCSV(from: url)
            }
        }
        .onAppear {
            print("🔄 TransactionsView appeared, loading transactions...")
            loadTransactions()
        }
        .onChange(of: csvProcessor.parsedTransactions) { _, newValue in
            print("🔄 CSV Processor parsed transactions changed: \(newValue.count) transactions")
            loadTransactions()
        }
        .onChange(of: dataManager.transactions) { _, newValue in
            print("🔄 DataManager transactions changed: \(newValue.count) transactions")
            loadTransactions()
        }
    }
    
    private func loadTransactions() {
        // Load transactions from DataManager (includes all saved transactions)
        let allTransactions = dataManager.transactions
        print("📦 TransactionsView: Loading transactions from DataManager")
        print("   - Total in DataManager: \(allTransactions.count)")
        
        transactions = allTransactions.sorted { $0.date > $1.date }
        print("   - After sorting: \(transactions.count)")
        
        // Log first few transactions for debugging
        for (index, transaction) in transactions.prefix(3).enumerated() {
            print("   - Transaction \(index + 1): \(transaction.description) - $\(transaction.amount) - \(transaction.category ?? "uncategorized")")
        }
    }
}

struct DocumentPicker: UIViewControllerRepresentable {
    let onPick: (URL) -> Void
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.commaSeparatedText])
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (URL) -> Void
        
        init(onPick: @escaping (URL) -> Void) {
            self.onPick = onPick
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            onPick(url)
        }
    }
}