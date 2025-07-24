//
//  UpdateSettingsView.swift
//  PresentInk
//
//  Created by Erwin van Hunen on 2025-07-13.
//

import Cocoa

class UpdateSettingsView: NSView {
    private let titleLabel = NSTextField(labelWithString: "UPDATES")
    private let checkOnStartupLabel = NSTextField(labelWithString: "Check for new version on startup")
    private let checkOnStartupSwitch = NSSwitch()
    private let checkNowButton = NSButton(title: "Check Now", target: nil, action: nil)
    private let lastCheckedLabel = NSTextField(labelWithString: "Last checked: Today")
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupUI()
        loadSettings()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
        loadSettings()
    }
    
    private func setupUI() {
        // Configure title
        titleLabel.font = NSFont.boldSystemFont(ofSize: 12)
        titleLabel.textColor = NSColor.secondaryLabelColor
        titleLabel.isBezeled = false
        titleLabel.drawsBackground = false
        titleLabel.isEditable = false
        titleLabel.isSelectable = false
        
        // Configure check on startup label
        checkOnStartupLabel.font = NSFont.systemFont(ofSize: 12)
        checkOnStartupLabel.textColor = NSColor.labelColor
        checkOnStartupLabel.isBezeled = false
        checkOnStartupLabel.drawsBackground = false
        checkOnStartupLabel.isEditable = false
        checkOnStartupLabel.isSelectable = false
        
        // Configure switch
        checkOnStartupSwitch.target = self
        checkOnStartupSwitch.action = #selector(switchChanged)
        
        // Configure check now button
        checkNowButton.target = self
        checkNowButton.action = #selector(checkNowPressed)
        checkNowButton.bezelStyle = .rounded
        
        // Configure last checked label
        lastCheckedLabel.font = NSFont.systemFont(ofSize: 12)
        lastCheckedLabel.textColor = NSColor.secondaryLabelColor
        lastCheckedLabel.isBezeled = false
        lastCheckedLabel.drawsBackground = false
        lastCheckedLabel.isEditable = false
        lastCheckedLabel.isSelectable = false
        
        // Create horizontal stack for checkbox and label
        let checkboxStack = NSStackView(views: [checkOnStartupLabel, checkOnStartupSwitch])
        checkboxStack.orientation = .horizontal
        checkboxStack.spacing = 8
        checkboxStack.alignment = .centerY
        
        // Create horizontal stack for button and last checked
        let buttonStack = NSStackView(views: [checkNowButton, lastCheckedLabel])
        buttonStack.orientation = .horizontal
        buttonStack.spacing = 16
        buttonStack.alignment = .centerY
        
        // Main vertical stack
        let mainStack = NSStackView(views: [
            titleLabel,
            checkboxStack,
            buttonStack
        ])
        mainStack.orientation = .vertical
        mainStack.spacing = 16
        mainStack.alignment = .leading
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        
        addSubview(mainStack)
        NSLayoutConstraint.activate([
            mainStack.topAnchor.constraint(equalTo: topAnchor, constant: 32),
            mainStack.leadingAnchor.constraint(
                equalTo: leadingAnchor,
                constant: 32
            ),
            mainStack.trailingAnchor.constraint(
                lessThanOrEqualTo: trailingAnchor,
                constant: -32
            ),
            mainStack.bottomAnchor.constraint(
                lessThanOrEqualTo: bottomAnchor,
                constant: -32
            ),
        ])
    }
    
    private func loadSettings() {
        checkOnStartupSwitch.state = Settings.shared.checkForUpdatesOnStartup ? .on : .off
        updateLastCheckedLabel()
    }
    
    private func updateLastCheckedLabel() {
        if let lastChecked = Settings.shared.lastUpdateCheck {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            lastCheckedLabel.stringValue = "Last checked: \(formatter.string(from: lastChecked))"
        } else {
            lastCheckedLabel.stringValue = "Last checked: Never"
        }
    }
    
    @objc private func switchChanged() {
        Settings.shared.checkForUpdatesOnStartup = checkOnStartupSwitch.state == .on
    }
    
    @objc private func checkNowPressed() {
        checkNowButton.isEnabled = false
        checkNowButton.title = "Checking..."
        
        UpdateChecker.checkForUpdates { [weak self] result in
            DispatchQueue.main.async {
                self?.checkNowButton.isEnabled = true
                self?.checkNowButton.title = "Check Now"
                
                switch result {
                case .success(let updateInfo):
                    if updateInfo.hasUpdate {
                        self?.showUpdateAvailableAlert(updateInfo)
                    } else {
                        self?.showNoUpdateAlert()
                    }
                case .failure(let error):
                    self?.showErrorAlert(error)
                }
            }
        }
        
        Settings.shared.lastUpdateCheck = Date()
        updateLastCheckedLabel()
    }
    
