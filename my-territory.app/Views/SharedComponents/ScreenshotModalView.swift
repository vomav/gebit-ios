import SwiftUI

struct ScreenshotModalView: View {
    let imageURL: URL
    @Environment(\.dismiss) private var dismiss
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var imageSize: CGSize = .zero
    
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ScrollView([.horizontal, .vertical], showsIndicators: true) {
                    AsyncImage(url: imageURL) { phase in
                        switch phase {
                        case .empty:
                            VStack {
                                Spacer()
                                ProgressView()
                                    .scaleEffect(1.5)
                                Text("Loading screenshot...")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .padding(.top, 12)
                                Spacer()
                            }
                            .frame(width: geometry.size.width, height: geometry.size.height)
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(
                                    width: geometry.size.width * scale,
                                    height: geometry.size.height * scale
                                )
                                .gesture(
                                    MagnifyGesture()
                                        .onChanged { value in
                                            let newScale = lastScale * value.magnification
                                            scale = min(max(newScale, 1.0), 5.0)
                                        }
                                        .onEnded { value in
                                            let newScale = lastScale * value.magnification
                                            scale = min(max(newScale, 1.0), 5.0)
                                            lastScale = scale
                                        }
                                )
                                .onTapGesture(count: 2) {
                                    withAnimation {
                                        if scale > 1.0 {
                                            scale = 1.0
                                            lastScale = 1.0
                                        } else {
                                            scale = 2.5
                                            lastScale = 2.5
                                        }
                                    }
                                }
                        case .failure:
                            VStack(spacing: 12) {
                                Image(systemName: "photo.badge.exclamationmark")
                                    .font(.largeTitle)
                                    .foregroundStyle(.secondary)
                                Text("Failed to load screenshot")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(width: geometry.size.width, height: geometry.size.height)
                        @unknown default:
                            EmptyView()
                        }
                    }
                }
            }
            .background(Color.black)
            .navigationTitle("Screenshot")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}
