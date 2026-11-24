extension Sequence where Element: Sendable {
    /// `transform` applied to every element, at most `limit` at a time; the results in the sequence's order.
    @discardableResult
    public func concurrentMap<Result: Sendable>(
        limit: Int,
        _ transform: @escaping @Sendable (Element) async -> Result
    ) async -> [Result] {
        await withTaskGroup(of: (Int, Result).self) { group in
            var results: [(Int, Result)] = []
            var running = 0
            for (index, element) in enumerated() {
                if running == limit, let result = await group.next() {
                    results.append(result)
                    running -= 1
                }
                group.addTask { (index, await transform(element)) }
                running += 1
            }
            for await result in group {
                results.append(result)
            }
            return results.sorted { $0.0 < $1.0 }.map(\.1)
        }
    }
}
