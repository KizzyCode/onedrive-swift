# OneDrive

A package that implements basic OneDrive file operations.


## Example: Creating a file
```swift
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
```

Tip: See `Tests/OneDriveTests/OneDriveTests.swift` for more inspiration.
