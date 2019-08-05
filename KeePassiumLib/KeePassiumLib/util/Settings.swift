//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import Foundation

public protocol SettingsObserver: class {
    /// Called whenever settings have changed.
    /// Make sure to `subscribeToSettingsNotifications` first.
    func settingsDidChange(key: Settings.Keys)
}

public class SettingsNotifications {
    private weak var observer: SettingsObserver?
    
    public init(observer: SettingsObserver) {
        self.observer = observer
    }
    
    /// Starts observing notifications about settings changes.
    public func startObserving() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(settingsDidChange(_:)),
            name: Settings.Notifications.settingsChanged,
            object: nil)
    }
    
    /// Stops observing notifications about settings changes.
    public func stopObserving() {
        NotificationCenter.default.removeObserver(
            self,
            name: Settings.Notifications.settingsChanged,
            object: nil)
    }
    
    @objc private func settingsDidChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
            let keyString = userInfo[Settings.Notifications.userInfoKey] as? String else { return }
        
        guard let key = Settings.Keys(rawValue: keyString) else {
            assertionFailure("Unknown Settings.Keys value: \(keyString)")
            return
        }
        observer?.settingsDidChange(key: key)
    }
}

/// Singleton for KeePassium app settings.
public class Settings {
    public static let latestVersion = 3
    public static let current = Settings()
    
    public enum Keys: String {
        case testEnvironment
        case settingsVersion
        case firstLaunchTimestamp
        
        // Database list
        case filesSortOrder
        case backupFilesVisible

        // Database unlock
        case startupDatabase
        case rememberDatabaseKey
        case keepKeyFileAssociations
        case keyFileAssociations

        // AppLock and timeouts
        case appLockEnabled
        case biometricAppLockEnabled
        case lockAllDatabasesOnFailedPasscode
        case recentUserActivityTimestamp
        case appLockTimeout
        case databaseLockTimeout
        case clipboardTimeout

        // Database content
        case startWithSearch
        case groupSortOrder
        case entryListDetail
        case entryViewerPage

        // Backup
        case backupDatabaseOnSave
        case backupKeepingDuration
        
        // AutoFill
        case autoFillFinishedOK
        case copyTOTPOnAutoFill
        
        // Password generator
        case passwordGeneratorLength
        case passwordGeneratorIncludeLowerCase
        case passwordGeneratorIncludeUpperCase
        case passwordGeneratorIncludeSpecials
        case passwordGeneratorIncludeDigits
        case passwordGeneratorIncludeLookAlike
        case passcodeKeyboardType
    }

    /// Notification constants
    fileprivate enum Notifications {
        static let settingsChanged = Notification.Name("com.keepassium.SettingsChanged")
        static let userInfoKey = "changedKey" // userInfo dict key - which Settings.Keys was changed
    }

    // MARK: - Internal types
    
    public enum AppLockTimeout: Int {
        /// The start event of the timeout
        public enum TriggerMode {
            case userIdle
            case appMinimized
        }
        
        public static let allValues = [
            immediately, after3seconds, after15seconds, after30seconds,
            after1minute, after2minutes, after5minutes]
        
        case never = -1 // left for backward compatibility
        case immediately = 0
        case after3seconds = 3
        case after15seconds = 15
        case after30seconds = 30
        case after1minute = 60
        case after2minutes = 120
        case after5minutes = 300
        
        public var seconds: Int {
            return self.rawValue
        }
        
        public var triggerMode: TriggerMode {
            switch self {
            case .never,
                 .immediately,
                 .after3seconds:
                return .appMinimized
            default:
                return .userIdle
            }
        }
        
        public var fullTitle: String {
            switch self {
            case .never:
                return NSLocalizedString("Never", comment: "One of the possible values of the 'Lock Application Timeout' setting. This should be full description. Will be shown as 'Timeouts: Lock Application: Never'")
            case .immediately:
                return NSLocalizedString("Immediately", comment: "One of the possible values of the 'Lock Application Timeout' setting. This should be full description. Will be shown as 'Timeouts: Lock Database: Immediately'")
            default:
                let formatter = DateComponentsFormatter()
                formatter.allowedUnits = [.hour, .minute, .second]
                formatter.collapsesLargestUnit = true
                formatter.maximumUnitCount = 2
                formatter.unitsStyle = .full
                guard let result = formatter.string(from: TimeInterval(self.rawValue)) else {
                    assertionFailure()
                    return "?"
                }
                return result
            }
        }
        public var shortTitle: String {
            switch self {
            case .never:
                return NSLocalizedString("Never", comment: "One of the possible values of the 'Lock Application Timeout' setting. This should be as a short version of 'Never'. Will be shown as 'Timeouts: Lock Application: Never'")
            case .immediately:
                return NSLocalizedString("Immediately", comment: "One of the possible values of the 'Lock Application Timeout' setting. This should be a short description of 'Immediately'. Will be shown as 'Timeouts: Lock Application: Immediately'")
            default:
                let formatter = DateComponentsFormatter()
                formatter.allowedUnits = [.hour, .minute, .second]
                formatter.collapsesLargestUnit = true
                formatter.maximumUnitCount = 2
                formatter.unitsStyle = .brief
                guard let result = formatter.string(from: TimeInterval(self.rawValue)) else {
                    assertionFailure()
                    return "?"
                }
                return result
            }
        }
        public var description: String? {
            switch triggerMode {
            case .appMinimized:
                return NSLocalizedString("After leaving the app", comment: "A description for AppLock timeout trigger 'when the app is minimized'. For example: 'Lock Timeout: 3 seconds (After leaving the app)")
            case .userIdle:
                return NSLocalizedString("After last interaction", comment: "A description for AppLock timeout trigger event 'when the user is idle'. For example: 'Lock Timeout: 3 seconds (After last interaction)")
            }
        }
    }

