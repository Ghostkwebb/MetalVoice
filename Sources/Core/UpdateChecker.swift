import Foundation

public struct ReleaseInfo {
    public let tagName: String
    public let name: String
    public let body: String
    public let htmlURL: String
    public let downloadURL: String?
    public let isNewer: Bool
}

public class UpdateChecker: ObservableObject {
    public static let shared = UpdateChecker()
    
    public static let currentVersion: String = {
        if let ver = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            return ver
        }
        return "1.2.5"
    }()
    
    private let repo = "Ghostkwebb/MetalVoice"
    
    @Published public var isChecking: Bool = false
    @Published public var latestRelease: ReleaseInfo?
    @Published public var updateAvailable: Bool = false
    @Published public var errorMessage: String?
    
    public init() {}
    
    /// Compares two semver strings like "1.2.5" and "v1.2.6"
    public static func isVersion(_ newVer: String, newerThan currentVer: String) -> Bool {
        let cleanNew = newVer.trimmingCharacters(in: CharacterSet(charactersIn: "vV "))
        let cleanCur = currentVer.trimmingCharacters(in: CharacterSet(charactersIn: "vV "))
        
        let newParts = cleanNew.split(separator: ".").compactMap { Int($0.prefix { $0.isNumber }) }
        let curParts = cleanCur.split(separator: ".").compactMap { Int($0.prefix { $0.isNumber }) }
        
        let maxCount = max(newParts.count, curParts.count)
        for i in 0..<maxCount {
            let n = i < newParts.count ? newParts[i] : 0
            let c = i < curParts.count ? curParts[i] : 0
            if n > c { return true }
            if n < c { return false }
        }
        return false
    }
    
    /// Checks GitHub for the latest release
    public func checkForUpdates(completion: ((Result<ReleaseInfo, Error>) -> Void)? = nil) {
        guard let url = URL(string: "https://api.github.com/repos/\(repo)/releases/latest") else {
            completion?(.failure(NSError(domain: "UpdateChecker", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid API URL"])))
            return
        }
        
        DispatchQueue.main.async {
            self.isChecking = true
            self.errorMessage = nil
        }
        
        var request = URLRequest(url: url)
        request.setValue("MetalVoice-Updater", forHTTPHeaderField: "User-Agent")
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 10.0
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            defer {
                DispatchQueue.main.async { self?.isChecking = false }
            }
            
            if let error = error {
                DispatchQueue.main.async { self?.errorMessage = error.localizedDescription }
                completion?(.failure(error))
                return
            }
            
            guard let data = data else {
                let err = NSError(domain: "UpdateChecker", code: -2, userInfo: [NSLocalizedDescriptionKey: "No data received"])
                DispatchQueue.main.async { self?.errorMessage = err.localizedDescription }
                completion?(.failure(err))
                return
            }
            
            do {
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                let tagName = json?["tag_name"] as? String ?? ""
                let name = json?["name"] as? String ?? tagName
                let body = json?["body"] as? String ?? ""
                let htmlURL = json?["html_url"] as? String ?? "https://github.com/\(self?.repo ?? "")/releases/latest"
                
                var downloadURL: String? = nil
                if let assets = json?["assets"] as? [[String: Any]] {
                    for asset in assets {
                        if let assetName = asset["name"] as? String,
                           assetName.hasSuffix(".zip"),
                           let dl = asset["browser_download_url"] as? String {
                            downloadURL = dl
                            break
                        }
                    }
                }
                
                let newer = UpdateChecker.isVersion(tagName, newerThan: UpdateChecker.currentVersion)
                let release = ReleaseInfo(
                    tagName: tagName,
                    name: name,
                    body: body,
                    htmlURL: htmlURL,
                    downloadURL: downloadURL,
                    isNewer: newer
                )
                
                DispatchQueue.main.async {
                    self?.latestRelease = release
                    self?.updateAvailable = newer
                }
                completion?(.success(release))
            } catch {
                DispatchQueue.main.async { self?.errorMessage = error.localizedDescription }
                completion?(.failure(error))
            }
        }.resume()
    }
    
    /// Downloads and replaces the current CLI binary atomically
    public static func updateCLIBinary(downloadURL: String, currentExecutablePath: String, completion: @escaping (Result<String, Error>) -> Void) {
        guard let url = URL(string: downloadURL) else {
            completion(.failure(NSError(domain: "UpdateChecker", code: -3, userInfo: [NSLocalizedDescriptionKey: "Invalid download URL"])))
            return
        }
        
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let zipDest = tempDir.appendingPathComponent("update.zip")
        
        URLSession.shared.downloadTask(with: url) { localURL, _, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let localURL = localURL else {
                completion(.failure(NSError(domain: "UpdateChecker", code: -4, userInfo: [NSLocalizedDescriptionKey: "Download failed"])))
                return
            }
            
            do {
                try FileManager.default.moveItem(at: localURL, to: zipDest)
                
                // Unzip
                let unzipProc = Process()
                unzipProc.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
                unzipProc.arguments = ["-q", "-o", zipDest.path, "-d", tempDir.path]
                try unzipProc.run()
                unzipProc.waitUntilExit()
                
                let extractedCLI = tempDir.appendingPathComponent("MetalVoiceCLI")
                guard FileManager.default.fileExists(atPath: extractedCLI.path) else {
                    completion(.failure(NSError(domain: "UpdateChecker", code: -5, userInfo: [NSLocalizedDescriptionKey: "MetalVoiceCLI binary not found in release archive"])))
                    return
                }
                
                // Remove quarantine attribute so macOS doesn't block execution
                let xattrProc = Process()
                xattrProc.executableURL = URL(fileURLWithPath: "/usr/bin/xattr")
                xattrProc.arguments = ["-d", "-r", "com.apple.quarantine", extractedCLI.path]
                try? xattrProc.run()
                xattrProc.waitUntilExit()

                // Set executable permissions (0755)
                try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: extractedCLI.path)
                
                let execURL = URL(fileURLWithPath: currentExecutablePath)
                let parentDir = execURL.deletingLastPathComponent()
                
                if FileManager.default.isWritableFile(atPath: parentDir.path) {
                    let backupURL = parentDir.appendingPathComponent(".\(execURL.lastPathComponent).old")
                    _ = try? FileManager.default.removeItem(at: backupURL)
                    
                    if FileManager.default.fileExists(atPath: execURL.path) {
                        try? FileManager.default.moveItem(at: execURL, to: backupURL)
                    }
                    
                    do {
                        try FileManager.default.moveItem(at: extractedCLI, to: execURL)
                        _ = try? FileManager.default.removeItem(at: backupURL)
                        try? FileManager.default.removeItem(at: tempDir)
                        completion(.success("MetalVoiceCLI updated successfully at \(execURL.path)!"))
                    } catch {
                        // Restore backup if replacement failed
                        if FileManager.default.fileExists(atPath: backupURL.path) {
                            _ = try? FileManager.default.moveItem(at: backupURL, to: execURL)
                        }
                        try? FileManager.default.removeItem(at: tempDir)
                        completion(.failure(error))
                    }
                } else {
                    try? FileManager.default.removeItem(at: tempDir)
                    completion(.failure(NSError(domain: "UpdateChecker", code: -6, userInfo: [NSLocalizedDescriptionKey: "Directory '\(parentDir.path)' is not writable. Please run with sudo: 'sudo \(execURL.path) --update' or download manually."])))
                }
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
}
