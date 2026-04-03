import Foundation

func isImageURL(_ urlString: String) -> Bool {
    let imageExtensions = ["png", "jpg", "jpeg", "gif", "webp", "bmp", "tiff", "heic", "heif", "svg"]
    let lowered = urlString.lowercased()
    return imageExtensions.contains { lowered.hasSuffix(".\($0)") || lowered.contains(".\($0)?") || lowered.contains(".\($0)&") }
}
