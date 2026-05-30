import Foundation

enum AppGroupConfiguration {
    static let identifier = "group.com.krusty84.QRToGo"
    static let settingsKey = "qrCodeSettings"
    static let importedFilesDirectoryName = "ImportedFiles"

    static func userDefaults() throws -> UserDefaults {
        guard let userDefaults = UserDefaults(suiteName: identifier) else {
            throw AppGroupError.unavailable(identifier)
        }
        return userDefaults
    }

    static func containerURL(fileManager: FileManager = .default) throws -> URL {
        guard let containerURL = fileManager.containerURL(forSecurityApplicationGroupIdentifier: identifier) else {
            throw AppGroupError.unavailable(identifier)
        }
        return containerURL
    }

    static func importedFilesDirectoryURL(fileManager: FileManager = .default) throws -> URL {
        let directoryURL = try containerURL(fileManager: fileManager)
            .appending(path: importedFilesDirectoryName, directoryHint: .isDirectory)
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        return directoryURL
    }
}

enum AppGroupError: LocalizedError {
    case unavailable(String)

    var errorDescription: String? {
        switch self {
        case .unavailable:
            NSLocalizedString("error.appGroupUnavailable", comment: "App Group unavailable")
        }
    }
}
