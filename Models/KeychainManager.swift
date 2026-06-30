import Foundation
import Security

/// Secure storage for API keys using macOS Keychain.
enum KeychainManager {
    private static let service = "com.trustedinstaller.mathatlas"

    static func saveAPIKey(_ key: String) -> Bool {
        deleteAPIKey() // remove old first
        guard let data = key.data(using: .utf8) else { return false }
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: "deepseek-api-key",
            kSecValueData: data
        ]
        return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
    }

    static func loadAPIKey() -> String? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: "deepseek-api-key",
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func deleteAPIKey() {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: "deepseek-api-key"
        ]
        SecItemDelete(query as CFDictionary)
    }
}