    public enum DatabaseLockTimeout: Int, Comparable {
        public static let allValues = [
            immediately, /*after5seconds, after15seconds, */after30seconds,
            after1minute, after2minutes, after5minutes, after10minutes,
            after30minutes, after1hour, after2hours, after4hours, after8hours,
            after24hours, never]
        case never = -1
        case immediately = 0
        case after5seconds = 5
        case after15seconds = 15
        case after30seconds = 30
        case after1minute = 60
        case after2minutes = 120
        case after5minutes = 300
        case after10minutes = 600
        case after30minutes = 1800
        case after1hour = 3600
        case after2hours = 7200
        case after4hours = 14400
        case after8hours = 28800
        case after24hours = 86400

        public var seconds: Int {
            return self.rawValue
        }
        
        public static func < (a: DatabaseLockTimeout, b: DatabaseLockTimeout) -> Bool {
            return a.seconds < b.seconds
        }
        
        public var fullTitle: String {
            switch self {
            case .never:
                return NSLocalizedString("Never", comment: "One of the possible values of the 'Database Lock Timeout' setting. This should be full description. Will be shown as 'Timeouts: Lock Database: Never'")
            case .immediately:
                return NSLocalizedString("Immediately", comment: "One of the possible values of the 'Database Lock Timeout' setting. This should be full description. Will be shown as 'Timeouts: Lock Database: Immediately'")
            default:
                let formatter = DateComponentsFormatter()
                formatter.allowedUnits = [.hour, .minute, .second]
                formatter.collapsesLargestUnit = true
                formatter.maximumUnitCount = 2
                formatter.unitsStyle = .full
                guard let result = formatter.string(from: TimeInterval(self.rawValue)) else {
                    assertionFailure()
                    return "?"
                }
                return result
            }
        }
        public var shortTitle: String {
            switch self {
            case .never:
                return NSLocalizedString("Never", comment: "One of the possible values of the 'Database Lock Timeout' setting. This should be as a short version of 'Never'. Will be shown as 'Timeouts: Lock Database: Never'")
            case .immediately:
                return NSLocalizedString("Immediately", comment: "One of the possible values of the 'Database Lock Timeout' setting. This should be a short description of 'Immediately'. Will be shown as 'Timeouts: Lock Database: Immediately'")
            default:
                let formatter = DateComponentsFormatter()
                formatter.allowedUnits = [.hour, .minute, .second]
                formatter.collapsesLargestUnit = true
                formatter.maximumUnitCount = 2
                formatter.unitsStyle = .brief
                guard let result = formatter.string(from: TimeInterval(self.rawValue)) else {
                    assertionFailure()
                    return "?"
                }
                return result
            }
        }
        public var description: String? {
            switch self {
            case .immediately:
                return NSLocalizedString("When leaving the app", comment: "A description for the 'Close Database: Immediately'.")
            default:
                return nil
            }
        }
    }
    
    public enum ClipboardTimeout: Int {
        public static let allValues = [
            after10seconds, after20seconds, after30seconds, after1minute, after2minutes,
            after3minutes, after5minutes, after10minutes, after20minutes, never]
        case never = -1
        case after10seconds = 10
        case after20seconds = 20
        case after30seconds = 30
        case after1minute = 60
        case after2minutes = 120
        case after3minutes = 180
        case after5minutes = 300
        case after10minutes = 600
        case after20minutes = 1200

        public var seconds: Int {
            return self.rawValue
        }
        
        public var fullTitle: String {
            switch self {
            case .never:
                return NSLocalizedString("Never", comment: "One of the possible values of the 'Clear Clipboard Timeout' setting. This should be full description. Will be shown as 'Clear Clipboard: Never'")
            default:
                let formatter = DateComponentsFormatter()
                formatter.allowedUnits = [.hour, .minute, .second]
                formatter.collapsesLargestUnit = true
                formatter.maximumUnitCount = 2
                formatter.unitsStyle = .full
                guard let result = formatter.string(from: TimeInterval(self.rawValue)) else {
                    assertionFailure()
                    return "?"
                }
                return result
            }
        }
        public var shortTitle: String {
            switch self {
            case .never:
                return NSLocalizedString("Never", comment: "One of the possible values of the 'Clear Clipboard Timeout' setting. This should be a short version of 'Never'. Will be shown as 'Clear Clipboard: Never'")
            default:
                let formatter = DateComponentsFormatter()
                formatter.allowedUnits = [.hour, .minute, .second]
                formatter.collapsesLargestUnit = true
                formatter.maximumUnitCount = 2
                formatter.unitsStyle = .brief
                guard let result = formatter.string(from: TimeInterval(self.rawValue)) else {
                    assertionFailure()
                    return "?"
                }
                return result
            }
        }
    }
    
    /// Allowed age of backup files
    public enum BackupKeepingDuration: Int {
        public static let allValues: [BackupKeepingDuration] = [
            .forever, _1year, _6months, _4weeks, _1week, _1day, _4hours, _1hour
        ]
        case _1hour = 3600
        case _4hours = 14400
        case _1day = 86400
        case _1week = 604_800
        case _4weeks = 2_419_200
        case _6months = 15_552_000
        case _1year = 31_536_000
        case forever

        public var seconds: TimeInterval {
            switch self {
            case .forever:
                return TimeInterval.infinity
            default:
                return TimeInterval(self.rawValue)
            }
        }
        
