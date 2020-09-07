import Foundation


/// An asynchronously set result
public class AsyncResult<R, E: Error> {
    /// The condition variable
    private let condition = NSCondition()
    /// The result
    private var result: Result<R, E>!
    
    /// Sets the result
    ///
    ///  - Parameter result: The result
    public func set(_ result: Result<R, E>) {
        // Set result
        self.condition.lock()
        self.result = result
        
        // Awake waiting threads
        self.condition.broadcast()
        self.condition.unlock()
    }
    
    /// Blocks until the result is available and returns the success value or throws the error value
    ///
    ///  - Returns: The success value
    ///  - Throws: The error value
    public func await() throws -> R {
        // Await result
        self.condition.lock()
        while self.result == nil {
            self.condition.wait()
        }
        
        // Get result
        let result = self.result!
        self.condition.unlock()
        return try result.get()
    }
}


/// A OneDrive instance
public class OneDrive {
    /// The access token
    public let token: Token
    
    /// Creates a new OneDrive instance with token
    ///
    ///  - Parameter token: A login token
    public init(token: Token) {
        self.token = token
    }
    
    /// Reads a folder
    ///
    ///  - Parameters:
    ///     - folder: The absolute path of the folder to read
    ///     - timeout: The timeout for the request
    ///     - completion: The completion handler
    public func read(folder path: String, timeout: TimeInterval = 10.0,
                     completion: @escaping (Result<[DirectoryEntry], OneDriveError>) -> Void) {
        _ = DirectoryReader(token: self.token, path: path, timeout: timeout, completion: completion)
    }
    /// Reads a file
    ///
    ///  - Parameters:
    ///     - file: The absolute path of the file to read
    ///     - timeout: The timeout for the request
    ///     - completion: The completion handler
    public func read(file path: String, timeout: TimeInterval = 10.0,
                     completion: @escaping (Result<Data, OneDriveError>) -> Void) {
        _ = FileReader(token: self.token, path: path, timeout: timeout, completion: completion)
    }
    
    /// Creates a folder at the given absolute path
    ///
    ///  - Parameters:
    ///     - folder: The absolute path of the folder to create
    ///     - timeout: The timeout for the request
    ///     - completion: The completion handler
    public func create(folder path: String, timeout: TimeInterval = 10.0,
                       completion: @escaping (Result<Void, OneDriveError>) -> Void) {
        _ = DirectoryWriter(token: self.token, path: path, timeout: timeout, completion: completion)
    }
    /// Creates/replaces a file
    ///
    ///  - Parameters:
    ///     - file: The absolute path of the file to create
    ///     - data: The contents of the file to create
    ///     - timeout: The timeout for the request
    ///     - completion: The completion handler
    public func create(file path: String, data: Data, timeout: TimeInterval = 10.0,
                       completion: @escaping (Result<Void, OneDriveError>) -> Void) {
        _ = FileWriter(token: self.token, path: path, data: data, timeout: timeout, completion: completion)
    }
    
    /// Moves a folder
    ///
    ///  - Parameters:
    ///     - path: The absolute path of the entry to move
    ///     - newPath: The new absolute path (including the entry name!) to move the entry to
    ///     - timeout: The timeout for the request
    ///     - completion: The completion handler
    public func move(folder path: String, newPath: String, timeout: TimeInterval = 10.0,
                     completion: @escaping (Result<Void, OneDriveError>) -> Void) {
        _ = MoveOperation(token: self.token, path: path, newPath: newPath, timeout: timeout, completion: completion)
    }
    /// Moves a file and replaces any existing file at the target path
    ///
    ///  - Parameters:
    ///     - path: The absolute path of the entry to move
    ///     - newPath: The new absolute path (including the filename!) to move the entry to
    ///     - timeout: The timeout for the request
    ///     - completion: The completion handler
    public func move(path: String, newPath: String, timeout: TimeInterval = 10.0,
                     completion: @escaping (Result<Void, OneDriveError>) -> Void) {
        _ = MoveOperation(token: self.token, path: path, newPath: newPath, timeout: timeout, completion: completion)
    }
    
    /// Deletes an entry
    ///
    ///  - Parameters:
    ///     - path: The absolute path of the entry to delete
    ///     - timeout: The timeout for the request
    ///     - completion: The completion handler
    public func delete(path: String, timeout: TimeInterval = 10.0,
                       completion: @escaping (Result<Void, OneDriveError>) -> Void) {
        _ = DeleteOperation(token: self.token, path: path, timeout: timeout, completion: completion)
    }
}
