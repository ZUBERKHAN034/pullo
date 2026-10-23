import Foundation
import Network

protocol NetworkPath: AnyObject {
    func start(_ onChange: @escaping @MainActor (Bool) -> Void)
    func cancel()
}

final class LiveNetworkPath: NetworkPath {
    private let monitor = NWPathMonitor()

    func start(_ onChange: @escaping @MainActor (Bool) -> Void) {
        monitor.pathUpdateHandler = { path in
            let reachable = path.status == .satisfied
            Task { @MainActor in onChange(reachable) }
        }
        monitor.start(queue: DispatchQueue(label: "dev.jrdan.pullo.network"))
    }

    func cancel() {
        monitor.cancel()
    }
}
