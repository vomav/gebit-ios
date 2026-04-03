import SwiftUI

struct IconTabButton: View {
    let title: String
    let icon: String
    let tag: Int
    @Binding var selectedTab: Int
    
    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedTab = tag
            }
        } label: {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.title2)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .stroke(selectedTab == tag ? Color.blue : Color.secondary.opacity(0.3), lineWidth: 2)
                    )
                    .foregroundStyle(selectedTab == tag ? .blue : .secondary)
                
                Text(title)
                    .font(.caption)
                    .fontWeight(selectedTab == tag ? .semibold : .regular)
                    .foregroundStyle(selectedTab == tag ? .blue : .secondary)
                
                Rectangle()
                    .fill(selectedTab == tag ? Color.blue : Color.clear)
                    .frame(height: 2)
            }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }
}
