import Foundation

enum StorageType: String {
    case swiftData
    case coreData
    
    static var current: StorageType {
        let defaults = UserDefaults.standard
        defaults.register(defaults: ["use_coredata": false])
        return defaults.bool(forKey: "use_coredata") ? .coreData : .swiftData
    }
}
