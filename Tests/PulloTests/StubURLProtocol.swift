import Foundation

final class StubURLProtocol: URLProtocol, @unchecked Sendable {
    struct Response {
        var status: Int
        var body: String
    }

    private static let lock = NSLock()
    private nonisolated(unsafe) static var responses: [String: Response] = [:]
    private nonisolated(unsafe) static var requests: [String: URLRequest] = [:]

    static func session(token: String, status: Int, body: String) -> URLSession {
        lock.withLock { responses[token] = Response(status: status, body: body) }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    static func lastRequest(token: String) -> URLRequest? {
        lock.withLock { requests[token] }
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let token = request.value(forHTTPHeaderField: "Authorization")?.replacingOccurrences(of: "bearer ", with: "") ?? ""
        let stub = Self.lock.withLock {
            Self.requests[token] = request
            return Self.responses[token]
        }
        guard let stub, let url = request.url,
              let response = HTTPURLResponse(url: url, statusCode: stub.status, httpVersion: nil, headerFields: nil)
        else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(stub.body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
