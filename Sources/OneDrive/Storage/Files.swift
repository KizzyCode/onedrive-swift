import Foundation


/// A file reader
internal class FileReader: OneDriveOperation<Data> {
    /// Creates a new file reader
    ///
    ///  - Parameters:
    ///     - token: The access token
    ///     - path: The path of the file to read
    ///     - timeout: The timeout for the request
    ///     - completion: The completion handler
    public override init(token: Token, path: String, timeout: TimeInterval,
                         completion: @escaping (Result<Data, OneDriveError>) -> Void) {
        super.init(token: token, path: path, timeout: timeout, completion: completion)
        self.getAccessToken(completion: self.gotAccessToken(accessToken:))
    }
    
    /// The next step after obtaining an access token
    ///
    ///  - Parameter accessToken: The access token
    private func gotAccessToken(accessToken: String) {
        // Get data (this works via a 302 redirect which is automatically resolved by `URLRequest`)
        let url = "https://graph.microsoft.com/v1.0/me/drive/root:\(self.path):/content"
        let request = HTTPRequest(url: url, method: "GET", headerFields: ["Authorization": "Bearer \(accessToken)"],
                                  timeout: self.timeout)
        request.start(completion: self.completion)
    }
}


/// A file writer
internal class FileWriter: OneDriveOperation<Void> {
    /// A request
    private struct CreateRequest: Encodable, JSONRequestObject {
        // Set coding keys
        enum CodingKeys: String, CodingKey {
            case name = "name"
            case file = "file"
            case conflictBehavior = "@microsoft.graph.conflictBehavior"
        }
        
        /// The entry name
        let name: String
        /// A folder object to indicate that the new entry should be a folder
        let file = EmptyJSON()
        /// The conflict behavior policy
        let conflictBehavior = "replace"
    }
    
    /// The file contents
    private let data: Data
    
    /// Creates a new file writer
    ///
    ///  - Parameters:
    ///     - token: The access token
    ///     - path: The path of the file to write
    ///     - timeout: The timeout for the request
    ///     - completion: The completion handler
    public init(token: Token, path: String, data: Data, timeout: TimeInterval,
                completion: @escaping (Result<Void, OneDriveError>) -> Void) {
        self.data = data
        super.init(token: token, path: path, timeout: timeout, completion: completion)
        self.getAccessToken(completion: self.gotAccessToken(accessToken:))
    }
    
    /// The next step after obtaining an access token
    ///
    ///  - Parameter accessToken: The access token
    private func gotAccessToken(accessToken: String) {
        // Build the request and create a new folder
        let url = "https://graph.microsoft.com/v1.0/me/drive/root:\(self.path):/content"
        let request = HTTPRequest(url: url, method: "PUT", headerFields: ["Authorization": "Bearer \(accessToken)"],
                                  timeout: self.timeout)
        request.start(body: self.data, completion: self.didCreate(result:))
    }
    
    /// The completion handler after creating the element
    ///
    ///  - Parameter result: The result
    private func didCreate(result: Result<EmptyJSON, OneDriveError>) {
        self.completion(result.map({ _ in () }))
    }
}
