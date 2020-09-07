import XCTest
@testable import OneDrive

extension String: Error {}

final class OneDriveTests: XCTestCase {
    #if os(macOS)
    	/// The test data
    	private static let testData = "Testolope".data(using: .utf8)!
    
    	/// A mutex to synchronize the access to `getToken`
    	private static var getTokenMutex: pthread_mutex_t = {
            var mutex = pthread_mutex_t()
            pthread_mutex_init(&mutex, nil)
            return mutex
    	}()
    
    	/// Prints some text prominently to the consolse
    	///
    	///  - Parameter text: The text to print
    	private func display(text: String) {
            print(" > ")
            print(" > \(text)")
            print(" > ")
    	}
    	
    	/// Gets the cached token or fetches a new one (expects a file `.de.KizzyCode.OneDrive.Credentials` with the
    	/// JSON-encoded `AuthConfig` in the current user's home directory
    	///
    	///  - Returns: The token
        private func getToken() throws -> Token {
            // Synchronize access to `getToken`
            pthread_mutex_lock(&Self.getTokenMutex)
            defer { pthread_mutex_unlock(&Self.getTokenMutex) }
            
            /// Fetches a token
            ///
            ///  - Returns: The token
            func fetchToken() throws -> Token {
                /// Opens a tab in the default browser
                ///
                ///  - Parameter url: The URL to open
                func webview(url: String, code: String) {
                    // Print the user code
                    self.display(text: "Login code: \(code)")
                    
                    // Open the URL
                    let process = Process()
                    process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
                    process.arguments = [url]
                    
                    // swiftlint:disable force_try
                    try! process.run()
                }
                
                // Perform a login
                let tokenResult = AsyncResult<Token, OneDriveError>()
                _ = try Login(webview: webview(url:code:), completion: tokenResult.set)
                return try tokenResult.get()
            }
            
            // Load testing credentials
            let credentialsPath = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent(".de.KizzyCode.OneDrive.Credentials")
            let credentialsData = try Data(contentsOf: credentialsPath)
            AuthConfig.global = try JSONDecoder().decode(AuthConfig.self, from: credentialsData)
            
            // Load cached token if any or fetch a new token
            let tokenPath = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent(".de.KizzyCode.OneDrive.Token")
            let token: Token
            switch try? Data(contentsOf: tokenPath) {
                case .some(let tokenData): token = try JSONDecoder().decode(Token.self, from: tokenData)
                case .none: token = try fetchToken()
            }
            
            // Refresh the token if appropriate
            let accessResult = AsyncResult<String, OneDriveError>()
            token.accessToken(completion: accessResult.set)
            _ = try accessResult.get()
            
            // Store the new token
            try JSONEncoder().encode(token).write(to: tokenPath)
            return token
        }
    
    	/// PRAGMA MARK: - Test section
    
    	/// Gets the cached token or fetches a new one
        func testGetToken() throws {
            _ = try self.getToken()
        }
    	
    	/// Tests folder operations (operates on `/de.KizzyCode.OneDrive.TestDir`)
    	func testFolder() throws {
            // Get the token and create a OneDrive instance
            let oneDrive = OneDrive(token: try self.getToken())
            
            // Create the entry
            let createResult = AsyncResult<Void, OneDriveError>()
            oneDrive.create(folder: "/de.KizzyCode.OneDrive.TestDir", completion: createResult.set)
            try createResult.get()
            
            // Move folder
            let moveResult = AsyncResult<Void, OneDriveError>()
            oneDrive.move(path: "/de.KizzyCode.OneDrive.TestDir", newPath: "/de.KizzyCode.OneDrive.TestDir.moved",
                          completion: moveResult.set)
            try moveResult.get()
            
            // Validate the entry
            let readResult = AsyncResult<[DirectoryEntry], OneDriveError>()
            oneDrive.read(folder: "/", completion: readResult.set)
            XCTAssert(try readResult.get().contains(where: { $0.name == "de.KizzyCode.OneDrive.TestDir.moved" }))
            
            // Delete folder
            let deleteResult = AsyncResult<Void, OneDriveError>()
            oneDrive.delete(path: "/de.KizzyCode.OneDrive.TestDir.moved", completion: deleteResult.set)
            try deleteResult.get()
            
            // Validate that the entry has been deleted
            let isDeletedResult = AsyncResult<[DirectoryEntry], OneDriveError>()
            oneDrive.read(folder: "/", completion: isDeletedResult.set)
            XCTAssertFalse(
                try isDeletedResult.get().contains(where: { $0.name == "de.KizzyCode.OneDrive.TestDir.moved" }))
    	}
        
    	/// Tests file operations (operates on `/de.KizzyCode.OneDrive.Testfile.txt`)
    	func testFile() throws {
            // Get the token and create a OneDrive instance
            let oneDrive = OneDrive(token: try self.getToken())
            
            // Create the entry
            let createResult = AsyncResult<Void, OneDriveError>()
            oneDrive.create(file: "/de.KizzyCode.OneDrive.Testfile.txt", data: Self.testData,
                            completion: createResult.set)
            try createResult.get()
            
            // Move file
            let moveResult = AsyncResult<Void, OneDriveError>()
            oneDrive.move(path: "/de.KizzyCode.OneDrive.Testfile.txt",
                          newPath: "/de.KizzyCode.OneDrive.Testfile.moved.txt", completion: moveResult.set)
            try moveResult.get()
            
            // Validate the entry
            let readResult = AsyncResult<Data, OneDriveError>()
            oneDrive.read(file: "/de.KizzyCode.OneDrive.Testfile.moved.txt", completion: readResult.set)
            XCTAssertEqual(try readResult.get(), Self.testData)
            
            // Delete file
            let deleteResult = AsyncResult<Void, OneDriveError>()
            oneDrive.delete(path: "/de.KizzyCode.OneDrive.Testfile.moved.txt", completion: deleteResult.set)
            try deleteResult.get()
            
            // Validate that the entry has been deleted
            let isDeletedResult = AsyncResult<[DirectoryEntry], OneDriveError>()
            oneDrive.read(folder: "/", completion: isDeletedResult.set)
            XCTAssertFalse(
                try isDeletedResult.get().contains(where: { $0.name == "de.KizzyCode.OneDrive.Testfile.moved.txt" }))
        }
    	
    	/// Ensures that the example code compiles
    	func example() throws {
            // A callback to open a webview
            let webview = { (url: String, code: String) in
                // Open a browser window at `url` and display the code so that the user can enter it
            }
            
            // Perform a login to get a token and create the OneDrive instance
            let token = AsyncResult<Token, OneDriveError>()
            _ = try Login(webview: webview, completion: token.set)
            let oneDrive = OneDrive(token: try token.get())
            
            // Create a file "/TestFile" with the contents "Testolope"
            let data = "Testolope".data(using: .utf8)!, result = AsyncResult<Void, OneDriveError>()
            oneDrive.create(file: "/TestFile", data: data, completion: result.set)
            try result.get()
    	}
    
        static var allTests = [
            ("testGetToken", testGetToken),
            ("testFolder", testFolder),
            ("testFile", testFile)
        ]
    #else
    	func testSentry() throws {
        	throw "Tests for other platforms than macOS are currently unsupported" as Error
    	}
    	
    	static var allTests = [
        	("testSentry", testSentry)
    	]
    #endif
}
