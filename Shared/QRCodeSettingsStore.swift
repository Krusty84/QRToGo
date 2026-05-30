//
//  QRCodeSettingsStore.swift
//  QRToGo
//
//  Created by Sedoykin Alexey on 26/05/2026.
//

import Foundation

enum AppLanguage: String, Codable, CaseIterable, Identifiable {
    case system
    case english
    case simplifiedChinese

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .system: "settings.language.system"
        case .english: "settings.language.english"
        case .simplifiedChinese: "settings.language.simplifiedChinese"
        }
    }

    var locale: Locale {
        switch self {
        case .system:
            Locale.autoupdatingCurrent
        case .english:
            Locale(identifier: "en")
        case .simplifiedChinese:
            Locale(identifier: "zh-Hans")
        }
    }

    fileprivate var localizationCode: String? {
        switch self {
        case .system:
            nil
        case .english:
            "en"
        case .simplifiedChinese:
            "zh-Hans"
        }
    }
}

struct AppLanguageStore {
    private let userDefaults: UserDefaults?

    init(userDefaults: UserDefaults? = UserDefaults(suiteName: AppGroupConfiguration.identifier)) {
        self.userDefaults = userDefaults
    }

    func load() -> AppLanguage {
        guard
            let rawValue = userDefaults?.string(forKey: AppGroupConfiguration.appLanguageKey),
            let language = AppLanguage(rawValue: rawValue)
        else {
            return .system
        }
        return language
    }

    func save(_ language: AppLanguage) {
        userDefaults?.set(language.rawValue, forKey: AppGroupConfiguration.appLanguageKey)
        userDefaults?.synchronize()
    }
}

enum AppLocalization {
    static func string(_ key: String) -> String {
        string(key, language: AppLanguageStore().load())
    }

    static func string(_ key: String, language: AppLanguage) -> String {
        guard
            let localizationCode = language.localizationCode,
            let bundlePath = Bundle.main.path(forResource: localizationCode, ofType: "lproj"),
            let bundle = Bundle(path: bundlePath)
        else {
            return Bundle.main.localizedString(forKey: key, value: nil, table: nil)
        }

        return bundle.localizedString(forKey: key, value: nil, table: nil)
    }
}

struct QRCodeSettingsStore {
    private let userDefaults: UserDefaults?
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(userDefaults: UserDefaults? = UserDefaults(suiteName: AppGroupConfiguration.identifier)) {
        self.userDefaults = userDefaults
    }

    func load() throws -> QRCodeSettings {
        guard let userDefaults else {
            throw AppGroupError.unavailable(AppGroupConfiguration.identifier)
        }
        guard let data = userDefaults.data(forKey: AppGroupConfiguration.settingsKey) else {
            return .defaults
        }
        return ((try? decoder.decode(QRCodeSettings.self, from: data)) ?? .defaults).normalized()
    }

    @discardableResult
    func save(_ settings: QRCodeSettings) throws -> QRCodeSettings {
        guard let userDefaults else {
            throw AppGroupError.unavailable(AppGroupConfiguration.identifier)
        }
        let updatedSettings = settings.normalized().withUpdatedTimestamp()
        let data = try encoder.encode(updatedSettings)
        userDefaults.set(data, forKey: AppGroupConfiguration.settingsKey)
        userDefaults.synchronize()
        return updatedSettings
    }
}
