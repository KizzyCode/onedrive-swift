import Foundation


/// An API error
public struct APIError: Error {
    /// The raw error
    public let raw: Data
    /// The entire error object
    private(set) public var all: Any?
    /// The dedicated API error field
    private(set) public var error: Any?
    
    /// The `error` field as `String` if possible
    public var errorString: String? { self.error as? String }
    
    /// Initializes the API error from a JSON object
    ///
    ///  - Parameter json: The JSON encoded data
    public init(json data: Data) {
        self.raw = data
        if let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            self.all = dict
            self.error = dict["error"]
        }
	}
}


/// A OneDrive related error
public enum OneDriveError: Error {
    /// A network error
    public enum Network: Error {
        /// Some network error occurred
        case other(Error, file: String = #file, line: Int = #line)
    }
    
    /// An authentication error
    public enum Authentication: Error {
        /// There was an invalid OAuth response
        case authenticationFailed(APIError, String = #file, Int = #line)
    }
    
    /// A HTTP request error
    public enum Request: Error {
        /// An API error occurred
        case apiError(APIError, String = #file, Int = #line)
        /// The request response is not empty
        case unexpectedBody(Data, URLResponse, String = #file, Int = #line)
        /// The response is invalid (i.e. cannot be parsed)
        case invalidResponse(Error, Data, URLResponse, String = #file, Int = #line)
    }
    
    /// A filesystem error
    public enum Filesystem: Error {
        /// Failed to access an entry
        case cannotAccessEntry(APIError, String = #file, Int = #line)
        /// The requested entry in not a file
        case notAFile(String, String = #file, Int = #line)
        /// The requested entry in not a folder
        case notAFolder(String, String = #file, Int = #line)
    }
    
    /// A network error
    case network(Network)
    /// An authentication error
    case authentication(Authentication)
    /// A HTTP request error
    case request(Request)
    /// A filesystem error
    case filesystem(Filesystem)
}
extension Result where Failure == OneDriveError {
    /// Wraps any error as network error
    public init(network error: Error) {
        self = .failure(.network(.other(error)))
    }
    /// Wraps an authentication error
    public init(authentication error: OneDriveError.Authentication) {
        self = .failure(.authentication(error))
    }
    /// Wraps a HTTP request error
    public init(request error: OneDriveError.Request) {
        self = .failure(.request(error))
    }
    /// Wraps a filesystem error
    public init(filesystem error: OneDriveError.Filesystem) {
        self = .failure(.filesystem(error))
    }
}
