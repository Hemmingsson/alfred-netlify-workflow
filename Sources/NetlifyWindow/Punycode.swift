/// Shows punycode domains in Unicode (`xn--spo-qla.com` reads `säpo.com`): a small RFC 3492 decoder.
enum Punycode {
    /// `host` with every `xn--` label decoded; labels that don't decode stay as they are.
    static func displayHost(_ host: String) -> String {
        guard host.lowercased().contains("xn--") else { return host }
        return host.split(separator: ".", omittingEmptySubsequences: false).map { label in
            let lower = label.lowercased()
            guard lower.hasPrefix("xn--"), let decoded = decode(String(lower.dropFirst(4))) else { return String(label) }
            return decoded
        }.joined(separator: ".")
    }

    private static let base = 36, tMin = 1, tMax = 26, skew = 38, damp = 700

    /// One label's punycode (without `xn--`) decoded, or nil when it isn't valid punycode.
    static func decode(_ input: String) -> String? {
        var output: [Unicode.Scalar] = []
        var encoded = Substring(input)
        if let delimiter = input.lastIndex(of: "-") {
            for scalar in input[..<delimiter].unicodeScalars {
                guard scalar.isASCII else { return nil }
                output.append(scalar)
            }
            encoded = input[input.index(after: delimiter)...]
        }
        var code = 128, index = 0, bias = 72
        var digits = encoded.unicodeScalars.makeIterator()
        var nextDigit = digits.next()
        while nextDigit != nil {
            let oldIndex = index
            var weight = 1
            var k = base
            while true {
                guard let scalar = nextDigit, let digit = value(of: scalar) else { return nil }
                nextDigit = digits.next()
                let (product, overflow1) = digit.multipliedReportingOverflow(by: weight)
                let (sum, overflow2) = index.addingReportingOverflow(product)
                guard !overflow1, !overflow2 else { return nil }
                index = sum
                let threshold = k <= bias ? tMin : (k >= bias + tMax ? tMax : k - bias)
                if digit < threshold { break }
                let (nextWeight, overflow3) = weight.multipliedReportingOverflow(by: base - threshold)
                guard !overflow3 else { return nil }
                weight = nextWeight
                k += base
            }
            let length = output.count + 1
            // Reject values outside Unicode before adding them or adapting the bias.
            guard index / length <= 0x10FFFF - code else { return nil }
            bias = adapt(index - oldIndex, length: length, first: oldIndex == 0)
            code += index / length
            index %= length
            guard let scalar = Unicode.Scalar(code) else { return nil }
            output.insert(scalar, at: index)
            index += 1
        }
        return String(String.UnicodeScalarView(output))
    }

    private static func value(of scalar: Unicode.Scalar) -> Int? {
        switch scalar.value {
        case 48...57: Int(scalar.value) - 22  // 0-9 are 26-35
        case 65...90: Int(scalar.value) - 65
        case 97...122: Int(scalar.value) - 97
        default: nil
        }
    }

    private static func adapt(_ delta: Int, length: Int, first: Bool) -> Int {
        var delta = first ? delta / damp : delta / 2
        delta += delta / length
        var k = 0
        while delta > ((base - tMin) * tMax) / 2 {
            delta /= base - tMin
            k += base
        }
        return k + (base - tMin + 1) * delta / (delta + skew)
    }
}
