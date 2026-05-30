import Foundation

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
        return (try? decoder.decode(QRCodeSettings.self, from: data)) ?? .defaults
    }

    @discardableResult
    func save(_ settings: QRCodeSettings) throws -> QRCodeSettings {
        guard let userDefaults else {
            throw AppGroupError.unavailable(AppGroupConfiguration.identifier)
        }
        let updatedSettings = settings.withUpdatedTimestamp()
        let data = try encoder.encode(updatedSettings)
        userDefaults.set(data, forKey: AppGroupConfiguration.settingsKey)
        userDefaults.synchronize()
        return updatedSettings
    }
}
