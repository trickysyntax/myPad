import Foundation
import SwiftData
import Observation
import OSLog

/// Lightweight MainActor facade for deciding when sync should start.
/// Bulk import work stays inside SyncEngine's background ModelContext path.
@MainActor
@Observable
public final class SyncCoordinator {
    public static let shared = SyncCoordinator()

    private static let logger = Logger(subsystem: "org.ciderhouse.myPad", category: "sync")

    /// Default freshness gate retained for future explicit background refresh affordances.
    /// Launch must not call `startIfNeeded`; recursive full sync is manual-only until S2
    /// replaces this with server-assisted incremental sync.
    public var freshnessInterval: TimeInterval = 6 * 60 * 60

    private let syncEngine = SyncEngine.shared

    private init() {}

    public func configure(modelContainer: ModelContainer) {
        syncEngine.configure(modelContainer: modelContainer)
    }

    public func startIfNeeded(isAuthenticated: Bool) {
        guard isAuthenticated else { return }

        // S1 intentionally does NOT start a recursive full sync from ordinary app launch.
        // Local SwiftData should render immediately; users can still run the expensive
        // recursive pull via Settings → Sync Now until S2 replaces it with an incremental
        // bootstrap/changes API.
        Self.logger.debug("launch-time automatic fullSync suppressed; use manual Sync Now")
    }

    public func syncNow() async {
        guard syncEngine.isOnline else { return }
        await syncEngine.fullSync()
    }
}
