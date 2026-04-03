import Foundation

/// Parses an ISO date string and returns a display format like "MMM dd, yyyy".
/// Falls back to the given `fallback` string if the input is nil or empty.
func formatISODateToDisplay(_ dateString: String?, fallback: String = "") -> String {
    guard let dateString = dateString, !dateString.isEmpty else {
        return fallback
    }
    let isoFormatter = ISO8601DateFormatter()
    isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let date = isoFormatter.date(from: dateString) {
        let displayFormatter = DateFormatter()
        displayFormatter.dateFormat = "MMM dd, yyyy"
        return displayFormatter.string(from: date)
    }
    // Try without fractional seconds
    isoFormatter.formatOptions = [.withInternetDateTime]
    if let date = isoFormatter.date(from: dateString) {
        let displayFormatter = DateFormatter()
        displayFormatter.dateFormat = "MMM dd, yyyy"
        return displayFormatter.string(from: date)
    }
    // Try date-only format (yyyy-MM-dd)
    let dateOnlyFormatter = DateFormatter()
    dateOnlyFormatter.dateFormat = "yyyy-MM-dd"
    if let date = dateOnlyFormatter.date(from: dateString) {
        let displayFormatter = DateFormatter()
        displayFormatter.dateFormat = "MMM dd, yyyy"
        return displayFormatter.string(from: date)
    }
    return dateString
}

/// Parses an ISO date string and returns "dd-MM-yyyy" format.
func formatISODateToDDMMYYYY(_ dateString: String) -> String {
    let iso8601Formatter = ISO8601DateFormatter()
    if let date = iso8601Formatter.date(from: dateString) {
        let displayFormatter = DateFormatter()
        displayFormatter.dateFormat = "dd-MM-yyyy"
        return displayFormatter.string(from: date)
    }
    
    let dateFormatter = DateFormatter()
    dateFormatter.locale = Locale(identifier: "en_US_POSIX")
    
    let formats = [
        "yyyy-MM-dd'T'HH:mm:ss.SSSZ",
        "yyyy-MM-dd'T'HH:mm:ssZ",
        "yyyy-MM-dd'T'HH:mm:ss",
        "yyyy-MM-dd"
    ]
    
    for format in formats {
        dateFormatter.dateFormat = format
        if let date = dateFormatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateFormat = "dd-MM-yyyy"
            return displayFormatter.string(from: date)
        }
    }
    
    return dateString
}
