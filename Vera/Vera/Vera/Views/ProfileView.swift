import SwiftUI
import UniformTypeIdentifiers

struct ProfileView: View {
    @StateObject private var csvProcessor = CSVProcessor()
    @State private var showingFilePicker = false
    @State private var showingErrorAlert = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                if csvProcessor.transactions.isEmpty {
                    VStack(spacing: 20) {
                        Text("Import your transaction CSV files to get started")
                            .font(.headline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding()
                        
                        Button("Import CSV") {
                            showingFilePicker = true
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.green)
                        .disabled(csvProcessor.isProcessing)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 15) {
                        HStack {
                            Text("Transactions (\(csvProcessor.transactions.count))")
                                .font(.headline)
                            
                            Spacer()
                            
                            Button("Import More") {
                                showingFilePicker = true
                            }
                            .buttonStyle(.bordered)
                            .tint(.green)
                        }
                        
                        List(csvProcessor.transactions) { transaction in
                            TransactionRow(transaction: transaction)
                        }
                        .listStyle(.plain)
                    }
                }
                
                if csvProcessor.isProcessing {
                    ProgressView("Processing CSV...")
                        .padding()
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Profile")
            .background(Color(.systemGray6))
            .fileImporter(
                isPresented: $showingFilePicker,
                allowedContentTypes: [UTType.commaSeparatedText],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    if let url = urls.first {
                        csvProcessor.importCSV(from: url)
                    }
                case .failure(let error):
                    csvProcessor.errorMessage = error.localizedDescription
                }
            }
            .alert("Import Error", isPresented: $showingErrorAlert) {
                Button("OK") { }
            } message: {
                Text(csvProcessor.errorMessage ?? "Unknown error occurred")
            }
            .onChange(of: csvProcessor.errorMessage) { errorMessage in
                showingErrorAlert = errorMessage != nil
            }
        }
    }
}

struct TransactionRow: View {
    let transaction: Transaction
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(transaction.description)
                    .font(.body)
                    .lineLimit(1)
                
                Spacer()
                
                Text(String(format: "$%.2f", abs(transaction.amount)))
                    .font(.body.weight(.medium))
                    .foregroundColor(transaction.amount >= 0 ? .green : .red)
            }
            
            HStack {
                Text(transaction.date, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if let counterparty = transaction.counterparty {
                    Text("• \(counterparty)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if let category = transaction.category {
                    Text(category)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.green.opacity(0.1))
                        .foregroundColor(.green)
                        .cornerRadius(4)
                }
            }
        }
        .padding(.vertical, 4)
    }
}