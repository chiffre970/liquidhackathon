import Foundation

struct ImportedFile: Identifiable {
    let id = UUID()
    let name: String
    let url: URL
    let importDate: Date
}

class CSVProcessor: ObservableObject {
    @Published var isProcessing = false
    @Published var errorMessage: String?
    @Published var importedFiles: [ImportedFile] = []
    @Published var parsedTransactions: [Transaction] = []
    
    func importCSV(from url: URL) {
        print("📁 Starting CSV upload from: \(url.lastPathComponent)")
        isProcessing = true
        errorMessage = nil
        
        guard url.startAccessingSecurityScopedResource() else {
            let errorMsg = "Cannot access the selected file: \(url.lastPathComponent)"
            print("❌ CSV Upload Error: \(errorMsg)")
            DispatchQueue.main.async {
                self.errorMessage = errorMsg
                self.isProcessing = false
            }
            return
        }
        
        defer {
            url.stopAccessingSecurityScopedResource()
        }
        
        do {
            print("📖 Reading file content...")
            let content = try String(contentsOf: url, encoding: .utf8)
            print("✅ File content read successfully. Size: \(content.count) characters")
            
            DispatchQueue.main.async {
                let importedFile = ImportedFile(
                    name: url.lastPathComponent,
                    url: url,
                    importDate: Date()
                )
                self.importedFiles.append(importedFile)
                
                self.isProcessing = false
                print("✅ CSV Upload Success: \(url.lastPathComponent)")
                print("📋 Upload Summary:")
                print("   - File: \(url.lastPathComponent)")
                print("   - Upload Date: \(importedFile.importDate)")
                print("   - File Size: \(content.count) characters")
                print("   - Total Files Uploaded: \(self.importedFiles.count)")
            }
        } catch {
            let errorMsg = error.localizedDescription
            print("❌ CSV Upload Error: \(errorMsg)")
            print("   File: \(url.lastPathComponent)")
            DispatchQueue.main.async {
                self.errorMessage = "Failed to upload \(url.lastPathComponent): \(errorMsg)"
                self.isProcessing = false
            }
        }
    }
}