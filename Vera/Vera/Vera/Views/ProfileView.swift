import SwiftUI
import UniformTypeIdentifiers

struct ProfileView: View {
    @EnvironmentObject var csvProcessor: CSVProcessor
    @State private var showingFilePicker = false
    @State private var showingErrorAlert = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                if csvProcessor.importedFiles.isEmpty {
                    VStack(spacing: 20) {
                        Text("Upload your transaction CSV files to get started")
                            .font(.custom("Inter", size: 17).weight(.semibold))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding()
                        
                        Button("Upload CSV") {
                            showingFilePicker = true
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.green)
                        .disabled(csvProcessor.isProcessing)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 15) {
                        HStack {
                            Text("Uploaded Files (\(csvProcessor.importedFiles.count))")
                                .font(.custom("Inter", size: 17).weight(.semibold))
                            
                            Spacer()
                            
                            Button("Upload More") {
                                showingFilePicker = true
                            }
                            .buttonStyle(.bordered)
                            .tint(.green)
                        }
                        
                        LazyVStack(spacing: 8) {
                            ForEach(csvProcessor.importedFiles, id: \.id) { file in
                                ImportedFileRow(file: file)
                            }
                        }
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
            .onChange(of: csvProcessor.errorMessage) { _, errorMessage in
                showingErrorAlert = errorMessage != nil
            }
        }
    }
}

struct ImportedFileRow: View {
    let file: ImportedFile
    
    var body: some View {
        HStack {
            Image(systemName: "doc.text")
                .foregroundColor(.green)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(file.name)
                    .font(.custom("Inter", size: 12).weight(.regular))
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                Text("Uploaded on \(file.importDate, style: .date)")
                    .font(.custom("Inter", size: 11).weight(.regular))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.green.opacity(0.05))
        .cornerRadius(6)
    }
}