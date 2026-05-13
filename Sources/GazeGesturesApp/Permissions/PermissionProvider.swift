import Foundation

protocol PermissionProviding {
    func currentSnapshot() -> PermissionSnapshot
}

final class PlaceholderPermissionProvider: PermissionProviding {
    func currentSnapshot() -> PermissionSnapshot {
        PermissionSnapshot.placeholder
    }
}