        public var shortTitle: String {
            switch self {
            case .forever:
                return NSLocalizedString("Forever", comment: "One of the possible values of the 'Keep Backup Files (Duration)' setting. Please keep it short. Will be shown as 'Keep Backup Files: Forever'")
            default:
                let formatter = DateComponentsFormatter()
                formatter.allowedUnits = [.year, .month, .day, .hour]
                formatter.collapsesLargestUnit = true
                formatter.maximumUnitCount = 1
                formatter.unitsStyle = .full
                guard let result = formatter.string(from: TimeInterval(self.rawValue)) else {
                    assertionFailure()
                    return "?"
                }
                return result
            }
        }
        
        public var fullTitle: String {
            return shortTitle
        }
    }
    
    /// Info to show in the second line of entry lsists
    public enum EntryListDetail: Int {
        public static let allValues = [none, userName, password, url, notes, lastModifiedDate]
        
        case none
        case userName
        case password
        case url
        case notes
        case lastModifiedDate
        
        public var shortTitle: String {
            return longTitle
        }
        public var longTitle: String {
            switch self {
            case .none:
                return NSLocalizedString("None", comment: "One of the possible values of the 'Entry List Details' setting. Will be shown as 'Entry List Details   None', meaningin that no entry details will be shown in any lists.")
            case .userName:
                return NSLocalizedString("User Name", comment: "One of the possible values of the 'Entry List Details' setting; it refers to login information rather than person name. Will be shown as 'Entry List Details   User Name'.")
            case .password:
                return NSLocalizedString("Password", comment: "One of the possible values of the 'Entry List Details' setting. Will be shown as 'Entry List Details   Password'.")
            case .url:
                return NSLocalizedString("URL", comment: "One of the possible values of the 'Entry List Details' setting. URL stands for 'internet address' or 'internet link'. Will be shown as 'Entry List Details   URL'.")
            case .notes:
                return NSLocalizedString("Notes", comment: "One of the possible values of the 'Entry List Details' setting; it refers to comments or additional text information contained in an entry. Will be shown as 'Entry List Details   Notes'.")
            case .lastModifiedDate:
                return NSLocalizedString("Last Modified Date", comment: "One of the possible values of the 'Entry List Details' setting; it referst fo the most recent time when the entry was modified. Will be shown as 'Entry List Details   Last Modified Time'.")
            }
        }
    }

    /// Sort order of group lists
    public enum GroupSortOrder: Int {
        public static let allValues = [
            noSorting,
            nameAsc, nameDesc,
            creationTimeDesc, creationTimeAsc,
            modificationTimeDesc, modificationTimeAsc]
        
        case noSorting
        case nameAsc
        case nameDesc
        case creationTimeAsc
        case creationTimeDesc
        case modificationTimeAsc
        case modificationTimeDesc
        
        public var longTitle: String {
            switch self {
            case .noSorting:
                return NSLocalizedString("No Sorting", comment: "One of possible values of the 'Sort Groups By' setting (full title). Example: 'Sort Groups: No Sorting'")
            case .nameAsc:
                return NSLocalizedString("By Title (A..Z)", comment: "One of possible values of the 'Sort Groups By' setting (full title). Example: 'Sort Groups: By Title (A..Z)'")
            case .nameDesc:
                return NSLocalizedString("By Title (Z..A)", comment: "One of possible values of the 'Sort Groups By' setting (full title). Example: 'Sort Groups: By Title (Z..A)'")
            case .creationTimeAsc:
                return NSLocalizedString("By Creation Date (Old..New)", comment: "One of possible values of the 'Sort Groups By' setting (full title). Example: 'Sort Groups: By Creation Date (Old..New)'")
            case .creationTimeDesc:
                return NSLocalizedString("By Creation Date (New..Old)", comment: "One of possible values of the 'Sort Groups By' setting (full title). Example: 'Sort Groups: By Creation Date (New..Old)'")
            case .modificationTimeAsc:
                return NSLocalizedString("By Modification Date (Old..New)", comment: "One of possible values of the 'Sort Groups By' setting (full title). Example: 'Sort Groups: By Modification Date (Old..New)'")
            case .modificationTimeDesc:
                return NSLocalizedString("By Modification Date (New..Old)", comment:  "One of possible values of the 'Sort Groups By' setting (full title). Example: 'Sort Groups: By Modification Date (New..Old)'")
            }
        }
        public var shortTitle: String {
            switch self {
            case .noSorting:
                return NSLocalizedString("None", comment: "One of possible values of the 'Sort Groups By' setting (short title for 'No Sorting'). Example: 'Sort Groups: None'")
            case .nameAsc:
                return NSLocalizedString("A..Z", comment: "One of possible values of the 'Sort Groups By' setting (short title for 'Title (A..Z)'). Example: 'Sort Groups: A..Z'")
            case .nameDesc:
                return NSLocalizedString("Z..A", comment: "One of possible values of the 'Sort Groups By' setting (short title for 'Title (Z..A)'). Example: 'Sort Groups: Z..A'")
            case .creationTimeAsc:
                return NSLocalizedString("Creation Date", comment: "One of possible values of the 'Sort Groups By' setting (short title for 'By Creation Date (Old..New)'). Example: 'Sort Groups: Creation Date'")
            case .creationTimeDesc:
                return NSLocalizedString("Creation Date", comment: "One of possible values of the 'Sort Groups By' setting (short title for 'By Creation Date (New..Old)'). Example: 'Sort Groups: Creation Date'")
            case .modificationTimeAsc:
                return NSLocalizedString("Last Modified", comment: "One of possible values of the 'Sort Groups By' setting (short title for 'By Modification Date (Old..New)'). Example: 'Sort Groups: Last Modified'")
            case .modificationTimeDesc:
                return NSLocalizedString("Last Modified", comment: "One of possible values of the 'Sort Groups By' setting (short title for 'By Modification Date (New..Old)'). Example: 'Sort Groups: Last Modified'")
            }
        }
        /// Comparator function for sorting
        public func compare(_ group1: Group, _ group2: Group) -> Bool {
            switch self {
            case .noSorting:
                return false
            case .nameAsc:
                return group1.name.localizedStandardCompare(group2.name) == .orderedAscending
            case .nameDesc:
                return group1.name.localizedStandardCompare(group2.name) == .orderedDescending
            case .creationTimeAsc:
                return group1.creationTime.compare(group2.creationTime) == .orderedAscending
            case .creationTimeDesc:
                return group1.creationTime.compare(group2.creationTime) == .orderedDescending
            case .modificationTimeAsc:
                return group1.lastModificationTime.compare(group2.lastModificationTime) == .orderedAscending
            case .modificationTimeDesc:
                return group1.lastModificationTime.compare(group2.lastModificationTime) == .orderedDescending
            }
        }
        public func compare(_ entry1: Entry, _ entry2: Entry) -> Bool {
            switch self {
            case .noSorting:
                return false
            case .nameAsc:
                return entry1.title.localizedStandardCompare(entry2.title) == .orderedAscending
            case .nameDesc:
                return entry1.title.localizedStandardCompare(entry2.title) == .orderedDescending
            case .creationTimeAsc:
                return entry1.creationTime.compare(entry2.creationTime) == .orderedAscending
            case .creationTimeDesc:
                return entry1.creationTime.compare(entry2.creationTime) == .orderedDescending
            case .modificationTimeAsc:
                return entry1.lastModificationTime.compare(entry2.lastModificationTime) == .orderedAscending
            case .modificationTimeDesc:
                return entry1.lastModificationTime.compare(entry2.lastModificationTime) == .orderedDescending
            }
        }
    }
    
