import Foundation


/// A directory entry
public struct DirectoryEntry: Decodable {
    /// A file info object
    public struct FileInfo: Decodable {
        /// The MIME type of a file
        public let mimeType: String
    }
    
    /// A folder info object
    public struct FolderInfo: Decodable {
        /// The amount of childs in the folder
        public let childCount: Int
    }
    
    /// The entry name
    public let name: String
    /// An attribute indicating that the entry is a file
    public let file: FileInfo?
    /// An attribute indicating that the entry is a folder
    public let folder: FolderInfo?
    /// The size of the entry
    public let size: Int
}


/// A directory reader
internal class DirectoryReader: OneDriveOperation<[DirectoryEntry]> {
    /// A children response
    private struct ChildrenResponse: Decodable, JSONResponseObject {
        // Set coding keys
        enum CodingKeys: String, CodingKey {
            case value = "value"
            case next_link = "@odata.nextLink"
        }
        
        /// The entries
        let value: [DirectoryEntry]
        /// A link to fetch the next entries if the amount of entries exceeds 200
        let next_link: String?
    }
    
    /// The access token
    private var accessToken: String!
    /// The entries
    private var entries: [DirectoryEntry] = []
    
    /// Creates a new directory reader
    ///
    ///  - Parameters:
    ///     - token: The access token
    ///     - path: The path of the directory to read
    ///     - timeout: The timeout for the request
    ///     - completion: The completion handler
    public override init(token: Token, path: String, timeout: TimeInterval,
                         completion: @escaping (Result<[DirectoryEntry], OneDriveError>) -> Void) {
        super.init(token: token, path: path, timeout: timeout, completion: completion)
        self.getAccessToken(completion: self.gotAccessToken(accessToken:))
    }
    
    /// The next step after obtaining an access token
    ///
    ///  - Parameter accessToken: The access token
    private func gotAccessToken(accessToken: String) {
        // Cache the access token
        self.accessToken = accessToken
        
        // Build the path
        let url: String
        switch self.path {
            case "/": url = "https://graph.microsoft.com/v1.0/me/drive/root/children"
            default: url = "https://graph.microsoft.com/v1.0/me/drive/root:\(self.path):/children"
        }
        
        // List the path
        let request = HTTPRequest(url: url, method: "GET", headerFields: ["Authorization": "Bearer \(accessToken)"],
                                  timeout: self.timeout)
        request.start(completion: self.gotEntries(result:))
    }
    
    /// The completion handler for the children request
    ///
    ///  - Parameter result: The result
    private func gotEntries(result: Result<ChildrenResponse, OneDriveError>) {
        switch result {
            case .success(let response) where response.next_link == nil:
                // We have all entries, call the completion handler
                self.entries += response.value
                self.completion(.success(self.entries))
            
            case .success(let response):
                // There are pending entries; fetch the next ones
                self.entries += response.value
                let request = HTTPRequest(url: response.next_link!, method: "GET",
                                          headerFields: ["Authorization": "Bearer \(self.accessToken!)"],
                                          timeout: self.timeout)
                request.start(completion: self.gotEntries)
            
            case .failure(.request(.apiError(let error, _, _))):
                return completion(.init(filesystem: .cannotAccessEntry(error)))
            case .failure(let error):
                self.completion(.failure(error))
        }
    }
}


/// A directory reader
internal class DirectoryWriter: OneDriveOperation<Void> {
    /// A request
    private struct CreateRequest: Encodable, JSONRequestObject {
        // Set coding keys
        enum CodingKeys: String, CodingKey {
            case name = "name"
            case folder = "folder"
            case conflictBehavior = "@microsoft.graph.conflictBehavior"
        }
        
        /// The entry name
        let name: String
        /// A folder object to indicate that the new entry should be a folder
        let folder = EmptyJSON()
        /// A link to fetch the next entries if the amount of entries exceeds 200
        let conflictBehavior = "replace"
    }
    
    /// Creates a new directory reader
    ///
    ///  - Parameters:
    ///     - token: The access token
    ///     - path: The path of the directory to read
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
        // Build the path
        let url: String, pathComponents = URL(fileURLWithPath: self.path)
        switch pathComponents.deletingLastPathComponent().path {
            case "/": url = "https://graph.microsoft.com/v1.0/me/drive/root/children"
            case let parent: url = "https://graph.microsoft.com/v1.0/me/drive/root:\(parent):/children"
        }
        
        // Build the request and create a new folder
        let body = CreateRequest(name: pathComponents.lastPathComponent)
        let request = HTTPRequest(url: url, method: "POST", headerFields: ["Authorization": "Bearer \(accessToken)"],
                                  timeout: self.timeout)
        request.start(body: body, completion: self.didCreate(result:))
    }
    
    /// The completion handler after creating the element
    ///
    ///  - Parameter result: The result
    private func didCreate(result: Result<EmptyJSON, OneDriveError>) {
        self.completion(result.map({ _ in () }))
    }
}
