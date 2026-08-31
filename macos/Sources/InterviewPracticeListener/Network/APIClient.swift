import Foundation

/// Async client for the EXISTING FastAPI backend. Consumes the same SSE stream
/// the browser frontend uses (`data: <json>\n\n`, terminated by `data: [DONE]`),
/// via URLSession's async byte stream — no extra dependencies.
///
/// This client does not alter any backend behavior; it mirrors the requests the
/// React app already makes.
actor APIClient {

    private let session: URLSession

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 300
        config.waitsForConnectivity = false
        self.session = URLSession(configuration: config)
    }

    private func makeRequest(_ url: URL, apiKey: String?) -> URLRequest {
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let key = apiKey, !key.isEmpty {
            req.setValue(key, forHTTPHeaderField: "x-openai-api-key")
        }
        return req
    }

    // MARK: - Streaming (SSE)

    /// Streams an SSE endpoint. `onChunk` receives the accumulated text after
    /// each chunk. Returns the final accumulated text.
    func streamSSE(
        baseURL: String,
        path: String,
        body: Data,
        apiKey: String?,
        onChunk: @escaping @Sendable (String) -> Void
    ) async throws -> String {
        guard let url = URL(string: baseURL + path) else { throw APIError.malformedResponse }
        var req = makeRequest(url, apiKey: apiKey)
        req.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        req.httpBody = body

        let bytes: URLSession.AsyncBytes
        let response: URLResponse
        do {
            (bytes, response) = try await session.bytes(for: req)
        } catch {
            throw APIError.backendOffline
        }
        guard let http = response as? HTTPURLResponse else { throw APIError.malformedResponse }
        guard (200..<300).contains(http.statusCode) else {
            throw APIError.badStatus(http.statusCode, "request failed")
        }

        var full = ""
        for try await line in bytes.lines {
            guard line.hasPrefix("data:") else { continue }
            let payload = String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces)
            if payload == "[DONE]" { break }
            let chunk = decodeJSONString(payload) ?? payload
            full += chunk
            onChunk(full)
        }
        return full
    }

    private func decodeJSONString(_ s: String) -> String? {
        guard let data = s.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(String.self, from: data)
    }

    // MARK: - JSON POST

    func postJSON<T: Decodable, B: Encodable>(
        baseURL: String, path: String, body: B, apiKey: String?, as type: T.Type
    ) async throws -> T {
        guard let url = URL(string: baseURL + path) else { throw APIError.malformedResponse }
        var req = makeRequest(url, apiKey: apiKey)
        req.httpBody = try JSONEncoder().encode(body)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: req)
        } catch {
            throw APIError.backendOffline
        }
        guard let http = response as? HTTPURLResponse else { throw APIError.malformedResponse }
        guard (200..<300).contains(http.statusCode) else {
            let detail = (try? JSONDecoder().decode([String: String].self, from: data))?["detail"]
                ?? String(data: data, encoding: .utf8) ?? "unknown"
            throw APIError.badStatus(http.statusCode, detail)
        }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw APIError.malformedResponse
        }
    }

    // MARK: - Health check

    func healthCheck(baseURL: String) async -> Bool {
        guard let url = URL(string: baseURL + "/") else { return false }
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.timeoutInterval = 5
        do {
            let (_, response) = try await session.data(for: req)
            return (response as? HTTPURLResponse).map { (200..<300).contains($0.statusCode) } ?? false
        } catch {
            return false
        }
    }

    // MARK: - Multipart upload (resume / context)

    func uploadFile(baseURL: String, path: String, fileURL: URL) async throws -> UploadResponse {
        guard let url = URL(string: baseURL + path) else { throw APIError.malformedResponse }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        let boundary = "Boundary-\(UUID().uuidString)"
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        let fileData = try Data(contentsOf: fileURL)
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileURL.lastPathComponent)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: application/octet-stream\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        req.httpBody = body

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: req)
        } catch {
            throw APIError.backendOffline
        }
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let detail = (try? JSONDecoder().decode([String: String].self, from: data))?["detail"] ?? "upload failed"
            throw APIError.badStatus((response as? HTTPURLResponse)?.statusCode ?? -1, detail)
        }
        do {
            return try JSONDecoder().decode(UploadResponse.self, from: data)
        } catch {
            throw APIError.malformedResponse
        }
    }
}