    /// Sort order of file lists
    public enum FilesSortOrder: Int {
        public static let allValues = [
            noSorting,
            nameAsc, nameDesc,
            creationTimeDesc, creationTimeAsc,
            modificationTimeDesc, modificationTimeAsc]
        
        case noSorting
        case nameAsc
        case nameDesc
        case creationTimeAsc
        case creationTimeDesc
        case modificationTimeAsc
        case modificationTimeDesc
        
        public var longTitle: String {
            switch self {
            case .noSorting:
                return NSLocalizedString("No Sorting", comment: "A settings option which defines sorting of items in lists. Example: 'Sort order   No Sorting'")
            case .nameAsc:
                return NSLocalizedString("Name (A..Z)", comment: "One of the possible values of the 'File Sort Order' setting. Will be displayed as 'File Sort Order: Name (A..Z)'")
            case .nameDesc:
                return NSLocalizedString("Name (Z..A)", comment: "One of the possible values of the 'File Sort Order' setting. Will be displayed as 'File Sort Order: Name (Z..A)'")
            case .creationTimeAsc:
                return NSLocalizedString("Date Created (Oldest First)", comment: "One of the possible values of the 'File Sort Order' setting. Will be displayed as 'File Sort Order: Date Created (Oldest First)")
            case .creationTimeDesc:
                return NSLocalizedString("Date Created (Recent First)", comment: "One of the possible values of the 'File Sort Order' setting. Will be displayed as 'File Sort Order: Date Created (Recent First)'")
            case .modificationTimeAsc:
                return NSLocalizedString("Date Modified (Oldest First)", comment: "One of the possible values of the 'File Sort Order' setting. Will be displayed as 'File Sort Order: Date Modified (Oldest First)'")
            case .modificationTimeDesc:
                return NSLocalizedString("Date Modified (Recent First)", comment: "One of the possible values of the 'File Sort Order' setting. Will be displayed as 'File Sort Order: Date Modified (Recent First)'")
            }
        }

        /// Comparator function for sorting.
        public func compare(_ lhs: URLReference, _ rhs: URLReference) -> Bool {
            switch self {
            case .noSorting:
                return false
            case .nameAsc:
                return lhs.info.fileName.localizedCaseInsensitiveCompare(rhs.info.fileName) == .orderedAscending
            case .nameDesc:
                return lhs.info.fileName.localizedCaseInsensitiveCompare(rhs.info.fileName) == .orderedDescending
            case .creationTimeAsc:
                guard let date1 = lhs.info.creationDate,
                    let date2 = rhs.info.creationDate else { return false }
                return date1.compare(date2) == .orderedAscending
            case .creationTimeDesc:
                guard let date1 = lhs.info.creationDate,
                    let date2 = rhs.info.creationDate else { return false }
                return date1.compare(date2) == .orderedDescending
            case .modificationTimeAsc:
                guard let date1 = lhs.info.modificationDate,
                    let date2 = rhs.info.modificationDate else { return false }
                return date1.compare(date2) == .orderedAscending
            case .modificationTimeDesc:
                guard let date1 = lhs.info.modificationDate,
                    let date2 = rhs.info.modificationDate else { return false }
                return date1.compare(date2) == .orderedDescending
            }
        }
    }
    
