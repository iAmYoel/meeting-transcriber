import Foundation

extension AppSettings {
    var vaultRoot: URL? {
        guard let vaultBookmark else { return nil }
        var stale = false
        return try? URL(
            resolvingBookmarkData: vaultBookmark, options: .withSecurityScope,
            relativeTo: nil, bookmarkDataIsStale: &stale,
        )
    }

    func setVaultRoot(_ url: URL) throws {
        vaultBookmark = try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
    }
}
