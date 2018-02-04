# OAuthTokenManager

`OAuthTokenManager` is a simple, opinionated way to handle authentication and token management with Swift and Apple's Keychain. It uses a bit of [SwiftKeychainWrapper](https://github.com/jrendel/SwiftKeychainWrapper) to handle communicating with the Keychain and begins the authentication flow with [SFAuthenticationSession](https://developer.apple.com/documentation/safariservices/sfauthenticationsession).

This manager works only with the OAuth [Code Grant Flow](https://tools.ietf.org/html/rfc6749#section-4.1).

## Installation

Just add `OAuthTokenManager.swift`, `KeychainWrapper.swift`, and  `KeychainItemAccessibility.swift` to your Xcode project.

## How To Use

### Initialization

You'll need to initialize a manager for any OAuth Service you use.

```swift
let tokenManager = OAuthTokenManager(
    authorizationUrl: exampleAuthUrl,
    tokenExchangeUrl: exampleExchangeUrl,
    redirectUri: "exampleapp://auth",
    clientId: "your_client_id",
    clientSecret: "super_secret_string",
    keychainPrefix: "example"
)
```
To be notified of a successful login, you will need to register your redirect URI scheme ("exampleapp://" in the example above) in your app's Info.plist.

The `keychainPrefix` is used when storing your session in Keychain. If no value is provided, `OAuthTokenManager` uses a default prefix. You should override this if you are using more than one OAuth service in your app (or if you  might). You can access the complete key string through the managers `keychainKeys` param.

_Note: Be sure to maintain a reference to this manager at least throughout the complete authentication process. If you see a `"Your App" Wants to Use "X Service" to Sign In` alert that immediately disappears, not maintaining this reference is probably your issue._

### Authentication

To authenticate, simply call `authenticate(callback:)` with your manager. You'll receive the session after successful authentication. This same method handles storing the current auth session securely in Keychain.

```swift
tokenManager.authenticate { session, error in
    let authToken = session.authToken
    // Do something with your session
}
```

### Current Session

You can access the current session at any time with your manager.

```swift
let session = tokenManager.currentSession
```

The first time you access this after initializing your manager (before calling `authenticate(callback:)`), the manager will check for an existing session in Keychain. This should be checked _prior_ to authenticating to prevent unnecessary re-authentication. If a previous session has expired, `currentSession` will retrun nil and be removed from Keychain upon first access.

### Refreshing Your Token

You can refresh an auth token at any time by simply calling `refresh(callback:)` with your manager.

```swift
tokenManager.refresh { session, error in
    let authToken = session.authToken
    // Do something with your session
}
```

You can check `expiresAt` on your session if you'd like to manage how often you refresh more carefully.