    /// Type of keyboard to use for App Lock passcode
    public enum PasscodeKeyboardType: Int {
        public static let allValues = [numeric, alphanumeric]
        case numeric
        case alphanumeric
        public var title: String {
            switch self {
            case .numeric:
                return NSLocalizedString("Numeric", comment: "Type of keyboard to show for App Lock passcode: digits-only.")
            case .alphanumeric:
                return NSLocalizedString("Alphanumeric", comment: "Type of keyboard to show for App Lock passcode: letters and digits.")
            }
        }
    }
    
    // MARK: - Internal
    
    /// True iff running in simulator or in TestFlight.
    public private(set) var isTestEnvironment: Bool
    
    /// True iff the app has never been launched before.
    public var isFirstLaunch: Bool { return _isFirstLaunch }
    
    public var settingsVersion: Int {
        get {
            let storedVersion = UserDefaults.appGroupShared
                .object(forKey: Keys.settingsVersion.rawValue)
                as? Int
            return storedVersion ?? 0
        }
        set {
            let oldValue = settingsVersion
            UserDefaults.appGroupShared.set(newValue, forKey: Keys.settingsVersion.rawValue)
            if newValue != oldValue {
                postChangeNotification(changedKey: Keys.settingsVersion)
            }
        }
    }
    
    /// Timestamp when the app was first launched (since install)
    public var firstLaunchTimestamp: Date {
        get {
            if let storedTimestamp = UserDefaults.appGroupShared
                .object(forKey: Keys.firstLaunchTimestamp.rawValue)
                as? Date
            {
                return storedTimestamp
            } else {
                let firstLaunchTimestamp = Date.now
                UserDefaults.appGroupShared.set(
                    firstLaunchTimestamp,
                    forKey: Keys.firstLaunchTimestamp.rawValue)
                return firstLaunchTimestamp
            }
        }
    }
    
#if DEBUG
    /// To be used for debug.
    public func resetFirstLaunchTimestampToNow() {
        UserDefaults.appGroupShared.set(
            Date.now,
            forKey: Keys.firstLaunchTimestamp.rawValue)
    }
#endif

    // MARK: - Database list
    
    /// Sort order for the file lists
    public var filesSortOrder: FilesSortOrder {
        get {
            if let rawValue = UserDefaults.appGroupShared
                .object(forKey: Keys.filesSortOrder.rawValue) as? Int,
                let sortOrder = FilesSortOrder(rawValue: rawValue)
            {
                return sortOrder
            }
            return FilesSortOrder.noSorting
        }
        set {
            let oldValue = filesSortOrder
            UserDefaults.appGroupShared.set(newValue.rawValue, forKey: Keys.filesSortOrder.rawValue)
            if newValue != oldValue {
                postChangeNotification(changedKey: Keys.filesSortOrder)
            }
        }
    }
    
    /// Whether to show backup files in file lists
    public var isBackupFilesVisible: Bool {
        get {
            let stored = UserDefaults.appGroupShared
                .object(forKey: Keys.backupFilesVisible.rawValue)
                as? Bool
            return stored ?? false
        }
        set {
            updateAndNotify(
                oldValue: isBackupFilesVisible,
                newValue: newValue,
                key: .backupFilesVisible)
        }
    }
    
    // MARK: - Database unlock
    
    /// Last used/default database file to open on app launch.
    public var startupDatabase: URLReference? {
        get {
            if let data = UserDefaults.appGroupShared.data(forKey: Keys.startupDatabase.rawValue) {
                return URLReference.deserialize(from: data)
            } else {
                return nil
            }
        }
        set {
            let oldValue = startupDatabase
            UserDefaults.appGroupShared.set(
                newValue?.serialize(),
                forKey: Keys.startupDatabase.rawValue)
            if newValue != oldValue {
                postChangeNotification(changedKey: Keys.startupDatabase)
            }
        }
    }
    
    /// Whether to store database's key in keychain after unlock
    public var isRememberDatabaseKey: Bool {
        get {
            let stored = UserDefaults.appGroupShared
                .object(forKey: Keys.rememberDatabaseKey.rawValue)
                as? Bool
            return stored ?? true
        }
        set {
            updateAndNotify(
                oldValue: isRememberDatabaseKey,
                newValue: newValue,
                key: .rememberDatabaseKey)
        }
    }
    
    /// Should we keep track of which key file is used with which database?
    public var isKeepKeyFileAssociations: Bool {
        get {
            if contains(key: Keys.keepKeyFileAssociations) {
                return UserDefaults.appGroupShared.bool(forKey: Keys.keepKeyFileAssociations.rawValue)
            } else {
                return true
            }
        }
        set {
            let oldValue = isKeepKeyFileAssociations
            UserDefaults.appGroupShared.set(newValue, forKey: Keys.keepKeyFileAssociations.rawValue)
            if !newValue {
                removeAllKeyFileAssociations()
            }
            if newValue != oldValue {
                postChangeNotification(changedKey: Keys.keepKeyFileAssociations)
            }
        }
    }
    
    /// Returns a URL reference to the key file last used with the given database.
    public func getKeyFileForDatabase(databaseRef: URLReference) -> URLReference? {
        guard let db2key = UserDefaults.appGroupShared
            .dictionary(forKey: Keys.keyFileAssociations.rawValue) else { return nil }
        
        let databaseID = databaseRef.info.fileName
        if let keyFileRefData = db2key[databaseID] as? Data {
            return URLReference.deserialize(from: keyFileRefData)
        } else { 
            return nil
        }
    }
    
