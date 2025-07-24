//
//  UpdateChecker.swift
//  PresentInk
//
//  Created by Erwin van Hunen on 2025-07-24.
//

import Foundation
import AppKit


struct GitHubRelease: Codable {
    let tagName: String
    let htmlUrl: URL
    
    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case htmlUrl = "html_url"
    }
}

struct UpdateInfo {
    let hasUpdate: Bool
    let latestVersion: String
    let currentVersion: String
    let downloadURL: URL
}

enum UpdateError: Error, LocalizedError {
    case invalidURL
    case noData
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid update URL"
        case .noData:
            return "No data received from server"
        }
    }
}


class UpdateChecker {
    static public func checkForUpdates(completion: @escaping (Result<UpdateInfo, Error>) -> Void) {
        guard let url = URL(string: "https://api.github.com/repos/erwinvanhunen/presentink/releases/latest") else {
            completion(.failure(UpdateError.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("PresentInk/2.0 (macOS)", forHTTPHeaderField: "User-Agent")
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(UpdateError.noData))
                return
            }
            
            do {
                let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
                let currentVersion = self.getCurrentVersion()
                let latestVersion = release.tagName.trimmingCharacters(in: CharacterSet(charactersIn: "v"))
                
                let hasUpdate = self.isNewerVersion(latest: latestVersion, current: currentVersion)
                let updateInfo = UpdateInfo(
                    hasUpdate: hasUpdate,
                    latestVersion: latestVersion,
                    currentVersion: currentVersion,
                    downloadURL: release.htmlUrl
                )
                
                completion(.success(updateInfo))
            } catch {
                completion(.failure(error))
            }
        }
        
        task.resume()
    }
    
    static private func getCurrentVersion() -> String {
        return Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
    }
    
    static private func isNewerVersion(latest: String, current: String) -> Bool {
        let latestComponents = latest.components(separatedBy: ".").compactMap { Int($0) }
        let currentComponents = current.components(separatedBy: ".").compactMap { Int($0) }
        
        let maxCount = max(latestComponents.count, currentComponents.count)
        
        for i in 0..<maxCount {
            let latestVersion = i < latestComponents.count ? latestComponents[i] : 0
            let currentVersion = i < currentComponents.count ? currentComponents[i] : 0
            
            if latestVersion > currentVersion {
                return true
            } else if latestVersion < currentVersion {
                return false
            }
        }
        
        return false
    }
    
    static public func showStartupUpdateAlert(
        latestVersion: String,
        currentVersion: String,
        downloadURL: URL
    ) {
        let alert = NSAlert()
        alert.messageText = "Update Available"
        alert.informativeText =
            "PresentInk version \(latestVersion) is available. You are currently using version \(currentVersion)."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Download")
        alert.addButton(withTitle: "Remind Me Later")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            NSWorkspace.shared.open(downloadURL)
        }
    }
}

