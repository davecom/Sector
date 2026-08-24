import Foundation

public extension Data {
    /// Returns a classic hex dump representation of the data.
    ///
    /// Each line consists of:
    /// - An 8-digit hexadecimal offset,
    /// - 16 bytes represented as two-digit uppercase hex values separated by spaces, grouped into two sets of 8 bytes with two spaces between the halves,
    /// - An ASCII column displaying printable ASCII characters (0x20...0x7E) or '.' for non-printable bytes.
    ///
    /// Lines contain 16 bytes each. The final line may be shorter if the data's length is not a multiple of 16.
    ///
    /// If the data is empty, returns an empty string.
    var hexDump: String {
        guard !self.isEmpty else { return "" }
        var result = String()
        result.reserveCapacity(self.count * 2)
        for byte in self {
            result.append(String(format: "%02X", byte))
        }
        return result
    }
}
