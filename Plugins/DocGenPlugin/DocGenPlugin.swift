import PackagePlugin
import Foundation

@main
struct DocGenPlugin: CommandPlugin {
    func performCommand(context: PluginContext, arguments: [String]) async throws {
        let fileManager = FileManager.default
        let packageDirURL = context.package.directoryURL
        let outputRootURL = packageDirURL.appendingPathComponent("build/docs")
        try fileManager.createDirectory(at: outputRootURL, withIntermediateDirectories: true)

        let targetName = "AudiocapRecorder"
        let htmlOutURL = outputRootURL.appendingPathComponent("html")
        let jsonOutURL = outputRootURL.appendingPathComponent("json")

        // Clean any stale outputs
        try? fileManager.removeItem(at: htmlOutURL)
        try? fileManager.removeItem(at: jsonOutURL)

        func runSwift(_ args: [String]) throws {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process.arguments = ["swift"] + args
            let pipe = Pipe()
            let err = Pipe()
            process.standardOutput = pipe
            process.standardError = err
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else {
                let stderr = String(data: err.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                Diagnostics.error("DocC generation failed: \(stderr)")
                throw PluginError.commandFailed
            }
        }

        try runSwift([
            "package", "generate-documentation",
            "--target", targetName,
            "--output-path", htmlOutURL.path,
            "--format", "html",
            "--symbol-graph-minimum-access-level", "internal",
            "--transform-for-static-hosting"
        ])

        try runSwift([
            "package", "generate-documentation",
            "--target", targetName,
            "--output-path", jsonOutURL.path,
            "--format", "json",
            "--symbol-graph-minimum-access-level", "internal",
            "--transform-for-static-hosting"
        ])

        Diagnostics.remark("Documentation generated to \(outputRootURL.path)")
    }
}

enum PluginError: Error {
    case commandFailed
}
