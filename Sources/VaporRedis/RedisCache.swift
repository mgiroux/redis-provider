import Redbird
import Cache
import Node
import JSON
import Core
import Foundation

/**
 Uses an underlying Redbird
 instance to conform to the CacheProtocol.
 */
public final class RedisCache: CacheProtocol {
    /**
     The underlying Redbird instance.
     */
    public let redbird: Redbird

    private let lock: NSLock
    
    /**
     Creates a RedisCache from the address,
     port, and password credentials.
     
     Password should be nil if not required.
     */
    public convenience init(address: String, port: Int, password: String? = nil) throws {
        let config = RedbirdConfig(address: address, port: UInt16(port), password: password)
        let redbird = try Redbird(config: config)
        self.init(redbird: redbird)
    }
    
    /**
     Create a new RedisCache from a Redbird.
     */
    public init(redbird: Redbird) {
        lock = NSLock()
        self.redbird = redbird
    }
    
    /**
     Returns a key from the underlying Redbird
     instance by using the GET command.
     Try to deserialize else return original
     */
    public func get(_ key: String) throws -> Node? {
        let resp: RespObject

        lock.lock()
        do {
            resp = try redbird.command("GET", params: [key])
        } catch {
            lock.unlock()
            throw error
        }
        lock.unlock()


        guard let result = try resp.toMaybeString() else {
            return nil
        }
        
        do {
            return try JSON(bytes: result.bytes).makeNode()
        } catch {
            return Node.string(result)
        }
    }
    
    /**
     Sets a key to the supplied value in the
     underlying Redbird instance using the
     SET command.
     Serializing Node if not a string
     */
    public func set(_ key: String, _ value: Node) throws {
        let string = try value.string ?? JSON(node: Node(value)).serialize().toString()
        lock.lock()
        defer { lock.unlock() }
        try redbird.command("SET", params: [key, string])
    }
    
    /**
     Deletes a key from the underlying Redbird
     instance using the DEL command.
     */
    public func delete(_ key: String) throws {
        lock.lock()
        defer { lock.unlock() }
            try redbird.command("DEL", params: [key])
    }
}