import SwiftUI

struct TransactionsView: View {
    @EnvironmentObject var csvProcessor: CSVProcessor
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
                            .foregroundColor(.veraLightGreen)
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
                loadTransactions()
            }
        }
        .onAppear {
            loadTransactions()
        }
    }
    
    private func loadTransactions() {
        transactions = csvProcessor.parsedTransactions
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