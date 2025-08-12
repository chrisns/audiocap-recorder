import Foundation

@discardableResult
func run(_ command: String, _ args: [String]) throws -> Int32 {
    let process = Process()
    process.launchPath = "/usr/bin/env"
    process.arguments = [command] + args

    let stdout = Pipe()
    let stderr = Pipe()
    process.standardOutput = stdout
    process.standardError = stderr

    try process.run()
    process.waitUntilExit()

    let status = process.terminationStatus
    if status != 0 {
        let errData = stderr.fileHandleForReading.readDataToEndOfFile()
        if let message = String(data: errData, encoding: .utf8) {
            FileHandle.standardError.write(Data(message.utf8))
        }
    }
    return status
}

let fileManager = FileManager.default
let buildDocsRoot = "build/docs"
let htmlOut = buildDocsRoot + "/html"
let jsonOut = buildDocsRoot + "/json"

// Ensure root exists and remove any stale outputs
try? fileManager.createDirectory(atPath: buildDocsRoot, withIntermediateDirectories: true)
try? fileManager.removeItem(atPath: htmlOut)
try? fileManager.removeItem(atPath: jsonOut)

let target = "AudiocapRecorder"

// HTML
var status = try run("swift", [
    "package", "--allow-writing-to-package-directory", "generate-documentation",
    "--target", target,
    "--output-path", htmlOut,
    "--format", "html",
    "--symbol-graph-minimum-access-level", "internal",
    "--transform-for-static-hosting"
])
if status != 0 { exit(status) }

// Try JSON via DocC; if it fails, fall back to copying HTML data JSON
status = try run("swift", [
    "package", "--allow-writing-to-package-directory", "generate-documentation",
    "--target", target,
    "--output-path", jsonOut,
    "--format", "json",
    "--symbol-graph-minimum-access-level", "internal",
    "--transform-for-static-hosting"
])
if status != 0 {
    // Fallback: copy HTML data bundle JSON
    let htmlData = htmlOut + "/data"
    if fileManager.fileExists(atPath: htmlData) {
        try? fileManager.removeItem(atPath: jsonOut)
        try fileManager.copyItem(atPath: htmlData, toPath: jsonOut)
        print("JSON generation via DocC failed; copied HTML data bundle to \(jsonOut) as fallback.")
        status = 0
    }
}
if status != 0 { exit(status) }

print("Documentation generated at \(buildDocsRoot)\n- HTML: \(htmlOut)\n- JSON: \(jsonOut)")
