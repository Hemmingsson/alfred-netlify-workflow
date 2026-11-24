import Foundation

/// A short hash (64-bit FNV-1a, hex) that changes when what it is made from changes.
enum Fingerprint {
    static func of(_ data: Data) -> String {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in data {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01b3
        }
        let hex = String(hash, radix: 16)
        return String(repeating: "0", count: 16 - hex.count) + hex
    }

    static func of(_ text: String) -> String { of(Data(text.utf8)) }
}
