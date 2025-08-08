import SwiftUI

struct UploadsSection: View {
    @EnvironmentObject var csvProcessor: CSVProcessor
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your uploads")
                .font(.custom("Inter", size: Typography.FontSize.body).weight(Typography.FontWeight.semibold))
                .foregroundColor(.black.opacity(0.7))
            
            if csvProcessor.importedFiles.isEmpty {
                Text("No files uploaded yet")
                    .font(.veraBodySmall())
                    .foregroundColor(.black.opacity(0.4))
                    .padding(.vertical, 8)
            } else {
                ForEach(csvProcessor.importedFiles, id: \.id) { file in
                    HStack {
                        Image(systemName: "doc.text")
                            .font(.custom("Inter", size: 14))
                            .foregroundColor(.black)
                        
                        Text(file.name)
                            .font(.veraBodySmall())
                            .foregroundColor(.black)
                        
                        Spacer()
                        
                        Text(file.importDate, style: .date)
                            .font(.veraCaption())
                            .foregroundColor(.black.opacity(0.6))
                        
                        Button(action: { 
                            deleteFile(file)
                        }) {
                            Image(systemName: "trash")
                                .font(.custom("Inter", size: 14))
                                .foregroundColor(.red.opacity(0.6))
                        }
                    }
                    .padding(12)
                    .background(Color.veraWhite)
                    .cornerRadius(DesignSystem.tinyCornerRadius)
                }
            }
        }
    }
    
    private func deleteFile(_ file: ImportedFile) {
        csvProcessor.importedFiles.removeAll { $0.id == file.id }
    }
}