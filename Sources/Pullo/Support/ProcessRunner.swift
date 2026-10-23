import Foundation
import os

enum ProcessRunner {
    struct Output {
        let status: Int32
        let stdout: Data
    }

    struct TimedOut: Error {}

    static let killGrace: TimeInterval = 2
    static let drainGrace: TimeInterval = 1

    static func run(
        _ executable: String,
        _ arguments: [String],
        environment: [String: String]? = nil,
        timeout: Duration
    ) async throws -> Output {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        if let environment { process.environment = environment }
        process.standardInput = FileHandle.nullDevice
        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        let collected = OSAllocatedUnfairLock(initialState: Data())
        let drained = DispatchGroup()
        drain(stdout, into: collected, group: drained)
        drain(stderr, into: nil, group: drained)

        return try await withCheckedThrowingContinuation { continuation in
            let once = Once(continuation)
            process.terminationHandler = { process in
                let status = process.terminationStatus
                let finish: @Sendable () -> Void = { once.resume(.success(Output(status: status, stdout: collected.withLock { $0 }))) }
                drained.notify(queue: .global(), execute: finish)
                DispatchQueue.global().asyncAfter(deadline: .now() + drainGrace, execute: finish)
            }
            do {
                try process.run()
            } catch {
                once.resume(.failure(error))
                return
            }
            let seconds = Double(timeout.components.seconds) + Double(timeout.components.attoseconds) / 1e18
            DispatchQueue.global().asyncAfter(deadline: .now() + seconds) {
                guard process.isRunning else { return }
                process.terminate()
                once.resume(.failure(TimedOut()))
                DispatchQueue.global().asyncAfter(deadline: .now() + killGrace) {
                    if process.isRunning { kill(process.processIdentifier, SIGKILL) }
                }
            }
        }
    }

    private static func drain(_ pipe: Pipe, into buffer: OSAllocatedUnfairLock<Data>?, group: DispatchGroup) {
        let handle = pipe.fileHandleForReading
        group.enter()
        DispatchQueue.global(qos: .utility).async {
            while true {
                let chunk = handle.availableData
                if chunk.isEmpty { break }
                buffer?.withLock { $0.append(chunk) }
            }
            group.leave()
        }
    }

    private final class Once: Sendable {
        private let continuation: OSAllocatedUnfairLock<CheckedContinuation<Output, Error>?>

        init(_ continuation: CheckedContinuation<Output, Error>) {
            self.continuation = OSAllocatedUnfairLock(initialState: continuation)
        }

        func resume(_ result: Result<Output, Error>) {
            let pending = continuation.withLock { value in
                defer { value = nil }
                return value
            }
            pending?.resume(with: result)
        }
    }
}
