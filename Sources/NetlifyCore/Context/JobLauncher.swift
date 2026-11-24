/// Starts a background job: a detached copy of the `netlify` binary, so Alfred doesn't wait for it.
public protocol JobLauncher: Sendable {
    /// Fire and forget. A job that finds its lock held exits at once, so starting one twice is harmless.
    func launch(_ job: BackgroundJob)
}
