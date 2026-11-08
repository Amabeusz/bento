public final class ConfigLoader {
    public private(set) var current: Config
    public private(set) var lastError: ConfigError?

    public init() {
        current = try! parseConfig(defaultConfigText)
    }

    public func reload(text: String) {
        do {
            current = try parseConfig(text)
            lastError = nil
        } catch {
            lastError = error
        }
    }
}