    /// Associates given keyFile as the one used with the given database,
    /// (if enabled by `keepKeyFileAssociations`, otherwise does nothing).
    public func setKeyFileForDatabase(databaseRef: URLReference, keyFileRef: URLReference?) {
        guard isKeepKeyFileAssociations else { return }
        var db2key: Dictionary<String, Data> = [:]
        if let storedDict = UserDefaults.appGroupShared
            .dictionary(forKey: Keys.keyFileAssociations.rawValue)
        {
            for (storedDatabaseID, storedKeyFileRefData) in storedDict {
                guard let storedKeyFileRefData = storedKeyFileRefData as? Data else { continue }
                db2key[storedDatabaseID] = storedKeyFileRefData
            }
        }
        
        let databaseID = databaseRef.info.fileName
        db2key[databaseID] = keyFileRef?.serialize()
        UserDefaults.appGroupShared.setValue(db2key, forKey: Keys.keyFileAssociations.rawValue)
        postChangeNotification(changedKey: Keys.keyFileAssociations)
    }
    
    /// Removes any database associations with the given key file.
    public func forgetKeyFile(_ keyFileRef: URLReference) {
        guard isKeepKeyFileAssociations else { return }
        var db2key = Dictionary<String, Data>()
        if let storedDict = UserDefaults.appGroupShared
            .dictionary(forKey: Keys.keyFileAssociations.rawValue)
        {
            for (storedDatabaseID, storedKeyFileRefData) in storedDict {
                guard let storedKeyFileRefData = storedKeyFileRefData as? Data else { continue }
                if keyFileRef != URLReference.deserialize(from: storedKeyFileRefData) {
                    db2key[storedDatabaseID] = storedKeyFileRefData
                }
            }
        }
        UserDefaults.appGroupShared.setValue(db2key, forKey: Keys.keyFileAssociations.rawValue)
    }
    
    /// Removes all associations between databases and key files.
    public func removeAllKeyFileAssociations() {
        UserDefaults.appGroupShared.setValue(
            Dictionary<String, Data>(),
            forKey: Keys.keyFileAssociations.rawValue)
    }

    // MARK: - AppLock and other timeouts
    
    public var isAppLockEnabled: Bool {
        get {
            let stored = UserDefaults.appGroupShared
                .object(forKey: Keys.appLockEnabled.rawValue)
                as? Bool
            return stored ?? false
        }
        set {
            updateAndNotify(
                oldValue: isAppLockEnabled,
                newValue: newValue,
                key: .appLockEnabled)
        }
    }
    
    /// Whether the user can use TouchID/FaceID to unlock the app
    public var isBiometricAppLockEnabled: Bool {
        get {
            let stored = UserDefaults.appGroupShared
                .object(forKey: Keys.biometricAppLockEnabled.rawValue)
                as? Bool
            return stored ?? true
        }
        set {
            updateAndNotify(
                oldValue: isBiometricAppLockEnabled,
                newValue: newValue,
                key: .biometricAppLockEnabled)
        }
    }
    
    /// Whether to clear all database keys from keychain
    /// after a wrong AppLock passcode has been entered.
    public var isLockAllDatabasesOnFailedPasscode: Bool {
        get {
            let stored = UserDefaults.appGroupShared
                .object(forKey: Keys.lockAllDatabasesOnFailedPasscode.rawValue)
                as? Bool
            return stored ?? true
        }
        set {
            updateAndNotify(
                oldValue: isLockAllDatabasesOnFailedPasscode,
                newValue: newValue,
                key: .lockAllDatabasesOnFailedPasscode)
        }
    }
    
    /// Timestamp of most recent user activity event (touching or typing).
    public var recentUserActivityTimestamp: Date {
        get {
            if let storedTimestamp = UserDefaults.appGroupShared
                .object(forKey: Keys.recentUserActivityTimestamp.rawValue)
                as? Date
            {
                return storedTimestamp
            }
            return Date.now
        }
        set {
            if contains(key: Keys.recentUserActivityTimestamp) {
                // We'll ignore sub-second differences, just to avoid too frequent writes.
                // (They are probably cached, but anyway.)
                let oldWholeSeconds = floor(recentUserActivityTimestamp.timeIntervalSinceReferenceDate)
                let newWholeSeconds = floor(newValue.timeIntervalSinceReferenceDate)
                if newWholeSeconds == oldWholeSeconds {
                    return
                }
            }
            UserDefaults.appGroupShared.set(
                newValue,
                forKey: Keys.recentUserActivityTimestamp.rawValue)
            postChangeNotification(changedKey: Keys.recentUserActivityTimestamp)
        }
    }
    
    /// Timeout for automatically locking the app, in seconds.
    public var appLockTimeout: AppLockTimeout {
        get {
            if let rawValue = UserDefaults.appGroupShared
                .object(forKey: Keys.appLockTimeout.rawValue) as? Int,
                let timeout = AppLockTimeout(rawValue: rawValue)
            {
                return timeout
            }
            return AppLockTimeout.immediately
        }
        set {
            let oldValue = appLockTimeout
            UserDefaults.appGroupShared.set(newValue.rawValue, forKey: Keys.appLockTimeout.rawValue)
            if newValue != oldValue {
                postChangeNotification(changedKey: Keys.appLockTimeout)
            }
        }
    }
    
    /// Timeout for automatically locking the database, in seconds.
    public var databaseLockTimeout: DatabaseLockTimeout {
        get {
            if let rawValue = UserDefaults.appGroupShared
                    .object(forKey: Keys.databaseLockTimeout.rawValue) as? Int,
                let timeout = DatabaseLockTimeout(rawValue: rawValue)
            {
                return timeout
            }
            return DatabaseLockTimeout.after1hour
        }
        set {
            let oldValue = databaseLockTimeout
            UserDefaults.appGroupShared.set(
                newValue.rawValue,
                forKey: Keys.databaseLockTimeout.rawValue)
            if newValue != oldValue {
                postChangeNotification(changedKey: Keys.databaseLockTimeout)
            }
        }
    }
    
