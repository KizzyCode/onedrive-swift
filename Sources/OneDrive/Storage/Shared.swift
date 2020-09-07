import Foundation


/// A basic operation template (usually not used directly)
internal class OneDriveOperation<R> {
    /// The token
    internal let token: Token
    /// The path of the entry
    internal let path: String
    /// The completion handler
    internal let completion: (Result<R, OneDriveError>) -> Void
    /// The timeout for the request
    internal let timeout: TimeInterval
    
    /// Creates a basic operation skeleton
    ///
    ///  - Parameters:
    ///     - token: The access token
    ///     - path: The path of the entry to work with
    ///     - timeout: The timeout for the request
    ///     - gotAccessToken: The next step after obtaining an access token
    ///     - completion: The completion handler
    public init(token: Token, path: String, timeout: TimeInterval,
                completion: @escaping (Result<R, OneDriveError>) -> Void) {
        // Initialize self
        self.token = token
        self.path = path
        self.completion = completion
        self.timeout = timeout
    }
    
    /// Gets an access token or aborts the operation
    ///
    ///  - Parameter completion: The completion handler
    public func getAccessToken(completion: @escaping (String) -> Void) {
        self.token.accessToken(completion: {
            switch $0 {
                case .success(let accessToken): completion(accessToken)
                case .failure(let error): self.completion(.failure(error))
            }
        })
    }
}


/// A OneDrive move operation
internal class MoveOperation: OneDriveOperation<Void> {
    /// A parent reference
    private struct ParentReference: Encodable {
        /// The parent reference ID
        let id: String
    }
    
    /// A drive item
    private struct DriveItem: Decodable, JSONResponseObject {
        /// The item ID
        let id: String
    }
    
    /// A move request
    private struct MoveRequest: Encodable, JSONRequestObject {
        // Set coding keys
        enum CodingKeys: String, CodingKey {
            case parentReference = "parentReference"
            case name = "name"
            case conflictBehavior = "@microsoft.graph.conflictBehavior"
        }
        
        /// The parent reference
        let parentReference: ParentReference
        /// The entry name
        let name: String
        /// The conflict behavior policy
        let conflictBehavior = "replace"
    }
    
    /// The destination path
    private let newPath: URL
    /// The access token
    private var accessToken: String!
    
    /// Creates a move operator
    ///
    ///  - Parameters:
    ///     - token: The access token
    ///     - path: The path of the file to write
    ///     - newPath: The new absolute path (including the filename!) to move the entry to
    ///     - timeout: The timeout for the request
    ///     - completion: The completion handler
    public init(token: Token, path: String, newPath: String, timeout: TimeInterval,
                completion: @escaping (Result<Void, OneDriveError>) -> Void) {
        self.newPath = URL(fileURLWithPath: newPath)
        super.init(token: token, path: path, timeout: timeout, completion: completion)
        self.getAccessToken(completion: self.gotAccessToken(accessToken:))
    }
    
    /// The next step after obtaining an access token
    ///
    ///  - Parameter accessToken: The access token
    private func gotAccessToken(accessToken: String) {
        // Cache access token
        self.accessToken = accessToken
        
        // Get the parent reference
        let url: String
        switch self.newPath.deletingLastPathComponent().path {
            case "/": url = "https://graph.microsoft.com/v1.0/me/drive/root"
            case let parent: url = "https://graph.microsoft.com/v1.0/me/drive/root:\(parent)"
        }
        let request = HTTPRequest(url: url, method: "GET",
                                  headerFields: ["Authorization": "Bearer \(self.accessToken!)"],
                                  timeout: self.timeout)
        request.start(completion: self.gotParentReference(result:))
    }
    
    /// The completion handler after getting the parent reference
    ///
    ///  - Parameter result: The result
    private func gotParentReference(result: Result<DriveItem, OneDriveError>) {
        switch result {
            case .success(let parent):
                // Move the item
                let body = MoveRequest(parentReference: ParentReference(id: parent.id),
                                       name: self.newPath.lastPathComponent)
                let url = "https://graph.microsoft.com/v1.0/me/drive/root:\(self.path)"
                let request = HTTPRequest(url: url, method: "PATCH",
                                          headerFields: ["Authorization": "Bearer \(self.accessToken!)"],
                                          timeout: self.timeout)
                request.start(body: body, completion: self.didMove(result:))
                
            case .failure(let error):
                self.completion(.failure(error))
        }
    }
    
    /// The completion handler after moving the element
    ///
    ///  - Parameter result: The result
    private func didMove(result: Result<EmptyJSON, OneDriveError>) {
        self.completion(result.map({ _ in () }))
    }
}


/// A OneDrive delete operation
internal class DeleteOperation: OneDriveOperation<Void> {
    /// Creates a delete operator
    ///
    ///  - Parameters:
    ///     - token: The access token
    ///     - path: The path of the entry to delete
    ///     - timeout: The timeout for the request
    ///     - completion: The completion handler
    public override init(token: Token, path: String, timeout: TimeInterval,
                         completion: @escaping (Result<Void, OneDriveError>) -> Void) {
        super.init(token: token, path: path, timeout: timeout, completion: completion)
        self.getAccessToken(completion: self.gotAccessToken(accessToken:))
    }
    
    /// The next step after obtaining an access token
    ///
    ///  - Parameter accessToken: The access token
    private func gotAccessToken(accessToken: String) {
        // Get the parent reference
        let url: String
        switch self.path {
            case "/": return completion(.success(()))
            default: url = "https://graph.microsoft.com/v1.0/me/drive/root:\(self.path)"
        }
        let request = HTTPRequest(url: url, method: "DELETE", headerFields: ["Authorization": "Bearer \(accessToken)"],
                                  timeout: self.timeout)
        request.start(completion: self.didDelete(result:))
    }
    
    /// The completion handler after deleting the element
    ///
    ///  - Parameter result: The result
    private func didDelete(result: Result<Empty, OneDriveError>) {
        self.completion(result.map({ _ in () }))
    }
}
