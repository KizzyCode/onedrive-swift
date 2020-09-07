import Foundation


/// A struct indicating an empty type
internal struct Empty {}

/// A struct indicating an empty JSON dictionary type
internal struct EmptyJSON: Codable, JSONRequestObject, JSONResponseObject {}


/// A REST request object
internal protocol RequestObject {
    /// The request content type (e.g. "application/x-www-form-urlencoded")
    var contentType: String { get }
    /// The request body data
    var data: Data { get }
}
extension Empty: RequestObject {
    var contentType: String { "application/octet-string" }
    var data: Data { Data() }
}
extension Data: RequestObject {
    var contentType: String { "application/octet-string" }
    var data: Data { self }
}
extension Dictionary: RequestObject where Key == String, Value == String {
    var contentType: String { "application/x-www-form-urlencoded" }
    var data: Data {
        var url = URLComponents()
        url.queryItems = self.map({ URLQueryItem(name: $0.key, value: $0.value) })
        return url.query!.data(using: .utf8)!
    }
}


/// A JSON encoded REST body
internal protocol JSONRequestObject: RequestObject {}
extension JSONRequestObject where Self: Encodable {
    var contentType: String { "application/json" }
    var data: Data {
        // swiftlint:disable force_try
        try! JSONEncoder().encode(self)
    }
}


/// A REST response object
internal protocol ResponseObject {
    /// Loads the response object from the response
    static func load(data: Data, code: Int, response: HTTPURLResponse) -> Result<Self, OneDriveError>
}
extension Empty: ResponseObject {
    static func load(data: Data, code: Int, response: HTTPURLResponse) -> Result<Self, OneDriveError> {
        switch code {
            case 200 ..< 300 where data.isEmpty: return .success(Empty())
            case 200 ..< 300: return .init(request: .unexpectedBody(data, response))
            default: return .init(request: .apiError(.init(json: data)))
        }
    }
}
extension Data: ResponseObject {
    static func load(data: Data, code: Int, response: HTTPURLResponse) -> Result<Self, OneDriveError> {
        switch code {
            case 200 ..< 300: return .success(data)
            default: return .init(request: .apiError(.init(json: data)))
        }
    }
}


/// A JSON REST response object
internal protocol JSONResponseObject: ResponseObject {}
extension JSONResponseObject where Self: Decodable {
    static func load(data: Data, code: Int, response: HTTPURLResponse) -> Result<Self, OneDriveError> {
        switch code {
            case 200 ..< 300:
                return Result(catching: { try JSONDecoder().decode(Self.self, from: data) })
                    .mapError({ .request(.invalidResponse($0, data, response)) })
            default:
                return .init(request: .apiError(.init(json: data)))
        }
    }
}


/// A HTTP request
internal class HTTPRequest {
    /// The request URL
    public let url: String
    /// The request method
    public let method: String
    /// The request timeout in seconds
    public let timeout: TimeInterval
    /// The HTTP header fields
    public var headerFields: [String: String] = [:]
    
    /// Creates a new HTTP request
    ///
    ///  - Parameters:
    ///     - url: The request URL
    ///     - method: The HTTP method
    ///     - headerFields: The header fields to set
    ///     - timeout: The request timeout in seconds
    public init(url: String, method: String, headerFields: [String: String] = [:], timeout: TimeInterval = 10.0) {
        self.url = url
        self.method = method
        self.headerFields = headerFields
        self.timeout = timeout
    }
    
    /// Performs a HTTP request
    ///
    ///  - Parameters:
    ///     - completion: The completion handler
    public func start<T: ResponseObject>(body: RequestObject = Empty(),
                                         completion: @escaping (Result<T, OneDriveError>) -> Void) {
        // Create request
        var request = URLRequest(url: URL(string: self.url)!, cachePolicy: .reloadRevalidatingCacheData,
                                 timeoutInterval: self.timeout)
        request.httpMethod = method
        request.setValue(body.contentType, forHTTPHeaderField: "Content-Type")
        headerFields.forEach({ request.setValue($0.value, forHTTPHeaderField: $0.key) })
        request.httpBody = body.data
        
        // Perform request
        URLSession.shared .dataTask(with: request, completionHandler: { (data, response, error) in
            // Check for error
            if let error = error {
                return completion(.init(network: error))
            }
            
            // Load response object
            let response = response as! HTTPURLResponse
            completion(T.load(data: data ?? Data(), code: response.statusCode, response: response))
        }).resume()
    }
}
