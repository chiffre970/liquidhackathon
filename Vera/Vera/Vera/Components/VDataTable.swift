import SwiftUI

struct VDataTable: View {
    struct Column {
        let title: String
        let key: String
        let width: CGFloat?
        
        init(title: String, key: String, width: CGFloat? = nil) {
            self.title = title
            self.key = key
            self.width = width
        }
    }
    
    let columns: [Column]
    let data: [[String: String]]
    var showDividers: Bool = true
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(columns, id: \.key) { column in
                    Text(column.title)
                        .font(.veraBodySmall())
                        .fontWeight(Typography.FontWeight.semibold)
                        .foregroundColor(.black)
                        .frame(width: column.width, alignment: .leading)
                        .frame(maxWidth: column.width == nil ? .infinity : nil)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                }
            }
            .background(Color.veraGrey.opacity(0.5))
            
            if showDividers {
                Divider()
                    .background(Color.veraDarkGreen.opacity(0.1))
            }
            
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    ForEach(Array(data.enumerated()), id: \.offset) { index, row in
                        HStack(spacing: 0) {
                            ForEach(columns, id: \.key) { column in
                                Text(row[column.key] ?? "")
                                    .font(.veraBodySmall())
                                    .foregroundColor(.black.opacity(0.8))
                                    .frame(width: column.width, alignment: .leading)
                                    .frame(maxWidth: column.width == nil ? .infinity : nil)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                            }
                        }
                        
                        if showDividers && index < data.count - 1 {
                            Divider()
                                .background(Color.veraDarkGreen.opacity(0.05))
                        }
                    }
                }
            }
        }
        .background(Color.veraWhite)
        .cornerRadius(DesignSystem.smallCornerRadius)
    }
}