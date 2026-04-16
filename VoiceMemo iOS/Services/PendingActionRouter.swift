import Foundation
import Observation

/// Observable bridge between the App Group pending-action queue (where Live
/// Activity AppIntents drop marker/photo requests) and the SwiftUI view
/// hierarchy that needs to respond to them. When the app becomes active,
/// `drain()` pops everything out of the App Group and publishes the most
/// recent action of each kind as observable state so views can bind to it.
@Observable
@MainActor
final class PendingActionRouter {
    static let shared = PendingActionRouter()

    /// Most recent pending "add marker" request the UI hasn't yet handled.
    /// Views observe this and present `AddMarkerSheet` when it changes.
    var pendingMarker: PendingLiveActivityAction?

    /// Most recent pending "take photo" request the UI hasn't yet handled.
    var pendingPhoto: PendingLiveActivityAction?

    private init() {}

    func drain() {
        let actions = PendingActionStore.drainActions()
        guard !actions.isEmpty else { return }

        // If multiple actions are queued, take the latest of each kind.
        // (User intent is almost always the last button press.)
        if let marker = actions.last(where: { $0.kind == .addMarker }) {
            pendingMarker = marker
        }
        if let photo = actions.last(where: { $0.kind == .takePhoto }) {
            pendingPhoto = photo
        }
    }

    func acknowledgeMarker() {
        pendingMarker = nil
    }

    func acknowledgePhoto() {
        pendingPhoto = nil
    }
}