//    private func checkForUpdates(completion: @escaping (Result<UpdateInfo, Error>) -> Void) {
//        guard let url = URL(string: "https://api.github.com/repos/erwinvanhunen/presentink/releases/latest") else {
//            completion(.failure(UpdateError.invalidURL))
//            return
//        }
//        
//        var request = URLRequest(url: url)
//        request.setValue("PresentInk/2.0 (macOS)", forHTTPHeaderField: "User-Agent")
//        
//        let task = URLSession.shared.dataTask(with: request) { data, response, error in
//            if let error = error {
//                completion(.failure(error))
//                return
//            }
//            
//            guard let data = data else {
//                completion(.failure(UpdateError.noData))
//                return
//            }
//            
//            do {
//                let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
//                let currentVersion = self.getCurrentVersion()
//                let latestVersion = release.tagName.trimmingCharacters(in: CharacterSet(charactersIn: "v"))
//                
//                let hasUpdate = self.isNewerVersion(latest: latestVersion, current: currentVersion)
//                let updateInfo = UpdateInfo(
//                    hasUpdate: hasUpdate,
//                    latestVersion: latestVersion,
//                    currentVersion: currentVersion,
//                    downloadURL: release.htmlUrl
//                )
//                
//                completion(.success(updateInfo))
//            } catch {
//                completion(.failure(error))
//            }
//        }
//        
//        task.resume()
//    }
    
//    private func getCurrentVersion() -> String {
//        return Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
//    }
//    
//    private func isNewerVersion(latest: String, current: String) -> Bool {
//        let latestComponents = latest.components(separatedBy: ".").compactMap { Int($0) }
//        let currentComponents = current.components(separatedBy: ".").compactMap { Int($0) }
//        
//        let maxCount = max(latestComponents.count, currentComponents.count)
//        
//        for i in 0..<maxCount {
//            let latestVersion = i < latestComponents.count ? latestComponents[i] : 0
//            let currentVersion = i < currentComponents.count ? currentComponents[i] : 0
//            
//            if latestVersion > currentVersion {
//                return true
//            } else if latestVersion < currentVersion {
//                return false
//            }
//        }
//        
//        return false
//    }
    
    private func showUpdateAvailableAlert(_ updateInfo: UpdateInfo) {
        let alert = NSAlert()
        alert.messageText = "Update Available"
        alert.informativeText = "A new version (\(updateInfo.latestVersion)) is available. You are currently using version \(updateInfo.currentVersion)."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Download")
        alert.addButton(withTitle: "Later")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            NSWorkspace.shared.open(updateInfo.downloadURL)
        }
    }
    
    private func showNoUpdateAlert() {
        let alert = NSAlert()
        alert.messageText = "No Updates Available"
        alert.informativeText = "You are running the latest version of PresentInk."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    private func showErrorAlert(_ error: Error) {
        let alert = NSAlert()
        alert.messageText = "Update Check Failed"
        alert.informativeText = "Unable to check for updates: \(error.localizedDescription)"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

// MARK: - Data Models
//
//struct GitHubRelease: Codable {
//    let tagName: String
//    let htmlUrl: URL
//    
//    enum CodingKeys: String, CodingKey {
//        case tagName = "tag_name"
//        case htmlUrl = "html_url"
//    }
//}
//
//struct UpdateInfo {
//    let hasUpdate: Bool
//    let latestVersion: String
//    let currentVersion: String
//    let downloadURL: URL
//}
//
//enum UpdateError: Error, LocalizedError {
//    case invalidURL
//    case noData
//    
//    var errorDescription: String? {
//        switch self {
//        case .invalidURL:
//            return "Invalid update URL"
//        case .noData:
//            return "No data received from server"
//        }
//    }
//}
