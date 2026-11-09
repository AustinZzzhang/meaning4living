import Foundation
import CommonCrypto
import Security

public struct PasswordCredential: Codable {
    public let version: Int
    public let salt: Data
    public let digest: Data
    public let rounds: UInt32

    /// Derives a credential from password and random salt; returns a verifier and never stores plaintext.
    public init(password: String) throws {
        guard let error = Self.validationMessage(password) else {
            var bytes = [UInt8](repeating: 0, count: 32)
            guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else {
                throw PasswordError.randomFailure
            }
            version = 1
            rounds = 150_000
            salt = Data(bytes)
            digest = try Self.derive(password, salt: salt, rounds: rounds)
            return
        }
        throw PasswordError.invalid(error)
    }

    /// Checks decoded credential parameters before use; no parameters, returns whether the record is supported.
    public func isValid() -> Bool {
        version == 1 && salt.count == 32 && digest.count == 32 && (100_000...1_000_000).contains(rounds)
    }

    /// Verifies candidate against this salted PBKDF2 verifier; returns a constant-time digest comparison.
    public func matches(_ candidate: String) throws -> Bool {
        guard isValid() else { throw PasswordError.invalid("密码记录无法读取，请使用原版本恢复。") }
        guard candidate.utf8.count <= 1024 else { return false }
        let other = try Self.derive(candidate, salt: salt, rounds: rounds)
        var difference: UInt8 = 0
        for (left, right) in zip(digest, other) { difference |= left ^ right }
        return difference == 0
    }

    /// Checks password length without trimming meaningful whitespace; returns a validation error or nil.
    public static func validationMessage(_ password: String) -> String? {
        guard password.count >= 6, password.utf8.count <= 1024 else { return "密码至少 6 位，最长 1024 字节。" }
        guard !password.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return "密码不能全部为空白。" }
        return nil
    }

    /// Derives a 32-byte digest from password, salt and rounds using PBKDF2-SHA256; returns data or throws.
    private static func derive(_ password: String, salt: Data, rounds: UInt32) throws -> Data {
        let passwordBytes = Array(password.utf8)
        var result = [UInt8](repeating: 0, count: 32)
        let status = passwordBytes.withUnsafeBytes { passwordBuffer in
            salt.withUnsafeBytes { saltBuffer in
                CCKeyDerivationPBKDF(
                    CCPBKDFAlgorithm(kCCPBKDF2),
                    passwordBuffer.baseAddress?.assumingMemoryBound(to: Int8.self),
                    passwordBytes.count,
                    saltBuffer.baseAddress?.assumingMemoryBound(to: UInt8.self),
                    salt.count,
                    CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                    rounds,
                    &result,
                    result.count
                )
            }
        }
        guard status == kCCSuccess else { throw PasswordError.randomFailure }
        return Data(result)
    }
}

public enum PasswordError: LocalizedError {
    case invalid(String)
    case randomFailure
    case keychain(Int32)

    public var errorDescription: String? {
        switch self {
        case .invalid(let message): return message
        case .randomFailure: return "无法安全处理密码，请稍后重试。"
        case .keychain(let status):
            return "钥匙串暂不可用（\(status)），设置已保持锁定。请解锁登录钥匙串后重试。"
        }
    }
}
