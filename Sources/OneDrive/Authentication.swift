import Foundation


/// The global auth config
///
///  - Warning: All fields must be set before performing a login or refreshing a token
public struct AuthConfig: Codable {
    /// The global auth config
    public static var global: AuthConfig?
    /// Gets the client ID or raises a fatal error
    internal static var clientID: String {
        Self.global?.clientID ?? { fatalError("Missing global OAuth client ID @\(#file):\(#line)") }()
    }
    
    /// The client ID registered with Microsoft
    public let clientID: String?
}


/// An authentication token
public class Token: Codable {
    /// The long term refresh token
    private var refreshToken: String
    /// A short term access token
    private var accessToken: String?
    /// The date when the access token will expire
    private var expirationDate: Double
    
    /// The cached access token or `nil` if it must be refreshed
    public var cachedAccessToken: String? {
        guard Date().timeIntervalSince1970 < self.expirationDate else {
            return nil
        }
        return self.accessToken
    }
    
    /// Initializes the authentication token
    ///
    ///  - Parameters:
    ///     - refreshToken: The refresh token
    ///     - accessToken: The access token
    ///     - expiresIn: The amount of seconds the access token is valid for
    internal init(refreshToken: String, accessToken: String, expiresIn: Int) {
        self.refreshToken = refreshToken
        self.accessToken = accessToken
        self.expirationDate = Date().timeIntervalSince1970 + Double(expiresIn - 300)
    }
    
    /// Gets the cached access token or refreshes it if necessary
    ///
    ///  - Parameter completion: The completion handler
    public func accessToken(completion: @escaping (Result<String, OneDriveError>) -> Void) {
        switch self.cachedAccessToken {
            case .some(let accessToken): completion(.success(accessToken))
            case .none: self.refresh(completion: completion)
        }
    }
    
    /// Refreshes the token
    ///
    ///  - Parameter completion: The completion handler that gets called with the new access token
    public func refresh(completion: @escaping (Result<String, OneDriveError>) -> Void) {
        /// The query response
        struct RefreshTokenResponse: Codable, JSONResponseObject {
            /// The refresh token
            let refresh_token: String
            /// The access token
            let access_token: String
            /// The expiration date
            let expires_in: Int
        }
        
        // Create the query
        let query = [
            "client_id": AuthConfig.clientID,
            "grant_type": "refresh_token",
            "refresh_token": self.refreshToken
        ]
        
        // Create the request
        let request = HTTPRequest(url: "https://login.microsoftonline.com/common/oauth2/v2.0/token", method: "POST")
        request.start(body: query, completion: { (result: Result<RefreshTokenResponse, OneDriveError>) in
            // Process result
            switch result {
                case .success(let response):
                    self.refreshToken = response.refresh_token
                    self.accessToken = response.access_token
                    self.expirationDate = Date().timeIntervalSince1970 + Double(response.expires_in - 300)
                    completion(.success(self.accessToken!))
                    
                case .failure(.request(.apiError(let error, _, _))):
                    return completion(.init(authentication: .authenticationFailed(error)))
                case .failure(let error):
                    return completion(.failure(error))
            }
        })
    }
}


/// An OAuth login implementation that can be used to acquire authentication tokens
public class Login {
    /// The associated queue
    private static let queue = DispatchQueue(label: "de.KizzyCode.OneDrive.Login")
    
    /// A device code response
    // swiftlint:disable identifier_name
    private struct DeviceCodeResponse: Decodable, JSONResponseObject {
        /// A long string used to verify the session between the client and the authorization server
        let device_code: String
        /// A short string shown to the user that's used to identify the session on a secondary device
        let user_code: String
        /// The URI the user should go to with the user_code in order to sign in
        let verification_uri: String
        /// The number of seconds the client should wait between polling requests
        let interval: Double
    }
    /// The token response
    private struct TokenResponse: Decodable, JSONResponseObject {
        /// The refresh token
        let refresh_token: String
        /// The access token
        let access_token: String
        /// The expiration date
        let expires_in: Int
    }
    
    /// A callback to open a webview that loads the given URL (required for the OAuth flow)
    private let webview: (String, String) -> Void
    /// The completion handler
    private let completion: (Result<Token, OneDriveError>) -> Void
    /// The device code response for the pending request
    private var deviceCodeResponse: DeviceCodeResponse?
    
    /// Starts an OAuth login flow
    ///
    ///  - Parameters:
    ///     - webview: A callback to open a webview that loads the given URL and displays/copies the auth code the user
    ///       has to enter (required for the OAuth flow)
    ///     - completion: The callback that gets called when the login flow is completed or has failed
    ///  - Throws: An error if the login fails
    public init(webview: @escaping (String, String) -> Void,
                completion: @escaping (Result<Token, OneDriveError>) -> Void) throws {
        // Store callbacks
        self.webview = webview
        self.completion = completion
        
        // Start flow
        let query = [
            "client_id": AuthConfig.clientID,
            "scope": "Files.ReadWrite.All%20offline_access"
        ]
        HTTPRequest(url: "https://login.microsoftonline.com/common/oauth2/v2.0/devicecode", method: "POST")
            .start(body: query, completion: self.deviceCodeResponse(result:))
    }
    
    /// The callback for a device code response
    ///
    ///  - Parameter result: The token response result
    private func deviceCodeResponse(result: Result<DeviceCodeResponse, OneDriveError>) {
        switch result {
            case .success(let response):
                // Open webview and poll tokens
                self.webview(response.verification_uri, response.user_code)
                self.deviceCodeResponse = response
                self.requestToken()
                
            case .failure(.request(.apiError(let error, _, _))):
                return completion(.init(authentication: .authenticationFailed(error)))
            case .failure(let error):
                self.completion(.failure(error))
        }
    }
    
    /// Requests a token
    private func requestToken() {
        // Build and start the request
        let query = [
            "grant_type": "urn:ietf:params:oauth:grant-type:device_code",
            "client_id": AuthConfig.clientID,
            "device_code": self.deviceCodeResponse!.device_code
        ]
        HTTPRequest(url: "https://login.microsoftonline.com/common/oauth2/v2.0/token", method: "POST")
        	.start(body: query, completion: self.tokenResponse(result:))
    }
    /// The callback for token responses
    ///
    ///  - Parameter result: The token response result
    private func tokenResponse(result: Result<TokenResponse, OneDriveError>) {
        switch result {
            case .success(let response):
                // Create the token
                let token = Token(refreshToken: response.refresh_token, accessToken: response.access_token,
                                  expiresIn: response.expires_in)
                self.completion(.success(token))
                
            case .failure(.request(.apiError(let error, _, _))) where error.errorString == "authorization_pending":
                // Wait for the requested sleep interval
                let sleep = DispatchTime.now() + self.deviceCodeResponse!.interval
                Self.queue.asyncAfter(deadline: sleep, execute: self.requestToken)
            
            case .failure(.request(.apiError(let error, _, _))):
                return completion(.init(authentication: .authenticationFailed(error)))
            case .failure(let error):
                self.completion(.failure(error))
        }
    }
}
