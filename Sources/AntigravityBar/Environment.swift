import Foundation

public protocol SystemEnvironment: Sendable {
    func contentsOfDirectory(at url: URL, includingPropertiesForKeys: [URLResourceKey]?, options: FileManager.DirectoryEnumerationOptions) throws -> [URL]
    func attributesOfItem(atPath path: String) throws -> [FileAttributeKey : Any]
    func removeItem(at URL: URL) throws
    func enumerator(at url: URL, includingPropertiesForKeys keys: [URLResourceKey]?, options: FileManager.DirectoryEnumerationOptions) -> NSEnumerator?
    func readData(contentsOf url: URL) throws -> Data
}

public struct DefaultSystemEnvironment: @unchecked Sendable, SystemEnvironment {
    let fm = FileManager.default
    
    public init() {}
    
    public func contentsOfDirectory(at url: URL, includingPropertiesForKeys keys: [URLResourceKey]?, options: FileManager.DirectoryEnumerationOptions) throws -> [URL] {
        return try fm.contentsOfDirectory(at: url, includingPropertiesForKeys: keys, options: options)
    }
    
    public func attributesOfItem(atPath path: String) throws -> [FileAttributeKey : Any] {
        return try fm.attributesOfItem(atPath: path)
    }
    
    public func removeItem(at url: URL) throws {
        try fm.removeItem(at: url)
    }
    
    public func enumerator(at url: URL, includingPropertiesForKeys keys: [URLResourceKey]?, options: FileManager.DirectoryEnumerationOptions) -> NSEnumerator? {
        return fm.enumerator(at: url, includingPropertiesForKeys: keys, options: options)
    }
    
    public func readData(contentsOf url: URL) throws -> Data {
        return try Data(contentsOf: url)
    }
}
