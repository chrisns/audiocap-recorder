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

// First, extract symbol graphs
var status = try run("swift", [
    "package", "--allow-writing-to-package-directory", "generate-documentation",
    "--target", target,
    "--output-path", "/tmp/dummy", // We don't use this output, just need symbol extraction
    "--symbol-graph-minimum-access-level", "internal"
])

// Find the symbol graph directory dynamically
let buildDir = ".build"
var symbolGraphDir: String?

// Look for extracted-symbols directory
let enumerator = fileManager.enumerator(atPath: buildDir)
while let file = enumerator?.nextObject() as? String {
    if file.contains("extracted-symbols") && file.hasSuffix(target) {
        symbolGraphDir = buildDir + "/" + file
        break
    }
}

guard let validSymbolGraphDir = symbolGraphDir else {
    print("Error: Could not find symbol graph directory for target \(target)")
    print("Available files in \(buildDir):")
    if let files = try? fileManager.contentsOfDirectory(atPath: buildDir) {
        for file in files {
            print("  \(file)")
        }
    }
    exit(1)
}

print("Using symbol graph directory: \(validSymbolGraphDir)")

// HTML - Use docc directly with our documentation catalog
status = try run("/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/docc", [
    "convert", "Documentation.docc",
    "--additional-symbol-graph-dir", validSymbolGraphDir,
    "--output-path", htmlOut,
    "--transform-for-static-hosting"
])
if status != 0 { exit(status) }

// JSON: Copy the data directory from HTML output (contains JSON symbol data)
let htmlData = htmlOut + "/data"
print("Checking for HTML data directory at: \(htmlData)")
print("HTML output directory contents:")
if let contents = try? fileManager.contentsOfDirectory(atPath: htmlOut) {
    for item in contents {
        print("  \(item)")
    }
}

if fileManager.fileExists(atPath: htmlData) {
    try? fileManager.removeItem(atPath: jsonOut)
    try fileManager.copyItem(atPath: htmlData, toPath: jsonOut)
    print("Copied HTML data bundle to \(jsonOut) for JSON access.")
    status = 0
} else {
    print("Warning: No data directory found in HTML output")
    status = 1
}
if status != 0 { exit(status) }

print("Documentation generated at \(buildDocsRoot)\n- HTML: \(htmlOut)\n- JSON: \(jsonOut)")
