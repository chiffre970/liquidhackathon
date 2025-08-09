import Foundation
import UIKit

class CacheManager {
    static let shared = CacheManager()
    
    private let logger = TelemetryLogger.shared
    private let cacheQueue = DispatchQueue(label: "com.vera.cache", attributes: .concurrent)
    private let memoryCache = NSCache<NSString, CacheEntry>()
    private let diskCacheURL: URL
    
    // Cache configuration
    private let maxMemoryCacheSizeMB = 50
    private let maxDiskCacheSizeMB = 200
    private let defaultExpirationHours = LFM2Config.cacheExpirationHours
    
    private init() {
        // Setup disk cache directory
        let cacheDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        diskCacheURL = cacheDirectory.appendingPathComponent("LFM2Cache")
        
        // Create cache directory if needed
        try? FileManager.default.createDirectory(at: diskCacheURL, withIntermediateDirectories: true)
        
        // Configure memory cache
        memoryCache.totalCostLimit = maxMemoryCacheSizeMB * 1024 * 1024
        memoryCache.countLimit = 100
        
        // Setup cache cleanup
        setupCacheCleanup()
        
        logger.info("CacheManager initialized with disk cache at: \(diskCacheURL.path)")
    }
    
    // MARK: - Cache Entry
    
    private class CacheEntry: NSObject {
        let data: Data
        let expirationDate: Date
        let key: String
        
        init(data: Data, expirationDate: Date, key: String) {
            self.data = data
            self.expirationDate = expirationDate
            self.key = key
        }
        
        var isExpired: Bool {
            return Date() > expirationDate
        }
        
        var size: Int {
            return data.count
        }
    }
    
    // Codable wrapper for disk storage
    private struct DiskCacheEntry: Codable {
        let data: Data
        let expirationDate: Date
    }
    
    // MARK: - Public Interface
    
