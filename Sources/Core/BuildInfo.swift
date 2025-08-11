import Foundation

/// Build-time information injected during compilation
public struct BuildInfo {
    /// Semantic version of the build
    public static let version: String = {
        // This will be replaced by the build system with the actual version
        return ProcessInfo.processInfo.environment["AUDIOCAP_VERSION"] ?? "0.0.0-dev"
    }()
    
    /// Git commit hash (short)
    public static let gitCommit: String = {
        return ProcessInfo.processInfo.environment["AUDIOCAP_GIT_COMMIT"] ?? "unknown"
    }()
    
    /// Build timestamp
    public static let buildDate: String = {
        return ProcessInfo.processInfo.environment["AUDIOCAP_BUILD_DATE"] ?? "unknown"
    }()
    
    /// Full version string including build metadata
    public static let fullVersion: String = {
        var components = [version]
        
        if gitCommit != "unknown" {
            components.append("(\(gitCommit))")
        }
        
        if buildDate != "unknown" {
            components.append("built \(buildDate)")
        }
        
        return components.joined(separator: " ")
    }()
}
