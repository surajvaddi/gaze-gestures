import Darwin
import Foundation

final class SingleInstanceLock {
    private let lockPath: String
    private var fileDescriptor: Int32 = -1

    init(identifier: String) {
        let safeIdentifier = identifier
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_")

        lockPath = (NSTemporaryDirectory() as NSString)
            .appendingPathComponent("\(safeIdentifier).lock")
    }

    deinit {
        release()
    }

    func acquire() -> Bool {
        guard fileDescriptor == -1 else { return true }

        let descriptor = Darwin.open(lockPath, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
        guard descriptor >= 0 else { return false }

        guard flock(descriptor, LOCK_EX | LOCK_NB) == 0 else {
            Darwin.close(descriptor)
            return false
        }

        fileDescriptor = descriptor
        return true
    }

    func release() {
        guard fileDescriptor >= 0 else { return }

        flock(fileDescriptor, LOCK_UN)
        Darwin.close(fileDescriptor)
        fileDescriptor = -1
    }
}
