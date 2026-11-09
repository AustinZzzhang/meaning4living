import Foundation

public enum UpdateSource {
    /// Validates a public HTTPS appcast address; returns a normalized URL or nil, refusing credentials/fragments.
    public static func url(_ input: String) -> URL? {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let components = URLComponents(string: text),
              components.scheme?.lowercased() == "https",
              let host = components.host, !host.isEmpty,
              components.user == nil, components.password == nil, components.fragment == nil,
              let url = components.url, url.pathExtension.lowercased() == "xml" else { return nil }
        return url
    }
}
