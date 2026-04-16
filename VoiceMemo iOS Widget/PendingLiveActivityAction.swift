import Foundation

// Shared App Group data exchange between:
//   1. Live Activity AppIntents (fired from the lock screen; run in the
//      widget extension process, not the main app).
//   2. The main iOS app (picks up the pending action on scenePhase /
//      onOpenURL after the user unlocks and is routed in).
//   3. The iPhone side of WatchConnectivity (when a Watch-sourced
//      recording finally arrives as a file, it drains pending markers
//      for that recordingId from the App Group).
//
// All data is stored as JSON under a single UserDefaults key in the shared
// App Group suite, so the widget extension (which has no access to the main
// app's SwiftData container) can queue work for the main app.

enum AppGroup {
    static let suiteName = "group.com.zhangshifeng.VoiceMemo"
    static var defaults: UserDefaults? {
        UserDefaults(suiteName: suiteName)
    }
}

/// What the user tapped on a Live Activity button.
enum PendingLiveActivityActionKind: String, Codable {
    case addMarker
    case takePhoto
}

/// A single action the user initiated from the Live Activity but that needs
/// the main app to open before it can be completed (marker text entry,
/// camera capture, etc.).
struct PendingLiveActivityAction: Codable, Sendable, Equatable {
    let id: UUID
    let kind: PendingLiveActivityActionKind
    let recordingId: String
    let timestamp: TimeInterval
    let createdAt: Date

    nonisolated init(
        id: UUID = UUID(),
        kind: PendingLiveActivityActionKind,
        recordingId: String,
        timestamp: TimeInterval,
        createdAt: Date = .now
    ) {
        self.id = id
        self.kind = kind
        self.recordingId = recordingId
        self.timestamp = timestamp
        self.createdAt = createdAt
    }
}

/// A marker captured during a Watch-sourced recording whose file hasn't yet
/// been transferred to the iPhone. Held in the App Group until the Watch
/// sends the .m4a over, at which point the iPhone materializes a Recording
/// and attaches any matching PendingWatchMarker entries.
struct PendingWatchMarker: Codable, Sendable {
    let id: UUID
    let recordingId: String
    let timestamp: TimeInterval
    let text: String
    let photoFileName: String?
    let createdAt: Date

    nonisolated init(
        id: UUID = UUID(),
        recordingId: String,
        timestamp: TimeInterval,
        text: String,
        photoFileName: String? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.recordingId = recordingId
        self.timestamp = timestamp
        self.text = text
        self.photoFileName = photoFileName
        self.createdAt = createdAt
    }
}

enum PendingActionStore {
    private static let actionsKey = "pendingLiveActivityActions"
    private static let watchMarkersKey = "pendingWatchMarkers"

    // MARK: - Pending actions (entry points from Live Activity → main app)

    nonisolated static func enqueueAction(_ action: PendingLiveActivityAction) {
        var actions = loadActions()
        actions.append(action)
        saveActions(actions)
    }

    nonisolated static func loadActions() -> [PendingLiveActivityAction] {
        guard let data = AppGroup.defaults?.data(forKey: actionsKey) else { return [] }
        return (try? JSONDecoder().decode([PendingLiveActivityAction].self, from: data)) ?? []
    }

    nonisolated static func drainActions() -> [PendingLiveActivityAction] {
        let actions = loadActions()
        AppGroup.defaults?.removeObject(forKey: actionsKey)
        return actions
    }

    nonisolated static func removeAction(id: UUID) {
        let remaining = loadActions().filter { $0.id != id }
        saveActions(remaining)
    }

    nonisolated private static func saveActions(_ actions: [PendingLiveActivityAction]) {
        if actions.isEmpty {
            AppGroup.defaults?.removeObject(forKey: actionsKey)
            return
        }
        if let data = try? JSONEncoder().encode(actions) {
            AppGroup.defaults?.set(data, forKey: actionsKey)
        }
    }

    // MARK: - Pending markers for Watch-sourced recordings

    nonisolated static func enqueueWatchMarker(_ marker: PendingWatchMarker) {
        var markers = loadWatchMarkers()
        markers.append(marker)
        saveWatchMarkers(markers)
    }

    nonisolated static func loadWatchMarkers() -> [PendingWatchMarker] {
        guard let data = AppGroup.defaults?.data(forKey: watchMarkersKey) else { return [] }
        return (try? JSONDecoder().decode([PendingWatchMarker].self, from: data)) ?? []
    }

    nonisolated static func drainWatchMarkers(for recordingId: String) -> [PendingWatchMarker] {
        let all = loadWatchMarkers()
        let matching = all.filter { $0.recordingId == recordingId }
        let remaining = all.filter { $0.recordingId != recordingId }
        saveWatchMarkers(remaining)
        return matching
    }

    nonisolated private static func saveWatchMarkers(_ markers: [PendingWatchMarker]) {
        if markers.isEmpty {
            AppGroup.defaults?.removeObject(forKey: watchMarkersKey)
            return
        }
        if let data = try? JSONEncoder().encode(markers) {
            AppGroup.defaults?.set(data, forKey: watchMarkersKey)
        }
    }
}
