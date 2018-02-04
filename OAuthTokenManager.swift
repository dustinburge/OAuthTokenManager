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
    let expiresAt: Int?

    var canRefresh: Bool {
        guard let expiresAt = expiresAt, refreshToken != nil else { return false }
        return expiresAt > Int(Date().timeIntervalSince1970)
    }

    // MARK: - Initialization

    init(accessToken: String, refreshToken: String?, expiresAt: Int?) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expiresAt = expiresAt
    }

    init(accessToken: String, refreshToken: String?, expiresIn: Int?) {
        var expiresAt: Int?
        if let expiresIn = expiresIn {
            expiresAt = Int(Date().timeIntervalSince1970) + expiresIn
        }
        self.init(accessToken: accessToken, refreshToken: refreshToken, expiresAt: expiresAt)
    }
}

struct KeychainKeys {
    var accessToken: String {
        return "\(keyPrefix)_access_token"
    }
    var refreshToken: String {
        return "\(keyPrefix)_refresh_token"
    }
    var expiresAt: String {
        return "\(keyPrefix)_expires_at"
    }
    let keyPrefix: String
}

enum OAuthError {
    case canceled, expired, network
}

class OAuthTokenManager {

    /// Keys used to store your session in Keychain.
    /// Defaults to "otm_access_token", "otm_refresh_token", and "otm_expires_at"
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
        return OAuthSession(
            accessToken: accessToken,
            refreshToken: KeychainWrapper.standard.string(forKey: keychainKeys.refreshToken),
            expiresAt: KeychainWrapper.standard.integer(forKey: keychainKeys.expiresAt)
        )
    }()

    init(authorizationUrl: URL,
         tokenExchangeUrl: URL,
         redirectUri: String,
         clientId: String,
         clientSecret: String,
         keychainPrefix: String = "otm") {

        self.authorizationUrl = authorizationUrl
        self.tokenExchangeUrl = tokenExchangeUrl
        self.redirectUri = redirectUri
        self.clientId = clientId
        self.clientSecret = clientSecret
        self.keychainKeys = KeychainKeys(keyPrefix: keychainPrefix)
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

    func refresh(callback: @escaping (OAuthSession?, OAuthError?) -> Void) {
        guard let refreshToken = currentSession?.refreshToken,
            let expiresAt = currentSession?.expiresAt, expiresAt > Int(Date().timeIntervalSince1970) else {
            callback(nil, .expired)
            return
        }
        exchange(refreshExchangeBody(with: refreshToken), callback: callback)
    }

    // MARK: - Private Methods

    private func exchangeCode(_ code: String, callback: @escaping (OAuthSession?, OAuthError?) -> Void) {
        exchange(tokenExchangeBody(with: code), callback: callback)
    }

    private func exchange(_ body: [String: String], callback: @escaping (OAuthSession?, OAuthError?) -> Void) {
        let defaultSession = URLSession(configuration: .default)
        var urlRequest = URLRequest(url: tokenExchangeUrl)
        urlRequest.httpMethod = "POST"
        urlRequest.allHTTPHeaderFields = ["Content-type": "application/json"]
        urlRequest.httpBody = try? JSONSerialization.data(withJSONObject: body, options: [])

        let dataTask = defaultSession.dataTask(with: urlRequest) { [weak self] data, response, error in
            guard let strongSelf = self, let data = data,
                let jsonObject = try? JSONSerialization.jsonObject(with: data, options: []),
                let dictionary = jsonObject as? [String: Any],
                let accessToken = dictionary["access_token"] as? String else {
                    // TODO: More detailed error handling here
                    DispatchQueue.main.async { callback(nil, error != nil ? .network : nil) }
                    return
            }

            let newSession = OAuthSession(
                accessToken: accessToken,
                refreshToken: dictionary["refresh_token"] as? String,
                expiresIn: dictionary["expires_in"] as? Int
            )
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

    private func refreshExchangeBody(with refreshToken: String) -> [String: String] {
        var body: [String: String] = [:]
        body["refresh_token"] = refreshToken
        body["client_id"] = clientId
        body["client_secret"] = clientSecret
        body["redirect_uri"] = redirectUri
        body["grant_type"] = "refresh_token"
        return body
    }

    private func saveToKeychain(_ session: OAuthSession) {
        KeychainWrapper.standard.set(session.accessToken, forKey: keychainKeys.accessToken)
        if let refreshToken = session.refreshToken, let expiresAt = session.expiresAt {
            KeychainWrapper.standard.set(refreshToken, forKey: keychainKeys.refreshToken)
            KeychainWrapper.standard.set(expiresAt, forKey: keychainKeys.expiresAt)
        } else {
            KeychainWrapper.standard.removeObject(forKey: keychainKeys.refreshToken)
            KeychainWrapper.standard.removeObject(forKey: keychainKeys.expiresAt)
        }
    }
}
