import Foundation
import Combine
import Security
import LivingCore

protocol CredentialVault {
    /// Returns the current verifier data, or nil when protection is disabled; no parameters, may throw.
    func read() throws -> Data?
    /// Replaces the verifier with data, or disables it with nil; returns nothing and throws on failure.
    func write(_ data: Data?) throws
}

struct KeychainCredentialVault: CredentialVault {
    let service: String

    /// Creates a keychain vault for service; returns an accessor without reading secrets.
    init(service: String = "local.livingmeaning.settings-password") {
        self.service = service
    }

    private var query: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "settings-verifier",
            kSecAttrSynchronizable as String: false
        ]
    }

    /// Reads the salted verifier from the local keychain; no parameters, returns nil only if absent.
    func read() throws -> Data? {
        var request = query
        request[kSecReturnData as String] = true
        request[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(request as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else {
            throw PasswordError.keychain(status)
        }
        return data
    }

    /// Atomically replaces verifier data or deletes it for nil; returns nothing, retaining old data on failure.
    func write(_ data: Data?) throws {
        if let data {
            let attributes = [kSecValueData as String: data]
            var status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
            if status == errSecItemNotFound {
                var item = query
                item[kSecValueData as String] = data
                item[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
                item[kSecAttrLabel as String] = "活着的意义 · 设置保护"
                status = SecItemAdd(item as CFDictionary, nil)
            }
            guard status == errSecSuccess else { throw PasswordError.keychain(status) }
        } else {
            let status = SecItemDelete(query as CFDictionary)
            guard status == errSecSuccess || status == errSecItemNotFound else {
                throw PasswordError.keychain(status)
            }
        }
    }
}

final class MemoryCredentialVault: CredentialVault {
    var data: Data?
    var failWrites = false
    var failReads = false

    /// Returns preview/test verifier data; no parameters, throws when failure simulation is enabled.
    func read() throws -> Data? {
        if failReads { throw PasswordError.keychain(errSecInteractionNotAllowed) }
        return data
    }

    /// Stores data in memory for isolated tests/previews; returns nothing, can simulate a failed write.
    func write(_ data: Data?) throws {
        if failWrites { throw PasswordError.keychain(errSecAuthFailed) }
        self.data = data
    }
}

final class SettingsLock: ObservableObject {
    @Published private(set) var isProtected = true
    @Published private(set) var isUnlocked = false
    @Published private(set) var error: String?
    private let vault: CredentialVault
    private var credential: PasswordCredential?
    private var failedAttempts = 0
    private var retryAfter: TimeInterval = 0
    private var loaded = false

    var canView: Bool { loaded && (!isProtected || isUnlocked) }

    /// Creates a fail-closed gate using vault; lazy loading avoids keychain prompts before settings are requested.
    init(vault: CredentialVault = KeychainCredentialVault()) {
        self.vault = vault
    }

    /// Reads keychain protection state and locks settings; no parameters or return value.
    func refresh() {
        isUnlocked = false
        do {
            if let data = try vault.read() {
                let decoded = try JSONDecoder().decode(PasswordCredential.self, from: data)
                guard decoded.isValid() else { throw PasswordError.invalid("密码记录不完整，无法解锁设置。") }
                credential = decoded
                isProtected = true
            } else {
                credential = nil
                isProtected = false
            }
            loaded = true
            error = nil
        } catch {
            loaded = false
            isProtected = true
            self.error = error.localizedDescription
        }
    }

    /// Verifies password subject to a local retry delay; returns true only after successful authentication.
    @discardableResult
    func unlock(_ password: String) -> Bool {
        guard ProcessInfo.processInfo.systemUptime >= retryAfter else {
            error = "尝试次数较多，请稍后再试。"
            return false
        }
        if !loaded { refresh() }
        guard loaded else { return false }
        guard let credential else { return !isProtected }
        do {
            guard try credential.matches(password) else {
                failedAttempts += 1
                if failedAttempts >= 5 {
                    retryAfter = ProcessInfo.processInfo.systemUptime + 30
                    error = "密码错误次数较多，请 30 秒后再试。"
                } else {
                    error = "密码不正确，请重新输入。"
                }
                return false
            }
            isUnlocked = true
            failedAttempts = 0
            retryAfter = 0
            error = nil
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    /// Enables or changes protection using password and confirmation; current authenticates changes, returns error/nil.
    func setPassword(_ password: String, confirmation: String, current: String) -> String? {
        if !loaded { refresh() }
        guard loaded, canView else { return error ?? "请先解锁设置。" }
        if isProtected, !unlock(current) { return error ?? "原密码不正确。" }
        guard password == confirmation else { return "两次输入的新密码不一致。" }
        do {
            let next = try PasswordCredential(password: password)
            try vault.write(JSONEncoder().encode(next))
            credential = next
            isProtected = true
            isUnlocked = true
            error = nil
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    /// Disables protection after checking current password; returns an error or nil after keychain deletion.
    func disable(current password: String) -> String? {
        guard canView, isProtected, unlock(password) else { return error ?? "请先输入正确的原密码。" }
        do {
            try vault.write(nil)
            credential = nil
            isProtected = false
            isUnlocked = false
            error = nil
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    /// Revokes any unlocked session; no parameters or return value.
    func lock() {
        isUnlocked = false
    }
}
