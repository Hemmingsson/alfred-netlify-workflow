import Foundation

/// One JSON action for the Alfred UI window: what every `netlify ui …` call prints, and the `src` of a JSON
/// action. Nil parts are left out; Alfred runs the parts in its own fixed order.
public struct WindowReply: Encodable, Equatable, Sendable {
    /// Window variables to set (read in ui.json as `{var:name}`).
    public var variables: [String: SafeText]?
    /// The `update` command: component id to its changed properties.
    public var update: [String: ComponentChange]?
    /// The `replace` command: component id to the component that takes its place.
    public var replace: [String: Component]?
    /// The `functions` command: component id to a function name, e.g. `"sites": "filterdata"`.
    public var functions: [String: String]?
    public var pulse: Pulse?
    /// The `finish` command: close the window and hand this argument to the workflow (a `FinishArgument`).
    public var finish: SafeText?

    public init(
        variables: [String: SafeText]? = nil,
        update: [String: ComponentChange]? = nil,
        replace: [String: Component]? = nil,
        functions: [String: String]? = nil,
        pulse: Pulse? = nil,
        finish: SafeText? = nil
    ) {
        self.variables = variables
        self.update = update
        self.replace = replace
        self.functions = functions
        self.pulse = pulse
        self.finish = finish
    }

    /// Does nothing; prints `{}`.
    public static let nothing = WindowReply()

    /// The reply as one line of JSON, for stdout. Keys are sorted, so output is stable.
    public func json() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(self)
    }

    private enum CodingKeys: String, CodingKey {
        case variables, update, replace, functions, pulse, finish
    }

    private enum IDsKey: String, CodingKey {
        case ids
    }

    private enum FinishKeys: String, CodingKey {
        case args
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(variables, forKey: .variables)
        if let update {
            var ids = container.nestedContainer(keyedBy: IDsKey.self, forKey: .update)
            try ids.encode(update, forKey: .ids)
        }
        if let replace {
            var ids = container.nestedContainer(keyedBy: IDsKey.self, forKey: .replace)
            try ids.encode(replace, forKey: .ids)
        }
        if let functions {
            var ids = container.nestedContainer(keyedBy: IDsKey.self, forKey: .functions)
            try ids.encode(functions, forKey: .ids)
        }
        try container.encodeIfPresent(pulse, forKey: .pulse)
        if let finish {
            var args = container.nestedContainer(keyedBy: FinishKeys.self, forKey: .finish)
            try args.encode(finish, forKey: .args)
        }
    }
}