    func cache(_ value: String, forKey key: String, expirationHours: Int? = nil) {
        guard LFM2Config.cacheEnabled else { return }
        
        cacheQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            
            let data = Data(value.utf8)
            let expiration = Date().addingTimeInterval(TimeInterval((expirationHours ?? self.defaultExpirationHours) * 3600))
            let entry = CacheEntry(data: data, expirationDate: expiration, key: key)
            
            // Add to memory cache
            self.memoryCache.setObject(entry, forKey: key as NSString, cost: data.count)
            
            // Add to disk cache
            self.saveToDisk(entry)
            
            self.logger.debug("Cached value for key: \(key), expires: \(expiration)")
        }
    }
    
    func retrieve(forKey key: String) -> String? {
        guard LFM2Config.cacheEnabled else { return nil }
        
        return cacheQueue.sync {
            // Check memory cache first
            if let entry = memoryCache.object(forKey: key as NSString) {
                if !entry.isExpired {
                    logger.debug("Cache hit (memory) for key: \(key)")
                    return String(data: entry.data, encoding: .utf8)
                } else {
                    // Remove expired entry
                    memoryCache.removeObject(forKey: key as NSString)
                    logger.debug("Cache expired (memory) for key: \(key)")
                }
            }
            
            // Check disk cache
            if let entry = loadFromDisk(forKey: key) {
                if !entry.isExpired {
                    // Add back to memory cache
                    memoryCache.setObject(entry, forKey: key as NSString, cost: entry.size)
                    logger.debug("Cache hit (disk) for key: \(key)")
                    return String(data: entry.data, encoding: .utf8)
                } else {
                    // Remove expired entry
                    removeFromDisk(forKey: key)
                    logger.debug("Cache expired (disk) for key: \(key)")
                }
            }
            
            logger.debug("Cache miss for key: \(key)")
            return nil
        }
    }
    
    func remove(forKey key: String) {
        cacheQueue.async(flags: .barrier) { [weak self] in
            self?.memoryCache.removeObject(forKey: key as NSString)
            self?.removeFromDisk(forKey: key)
            self?.logger.debug("Removed cache for key: \(key)")
        }
    }
    
    func clearAll() {
        cacheQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            
            // Clear memory cache
            self.memoryCache.removeAllObjects()
            
            // Clear disk cache
            if let files = try? FileManager.default.contentsOfDirectory(at: self.diskCacheURL, includingPropertiesForKeys: nil) {
                for file in files {
                    try? FileManager.default.removeItem(at: file)
                }
            }
            
            self.logger.info("Cleared all cache")
        }
    }
    
    func clearExpired() {
        cacheQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            
            var expiredCount = 0
            
            // Clear expired entries from disk
            if let files = try? FileManager.default.contentsOfDirectory(at: self.diskCacheURL, includingPropertiesForKeys: nil) {
                for file in files {
                    if let entry = self.loadFromDisk(url: file), entry.isExpired {
                        try? FileManager.default.removeItem(at: file)
                        expiredCount += 1
                    }
                }
            }
            
            self.logger.info("Cleared \(expiredCount) expired cache entries")
        }
    }
    
    // MARK: - Disk Operations
    
    private func diskCacheFileURL(forKey key: String) -> URL {
        let fileName = key.data(using: .utf8)?.base64EncodedString() ?? key
        return diskCacheURL.appendingPathComponent(fileName)
    }
    
    private func saveToDisk(_ entry: CacheEntry) {
        let fileURL = diskCacheFileURL(forKey: entry.key)
        
        do {
            let encoder = PropertyListEncoder()
            let diskEntry = DiskCacheEntry(data: entry.data, expirationDate: entry.expirationDate)
            let encoded = try encoder.encode(diskEntry)
            try encoded.write(to: fileURL)
        } catch {
            logger.error("Failed to save cache to disk: \(error)")
        }
    }
    
    private func loadFromDisk(forKey key: String) -> CacheEntry? {
        let fileURL = diskCacheFileURL(forKey: key)
        return loadFromDisk(url: fileURL, key: key)
    }
    
    private func loadFromDisk(url: URL, key: String? = nil) -> CacheEntry? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        
        do {
            let decoder = PropertyListDecoder()
            let diskEntry = try decoder.decode(DiskCacheEntry.self, from: data)
            let cacheKey = key ?? url.lastPathComponent
            
            return CacheEntry(data: diskEntry.data, expirationDate: diskEntry.expirationDate, key: cacheKey)
        } catch {
            logger.error("Failed to load cache from disk: \(error)")
        }
        
        return nil
    }
    
    private func removeFromDisk(forKey key: String) {
        let fileURL = diskCacheFileURL(forKey: key)
        try? FileManager.default.removeItem(at: fileURL)
    }
    
    // MARK: - Cache Management
    
    private func setupCacheCleanup() {
        // Schedule periodic cleanup
        Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [weak self] _ in
            self?.clearExpired()
            self?.checkDiskCacheSize()
        }
        
        // Listen for memory warnings
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
    }
    
    @objc private func handleMemoryWarning() {
        logger.warning("Memory warning received, clearing memory cache")
        memoryCache.removeAllObjects()
    }
    
    private func checkDiskCacheSize() {
        cacheQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            
            var totalSize: Int64 = 0
            var fileURLs: [(URL, Date)] = []
            
            if let files = try? FileManager.default.contentsOfDirectory(at: self.diskCacheURL, includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey]) {
                for file in files {
                    if let attributes = try? file.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey]),
                       let size = attributes.fileSize,
                       let modified = attributes.contentModificationDate {
                        totalSize += Int64(size)
                        fileURLs.append((file, modified))
                    }
                }
            }
            
            let maxSize = Int64(self.maxDiskCacheSizeMB * 1024 * 1024)
            
            if totalSize > maxSize {
                // Sort by modification date (oldest first)
                fileURLs.sort { $0.1 < $1.1 }
                
                // Remove oldest files until under limit
                for (url, _) in fileURLs {
                    try? FileManager.default.removeItem(at: url)
                    totalSize -= Int64((try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
                    
                    if totalSize <= maxSize {
                        break
                    }
                }
                
                self.logger.info("Disk cache cleaned, size reduced to \(totalSize / 1024 / 1024) MB")
            }
        }
    }
    
    // MARK: - Statistics
    
    func getCacheStatistics() -> CacheStatistics {
        return cacheQueue.sync {
            var memorySize = 0
            var diskSize: Int64 = 0
            var entryCount = 0
            
            // Calculate disk cache size
            if let files = try? FileManager.default.contentsOfDirectory(at: diskCacheURL, includingPropertiesForKeys: [.fileSizeKey]) {
                entryCount = files.count
                for file in files {
                    if let size = try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                        diskSize += Int64(size)
                    }
                }
            }
            
            return CacheStatistics(
                memorySizeMB: Double(memorySize) / 1024 / 1024,
                diskSizeMB: Double(diskSize) / 1024 / 1024,
                entryCount: entryCount,
                hitRate: calculateHitRate()
            )
        }
    }
    
    private var cacheHits = 0
    private var cacheMisses = 0
    
    private func calculateHitRate() -> Double {
        let total = cacheHits + cacheMisses
        return total > 0 ? Double(cacheHits) / Double(total) * 100 : 0
    }
    
    struct CacheStatistics {
        let memorySizeMB: Double
        let diskSizeMB: Double
        let entryCount: Int
        let hitRate: Double
    }
}

// MARK: - Specialized Cache Methods

extension CacheManager {
    func cacheInferenceResult(prompt: String, result: String, type: String) {
        let key = generateCacheKey(prompt: prompt, type: type)
        cache(result, forKey: key)
    }
    
    func retrieveInferenceResult(prompt: String, type: String) -> String? {
        let key = generateCacheKey(prompt: prompt, type: type)
        return retrieve(forKey: key)
    }
    
    private func generateCacheKey(prompt: String, type: String) -> String {
        let combined = "\(type):\(prompt)"
        
        // Create a hash for the key to handle long prompts
        if let data = combined.data(using: .utf8) {
            let hash = data.base64EncodedString()
                .replacingOccurrences(of: "/", with: "_")
                .replacingOccurrences(of: "+", with: "-")
                .prefix(64)
            return String(hash)
        }
        
        return combined
    }
}