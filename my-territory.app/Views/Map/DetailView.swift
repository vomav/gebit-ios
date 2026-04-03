import SwiftUI

struct DetailView: View {
    let category: Category
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack {
                    Image(systemName: category.icon)
                        .font(.system(size: 60))
                        .foregroundStyle(.tint)
                    
                    VStack(alignment: .leading) {
                        Text(category.name)
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        if let children = category.children {
                            Text("\(children.count) sub-items")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    Spacer()
                }
                
                Divider()
                
                // Content Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Details")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("This is the content area for **\(category.name)**. You can display any relevant information, forms, or data visualizations here.")
                        .font(.body)
                    
                    if let children = category.children, !children.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Sub-items:")
                                .font(.headline)
                                .padding(.top, 8)
                            
                            ForEach(children) { child in
                                HStack {
                                    Image(systemName: child.icon)
                                        .foregroundStyle(.secondary)
                                    Text(child.name)
                                    Spacer()
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }
                
                Spacer()
            }
            .padding()
        }
        .navigationTitle(category.name)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}
