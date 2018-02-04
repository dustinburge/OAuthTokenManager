# OAuthTokenManager

`OAuthTokenManager` is a simple, opinionated way to handle authentication and token management with Swift and Apple's Keychain. It uses a bit of [SwiftKeychainWrapper](https://github.com/jrendel/SwiftKeychainWrapper) to handle communicating with the Keychain and begins the authentication flow with [SFAuthenticationSession](https://developer.apple.com/documentation/safariservices/sfauthenticationsession).

## Installation

Just add `OAuthTokenManager.swift`, `KeychainWrapper.swift`, and  `KeychainItemAccessibility.swift` to your Xcode project.

## How To Use

You'll need to initialize a manager for any OAuth Service you use.

```swift
let tokenManager = OAuthTokenManager(
    authorizationUrl: URL(string: "https://example.com/oauth/authorize?\(params)")!,
    tokenExchangeUrl: URL(string: "https://example.com/oauth/token")!,
    redirectUri: "exampleapp://auth", // you'll need to register your scheme in your app's Info.plist
    clientId: "your_client_id",
    clientSecret: "super_secret_string",
    keychainKeys: KeychainKeys(accessToken: "trakt_access_token", refreshToken: "trakt_refresh_token")
)
```

The `keychainKeys` are used to store your session in Keychain. If no value is provided, `OAuthTokenManager` uses default keys. You should override this if you are using more than one OAuth service in your app (or if you  might).

_Note: Be sure to maintain a reference to this manager at least throughout the complete authentication process. If you see a `"Your App" Wants to Use "X Service" to Sign In` alert that immediately disappears, not maintaining this reference is probably your issue._

To authenticate, simply call `authenticat(callback:)` with your manager. You'll receive the session after successful authentication. This same method handles storing the current auth session securely in Keychain.

```swift
tokenManager.authenticate { [weak self] session, error in
    let authToken = session.authToken
    // Do something with your session
}
```

You can access the current session at any time with your manager.

```swift
let session = tokenManager.currentSession
```

The first time you access this after initializing your manager (before calling `authenticate(callback:)`), the manager will check for an existing session in Keychain. This should be checked _prior_ to authenticating to prevent unnecessary re-authentication.
