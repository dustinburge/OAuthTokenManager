//
//  OAuthTokenManager.swift
//  OAuthTokenManager
//
//  Created by Dustin Burge on 2/3/18.
//  Copyright © 2018 Dustin Burge. All rights reserved.
//

import SafariServices

struct OAuthSession {
    let accessToken: String
    let refreshToken: String?
}

struct KeychainKeys {
    let accessToken: String
    let refreshToken: String
}

enum OAuthError {
    case canceled, network
}

class OAuthTokenManager {

    /// Keys used to store your session in Keychain.
    /// Defaults to "otm_access_token" and "otm_refresh_token"
    /// You should override this if you are using more than one OAuth service in your app (or if you  might)
    private let keychainKeys: KeychainKeys

    private let authorizationUrl: URL
    private let tokenExchangeUrl: URL
    private let redirectUri: String
    private let clientId: String
    private let clientSecret: String

    private var authenticationSession: SFAuthenticationSession?

    /// Current OAuthSession
    /// Accessing this after starting up the app checks for an existing session in Keychain
    /// This should be checked _prior_ to reauthenticating to prevent unnecessary reauthentication
    lazy var currentSession: OAuthSession? = {
        guard let accessToken = KeychainWrapper.standard.string(forKey: keychainKeys.accessToken) else { return nil }
        return OAuthSession(accessToken: accessToken, refreshToken: KeychainWrapper.standard.string(forKey: keychainKeys.refreshToken))
    }()

    init(authorizationUrl: URL,
         tokenExchangeUrl: URL,
         redirectUri: String,
         clientId: String,
         clientSecret: String,
         keychainKeys: KeychainKeys = KeychainKeys(accessToken: "otm_access_token", refreshToken: "otm_refresh_token")) {

        self.authorizationUrl = authorizationUrl
        self.tokenExchangeUrl = tokenExchangeUrl
        self.redirectUri = redirectUri
        self.clientId = clientId
        self.clientSecret = clientSecret
        self.keychainKeys = keychainKeys
    }

    // MARK: - Public Methods

    func authenticate(callback: @escaping (OAuthSession?, OAuthError?) -> Void) {
        authenticationSession = SFAuthenticationSession(url: authorizationUrl, callbackURLScheme: redirectUri) { [weak self] url, error in
            guard let code = url?.queryParameters?["code"], error == nil else {
                DispatchQueue.main.async { callback(nil, .canceled) }
                return
            }
            self?.exchangeCode(code, callback: callback)
        }
        authenticationSession?.start()
    }

    // MARK: - Private Methods

    private func exchangeCode(_ code: String, callback: @escaping (OAuthSession?, OAuthError?) -> Void) {
        let defaultSession = URLSession(configuration: .default)
        var urlRequest = URLRequest(url: tokenExchangeUrl)
        urlRequest.httpMethod = "POST"
        urlRequest.allHTTPHeaderFields = ["Content-type": "application/json"]
        urlRequest.httpBody = try? JSONSerialization.data(withJSONObject: tokenExchangeBody, options: [])

        let dataTask = defaultSession.dataTask(with: urlRequest) { [weak self] data, response, error in
            guard let strongSelf = self, let data = data,
                let jsonObject = try? JSONSerialization.jsonObject(with: data, options: []),
                let dictionary = jsonObject as? [String: Any],
                let accessToken = dictionary["access_token"] as? String else {
                    // TODO: More detailed error handling here
                    DispatchQueue.main.async { callback(nil, error != nil ? .network : nil) }
                    return
            }

            let newSession = OAuthSession(accessToken: accessToken, refreshToken: dictionary["refresh_token"] as? String)
            strongSelf.saveToKeychain(newSession)
            strongSelf.currentSession = newSession
            DispatchQueue.main.async { callback(newSession, nil) }
        }
        dataTask.resume()
    }

    private func tokenExchangeBody(with code: String) -> [String: String] {
        var body: [String: String] = [:]
        body["code"] = code
        body["client_id"] = clientId
        body["client_secret"] = clientSecret
        body["redirect_uri"] = redirectUri
        body["grant_type"] = "authorization_code"
        return body
    }

    private func saveToKeychain(_ session: OAuthSession) {
        KeychainWrapper.standard.set(session.accessToken, forKey: keychainKeys.accessToken)
        if let refreshToken = session.refreshToken {
            KeychainWrapper.standard.set(refreshToken, forKey: keychainKeys.refreshToken)
        } else {
            KeychainWrapper.standard.removeObject(forKey: keychainKeys.refreshToken)
        }
    }
}