    /// Timeout for temporary clipboard content, in seconds.
    public var clipboardTimeout: ClipboardTimeout {
        get {
            if let rawValue = UserDefaults.appGroupShared
                    .object(forKey: Keys.clipboardTimeout.rawValue) as? Int,
                let timeout = ClipboardTimeout(rawValue: rawValue)
            {
                return timeout
            }
            return ClipboardTimeout.after1minute
        }
        set {
            let oldValue = clipboardTimeout
            UserDefaults.appGroupShared.set(newValue.rawValue, forKey: Keys.clipboardTimeout.rawValue)
            if newValue != oldValue {
                postChangeNotification(changedKey: Keys.clipboardTimeout)
            }
        }
    }
    
    // MARK: - Database view
    
    /// Automatically show search bar after opening a database.
    public var isStartWithSearch: Bool {
        get {
            let stored = UserDefaults.appGroupShared
                .object(forKey: Keys.startWithSearch.rawValue)
                as? Bool
            return stored ?? false
        }
        set {
            updateAndNotify(
                oldValue: isStartWithSearch,
                newValue: newValue,
                key: .startWithSearch)
        }
    }
    
    /// Which field to use for entry subtitles in ViewGroupVC
    public var groupSortOrder: GroupSortOrder {
        get {
            if let rawValue = UserDefaults.appGroupShared
                    .object(forKey: Keys.groupSortOrder.rawValue) as? Int,
                let sortOrder = GroupSortOrder(rawValue: rawValue)
            {
                return sortOrder
            }
            return GroupSortOrder.noSorting
        }
        set {
            let oldValue = groupSortOrder
            UserDefaults.appGroupShared.set(newValue.rawValue, forKey: Keys.groupSortOrder.rawValue)
            if newValue != oldValue {
                postChangeNotification(changedKey: Keys.groupSortOrder)
            }
        }
    }

    /// Which field to use for entry subtitles in ViewGroupVC
    public var entryListDetail: EntryListDetail {
        get {
            if let rawValue = UserDefaults.appGroupShared
                .object(forKey: Keys.entryListDetail.rawValue) as? Int,
                let detail = EntryListDetail(rawValue: rawValue)
            {
                return detail
            }
            return EntryListDetail.userName
        }
        set {
            let oldValue = entryListDetail
            UserDefaults.appGroupShared.set(newValue.rawValue, forKey: Keys.entryListDetail.rawValue)
            if newValue != oldValue {
                postChangeNotification(changedKey: Keys.entryListDetail)
            }
        }
    }
    
    /// Last used page/tab of the EntryViewer
    public var entryViewerPage: Int {
        get {
            let storedPage = UserDefaults.appGroupShared
                .object(forKey: Keys.entryViewerPage.rawValue) as? Int
            return storedPage ?? 0
        }
        set {
            updateAndNotify(
                oldValue: entryViewerPage,
                newValue: newValue,
                key: Keys.entryViewerPage)
        }
    }
    
    // MARK: - Backup
    
    /// Whether to create a backup copy everytime database is saved.
    public var isBackupDatabaseOnSave: Bool {
        get {
            let stored = UserDefaults.appGroupShared
                .object(forKey: Keys.backupDatabaseOnSave.rawValue)
                as? Bool
            return stored ?? true
        }
        set {
            updateAndNotify(
                oldValue: isBackupDatabaseOnSave,
                newValue: newValue,
                key: .backupDatabaseOnSave)
        }
    }
    
    /// Maximum allowed age of backup files
    public var backupKeepingDuration: BackupKeepingDuration {
        get {
            if let stored = UserDefaults.appGroupShared
                .object(forKey: Keys.backupKeepingDuration.rawValue) as? Int,
                let timeout = BackupKeepingDuration(rawValue: stored)
            {
                return timeout
            }
            return BackupKeepingDuration.forever
        }
        set {
            let oldValue = backupKeepingDuration
            UserDefaults.appGroupShared.set(
                newValue.rawValue,
                forKey: Keys.backupKeepingDuration.rawValue)
            if newValue != oldValue {
                postChangeNotification(changedKey: Keys.backupKeepingDuration)
            }
        }
    }
    
    // MARK: - AutoFill
    
    /// Is set to `false` while AutoFill is running,
    /// and set to `true` only after a controlled/graceful finish.
    /// If this flag is `false` on AutoFill start,
    /// the extension has previously crashed (likely went out of memory).
    public var isAutoFillFinishedOK: Bool {
        get {
            let stored = UserDefaults.appGroupShared
                .object(forKey: Keys.autoFillFinishedOK.rawValue)
                as? Bool
            return stored ?? true
        }
        set {
            updateAndNotify(
                oldValue: isAutoFillFinishedOK,
                newValue: newValue,
                key: Keys.autoFillFinishedOK)
            
            // `isAutoFillFinishedOK` is written just before a possible out of memory crash,
            // so we must make sure it has actually been written.
            UserDefaults.appGroupShared.synchronize()
        }
    }
    
    /// Whether to copy TOTP when auto-filling an entry.
    public var isCopyTOTPOnAutoFill: Bool {
        get {
            let stored = UserDefaults.appGroupShared
                .object(forKey: Keys.copyTOTPOnAutoFill.rawValue)
                as? Bool
            return stored ?? true
        }
        set {
            updateAndNotify(
                oldValue: isCopyTOTPOnAutoFill,
                newValue: newValue,
                key: .copyTOTPOnAutoFill)
        }
    }

