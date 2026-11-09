import Foundation
import Testing
@testable import Cap

// MARK: - Multipart

@Test func multipartBodyIncludesHeadersAndContent() {
    let payload = Data("PNGDATA".utf8)
    let body = MultipartFormData.make(
        boundary: "BOUNDARY",
        fieldName: "file",
        filename: "cap.png",
        mimeType: "image/png",
        data: payload
    )
    let text = String(decoding: body, as: UTF8.self)
    #expect(text.hasPrefix("--BOUNDARY\r\n"))
    #expect(text.contains("Content-Disposition: form-data; name=\"file\"; filename=\"cap.png\""))
    #expect(text.contains("Content-Type: image/png"))
    #expect(text.hasSuffix("\r\n--BOUNDARY--\r\n"))
    #expect(body.range(of: payload) != nil)
}

// MARK: - Response parsing

@Test func parserFindsTopLevelURLField() {
    let data = Data(#"{"url":"https://example.com/a.png"}"#.utf8)
    #expect(UploadResponseParser.url(from: data, contentType: "application/json", preferredKey: "")?.absoluteString == "https://example.com/a.png")
}

@Test func parserFindsNestedDataURL() {
    let data = Data(#"{"data":{"url":"https://example.com/n.png","link":"https://example.com/l.png"}}"#.utf8)
    #expect(UploadResponseParser.url(from: data, contentType: "application/json", preferredKey: "")?.absoluteString == "https://example.com/n.png")
}

@Test func parserHonorsPreferredKeyAndPlainText() {
    let json = Data(#"{"url":"https://example.com/a.png","custom":"https://example.com/c.png"}"#.utf8)
    #expect(UploadResponseParser.url(from: json, contentType: "application/json", preferredKey: "custom")?.absoluteString == "https://example.com/c.png")

    let plain = Data("  https://example.com/plain.png \n".utf8)
    #expect(UploadResponseParser.url(from: plain, contentType: "text/plain", preferredKey: "")?.absoluteString == "https://example.com/plain.png")
}

@Test func parserRejectsInvalidResponses() {
    #expect(UploadResponseParser.url(from: Data("not a url".utf8), contentType: "text/plain", preferredKey: "") == nil)
    #expect(UploadResponseParser.url(from: Data(#"{"status":"ok"}"#.utf8), contentType: "application/json", preferredKey: "") == nil)
    #expect(UploadResponseParser.url(from: Data("<html></html>".utf8), contentType: "text/html", preferredKey: "") == nil)
}

// MARK: - HTTPUploadService

private final class StubURLProtocol: URLProtocol {
    nonisolated(unsafe) static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?
    nonisolated(unsafe) static var requestCount = 0

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.requestCount += 1
        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.unknown))
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

// Swift Testing 默认并行；URLProtocol 用静态 handler/counter，HTTP 用例必须串行。
@Suite(.serialized)
struct HTTPUploadServiceTests {
    private func makeService() -> HTTPUploadService {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        let session = URLSession(configuration: configuration)
        return HTTPUploadService(session: session)
    }

    private func stubResponse(url: String, status: Int) -> (HTTPURLResponse, Data) {
        let response = HTTPURLResponse(
            url: URL(string: url)!,
            statusCode: status,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )!
        return (response, Data(#"{"url":"https://example.com/ok.png"}"#.utf8))
    }

    private let configuration = UploadConfiguration(endpoint: URL(string: "https://example.com/upload")!, fieldName: "file")

    @Test func uploadSucceedsAndReturnsURL() async throws {
        StubURLProtocol.requestCount = 0
        StubURLProtocol.handler = { _ in stubResponse(url: "https://example.com/upload", status: 200) }
        let url = try await makeService().upload(Data("png".utf8), filename: "cap.png", mimeType: "image/png", configuration: configuration)
        #expect(url.absoluteString == "https://example.com/ok.png")
        #expect(StubURLProtocol.requestCount == 1)
    }

    @Test func uploadRetriesOnceOnServerError() async throws {
        StubURLProtocol.requestCount = 0
        StubURLProtocol.handler = { _ in
            StubURLProtocol.requestCount == 1
                ? stubResponse(url: "https://example.com/upload", status: 500)
                : stubResponse(url: "https://example.com/upload", status: 200)
        }
        let url = try await makeService().upload(Data("png".utf8), filename: "cap.png", mimeType: "image/png", configuration: configuration)
        #expect(url.absoluteString == "https://example.com/ok.png")
        #expect(StubURLProtocol.requestCount == 2)
    }

    @Test func uploadDoesNotRetryClientErrors() async {
        StubURLProtocol.requestCount = 0
        StubURLProtocol.handler = { _ in stubResponse(url: "https://example.com/upload", status: 401) }
        await #expect(throws: UploadError.requestFailed(statusCode: 401)) {
            try await makeService().upload(Data("png".utf8), filename: "cap.png", mimeType: "image/png", configuration: configuration)
        }
        #expect(StubURLProtocol.requestCount == 1)
    }

    @Test func uploadClassifiesTimeout() async {
        StubURLProtocol.requestCount = 0
        StubURLProtocol.handler = { _ in throw URLError(.timedOut) }
        await #expect(throws: UploadError.timedOut) {
            try await makeService().upload(Data("png".utf8), filename: "cap.png", mimeType: "image/png", configuration: configuration)
        }
        #expect(StubURLProtocol.requestCount == 2)
    }

    @Test func uploadRejectsInvalidResponseBody() async {
        StubURLProtocol.requestCount = 0
        StubURLProtocol.handler = { _ in
            let response = HTTPURLResponse(url: URL(string: "https://example.com/upload")!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "text/html"])!
            return (response, Data("<html>nope</html>".utf8))
        }
        await #expect(throws: UploadError.invalidResponse) {
            try await makeService().upload(Data("png".utf8), filename: "cap.png", mimeType: "image/png", configuration: configuration)
        }
    }

    @Test func uploadRejectsEmptyData() async {
        await #expect(throws: UploadError.invalidImage) {
            try await makeService().upload(Data(), filename: "cap.png", mimeType: "image/png", configuration: configuration)
        }
    }
}

// MARK: - Settings

@MainActor
private func makeUploadDefaults() -> UserDefaults {
    let suite = "cap.tests.upload.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defaults.removePersistentDomain(forName: suite)
    return defaults
}

@MainActor
@Test func uploadSettingsPersistAndReload() {
    let defaults = makeUploadDefaults()
    let store = UploadSettingsStore(defaults: defaults)
    #expect(!store.isConfigured)

    store.endpoint = "https://example.com/upload"
    store.authorization = "Bearer token"
    store.fieldName = "screenshot"

    let reloaded = UploadSettingsStore(defaults: defaults)
    #expect(reloaded.isConfigured)
    let configuration = reloaded.configuration
    #expect(configuration?.endpoint.absoluteString == "https://example.com/upload")
    #expect(configuration?.authorization == "Bearer token")
    #expect(configuration?.fieldName == "screenshot")
}

@MainActor
@Test func uploadSettingsRejectInvalidEndpoint() {
    let store = UploadSettingsStore(defaults: makeUploadDefaults())
    store.endpoint = "not a url"
    #expect(!store.isConfigured)
    #expect(store.configuration == nil)

    store.endpoint = "ftp://example.com/file"
    #expect(!store.isConfigured)
}

@MainActor
@Test func uploadSettingsDefaultsAndReset() {
    let store = UploadSettingsStore(defaults: makeUploadDefaults())
    #expect(store.fieldName == "file")
    store.endpoint = "https://example.com/upload"
    store.reset()
    #expect(!store.isConfigured)
}
