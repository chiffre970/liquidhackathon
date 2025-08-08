import Foundation

enum Environment {
    case development
    case staging
    case production
    
    static var current: Environment {
        #if DEBUG
        return .development
        #else
        return .production
        #endif
    }
    
    var lfm2Config: LFM2ConfigProtocol {
        switch self {
        case .development:
            return LFM2ConfigDev()
        case .staging:
            return LFM2ConfigStaging()
        case .production:
            return LFM2ConfigProd()
        }
    }
    
    var name: String {
        switch self {
        case .development:
            return "Development"
        case .staging:
            return "Staging"
        case .production:
            return "Production"
        }
    }
    
    var isDebugMode: Bool {
        switch self {
        case .development:
            return true
        case .staging, .production:
            return false
        }
    }
}