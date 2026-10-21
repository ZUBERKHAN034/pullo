import Foundation

final class StubURLProtocol: URLProtocol, @unchecked Sendable {
    struct Response {
        var status: Int
        var body: String
        var headers: [String: String] = [:]
        var failure: URLError.Code?

        static func offline() -> Response { Response(status: 0, body: "", failure: .notConnectedToInternet) }
    }

    private static let lock = NSLock()
    private nonisolated(unsafe) static var responses: [String: [Response]] = [:]
    private nonisolated(unsafe) static var requests: [String: [URLRequest]] = [:]
    private nonisolated(unsafe) static var bodies: [String: [String]] = [:]

    static func session(token: String, status: Int, body: String) -> URLSession {
        session(token: token, responses: [Response(status: status, body: body)])
    }

    static func session(token: String, responses: [Response]) -> URLSession {
        lock.withLock { self.responses[token] = responses }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    static func lastRequest(token: String) -> URLRequest? {
        lock.withLock { requests[token]?.last }
    }

    static func requestCount(token: String) -> Int {
        lock.withLock { requests[token]?.count ?? 0 }
    }

    static func bodies(token: String) -> [String] {
        lock.withLock { bodies[token] ?? [] }
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let token = request.value(forHTTPHeaderField: "Authorization")?.replacingOccurrences(of: "bearer ", with: "") ?? ""
        let body = Self.read(request)
        let stub = Self.lock.withLock {
            Self.requests[token, default: []].append(request)
            Self.bodies[token, default: []].append(body)
            guard var queue = Self.responses[token], let next = queue.first else { return Response?.none }
            if queue.count > 1 {
                queue.removeFirst()
                Self.responses[token] = queue
            }
            return next
        }
        if let code = stub?.failure {
            client?.urlProtocol(self, didFailWithError: URLError(code))
            return
        }
        guard let stub, let url = request.url,
              let response = HTTPURLResponse(url: url, statusCode: stub.status, httpVersion: nil, headerFields: stub.headers)
        else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(stub.body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    private static func read(_ request: URLRequest) -> String {
        if let body = request.httpBody { return String(decoding: body, as: UTF8.self) }
        guard let stream = request.httpBodyStream else { return "" }
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while stream.hasBytesAvailable {
            let read = stream.read(&buffer, maxLength: buffer.count)
            guard read > 0 else { break }
            data.append(buffer, count: read)
        }
        return String(decoding: data, as: UTF8.self)
    }
}