    // MARK: - Password generator
    
    /// Password generator: length of generated passwords
    public var passwordGeneratorLength: Int {
        get {
            let stored = UserDefaults.appGroupShared
                .object(forKey: Keys.passwordGeneratorLength.rawValue)
                as? Int
            return stored ?? PasswordGenerator.defaultLength
        }
        set {
            updateAndNotify(
                oldValue: passwordGeneratorLength,
                newValue: newValue,
                key: .passwordGeneratorLength)
        }
    }
    public var passwordGeneratorIncludeLowerCase: Bool {
        get {
            let stored = UserDefaults.appGroupShared
                .object(forKey: Keys.passwordGeneratorIncludeLowerCase.rawValue)
                as? Bool
            return stored ?? true
        }
        set {
            updateAndNotify(
                oldValue: passwordGeneratorIncludeLowerCase,
                newValue: newValue,
                key: .passwordGeneratorIncludeLowerCase)
        }
    }
    public var passwordGeneratorIncludeUpperCase: Bool {
        get {
            let stored = UserDefaults.appGroupShared
                .object(forKey: Keys.passwordGeneratorIncludeUpperCase.rawValue)
                as? Bool
            return stored ?? true
        }
        set {
            updateAndNotify(
                oldValue: passwordGeneratorIncludeUpperCase,
                newValue: newValue,
                key: .passwordGeneratorIncludeUpperCase)
        }
    }
    public var passwordGeneratorIncludeSpecials: Bool {
        get {
            let stored = UserDefaults.appGroupShared
                .object(forKey: Keys.passwordGeneratorIncludeSpecials.rawValue)
                as? Bool
            return stored ?? true
        }
        set {
            updateAndNotify(
                oldValue: passwordGeneratorIncludeSpecials,
                newValue: newValue,
                key: .passwordGeneratorIncludeSpecials)
        }
    }
    public var passwordGeneratorIncludeDigits: Bool {
        get {
            let stored = UserDefaults.appGroupShared
                .object(forKey: Keys.passwordGeneratorIncludeDigits.rawValue)
                as? Bool
            return stored ?? true
        }
        set {
            updateAndNotify(
                oldValue: passwordGeneratorIncludeDigits,
                newValue: newValue,
                key: .passwordGeneratorIncludeDigits)
        }
    }
    public var passwordGeneratorIncludeLookAlike: Bool {
        get {
            let stored = UserDefaults.appGroupShared
                .object(forKey: Keys.passwordGeneratorIncludeLookAlike.rawValue)
                as? Bool
            return stored ?? false
        }
        set {
            updateAndNotify(
                oldValue: passwordGeneratorIncludeLookAlike,
                newValue: newValue,
                key: .passwordGeneratorIncludeLookAlike)
        }
    }
    
    /// Type of keyboard to show for App Lock passcode.
    public var passcodeKeyboardType: PasscodeKeyboardType {
        get {
            if let rawValue = UserDefaults.appGroupShared
                .object(forKey: Keys.passcodeKeyboardType.rawValue) as? Int,
                let keyboardType = PasscodeKeyboardType(rawValue: rawValue)
            {
                return keyboardType
            }
            return PasscodeKeyboardType.numeric
        }
        set {
            let oldValue = passcodeKeyboardType
            UserDefaults.appGroupShared.set(newValue.rawValue, forKey: Keys.passcodeKeyboardType.rawValue)
            if newValue != oldValue {
                postChangeNotification(changedKey: Keys.passcodeKeyboardType)
            }
        }
    }
    
    // MARK: - Internal vars and methods
    
    private var _isFirstLaunch: Bool
    private init() {
        if AppGroup.isMainApp {
            let lastPathComp = Bundle.main.appStoreReceiptURL?.lastPathComponent
            isTestEnvironment = lastPathComp == "sandboxReceipt"
            UserDefaults.appGroupShared.set(isTestEnvironment, forKey: Keys.testEnvironment.rawValue)
        } else {
            isTestEnvironment = UserDefaults.appGroupShared
                .object(forKey: Keys.testEnvironment.rawValue) as? Bool
                ?? false
        }

        let versionInfo = UserDefaults.appGroupShared
            .object(forKey: Keys.settingsVersion.rawValue) as? Int
        _isFirstLaunch = (versionInfo == nil)
    }

    // MARK: - Helper methods
    
    /// Updates stored value, and notifies observers if the new value is different.
    private func updateAndNotify(oldValue: Bool, newValue: Bool, key: Keys) {
        UserDefaults.appGroupShared.set(newValue, forKey: key.rawValue)
        if newValue != oldValue {
            postChangeNotification(changedKey: key)
        }
    }

    /// Updates stored value, and notifies observers if the new value is different.
    private func updateAndNotify(oldValue: Int, newValue: Int, key: Keys) {
        UserDefaults.appGroupShared.set(newValue, forKey: key.rawValue)
        if newValue != oldValue {
            postChangeNotification(changedKey: key)
        }
    }

    /// Checks if given key is present in UserDefaults
    private func contains(key: Keys) -> Bool {
        return UserDefaults.appGroupShared.object(forKey: key.rawValue) != nil
    }

    /// Sends a notification about settigns change.
    fileprivate func postChangeNotification(changedKey: Settings.Keys) {
        NotificationCenter.default.post(
            name: Notifications.settingsChanged,
            object: self,
            userInfo: [
                Notifications.userInfoKey: changedKey.rawValue
            ]
        )
    }
}
