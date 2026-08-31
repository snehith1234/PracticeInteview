import Foundation

// MARK: - Request bodies (mirror the EXISTING Pydantic models in coach_routes.py)

/// Matches `QuickAnswerRequest` in coach_routes.py (used by /coach/quick-short
/// and /coach/quick-answer). Field names must match exactly.
struct QuickAnswerRequest: Encodable {
    var role: String
    var job_description: String
    var resume_text: String
    var company_context: String
    var additional_context: String
    var profile: [String: AnyCodable]
    var transcript: String
    var quick_answer: String
    var mode: String
    var model: String?
}

/// Matches `ProfileRequest` in coach_routes.py.
struct ProfileRequest: Encodable {
    var role: String
    var job_description: String
    var resume_text: String
    var company_context: String
    var additional_context: String
    var model: String?
}

/// Matches `TestRequest` in coach_routes.py.
struct TestRequest: Encodable {
    var model: String?
}

/// Matches `DetectRequest` in coach_routes.py (POST /coach/detect-question).
struct DetectRequest: Encodable {
    var transcript: String
    var model: String?
}

/// Matches `EvaluateRequest` in coach_routes.py (POST /coach/evaluate).
struct EvaluateRequest: Encodable {
    var role: String
    var job_description: String
    var profile: [String: AnyCodable]
    var question: String
    var user_answer: String
    var model: String?
}

// MARK: - Response bodies

struct TestLLMResponse: Decodable {
    var ok: Bool
    var model: String?
    var message: String?
    var error: String?
}

/// Matches the dict returned by /upload/resume and /upload/context.
struct UploadResponse: Decodable {
    var filename: String
    var text: String
    var characters: Int
}

/// Matches the JSON from /coach/detect-question (see detect_question prompt).
struct DetectResponse: Decodable {
    var is_interview_question: Bool?
    var clean_question: String?
    var question_type: String?
    var topic: String?
    var difficulty: String?
    var confidence: Double?
}

/// Matches { "feedback": ... } from /coach/evaluate.
struct EvaluateResponse: Decodable {
    var feedback: String
}

// MARK: - AnyCodable

/// Type-erased Codable so the free-form `profile` dict from /coach/profile can
/// be round-tripped back to /coach/quick-answer without modeling every field.
struct AnyCodable: Codable, Equatable {
    let value: Any

    init(_ value: Any) { self.value = value }

    static func == (lhs: AnyCodable, rhs: AnyCodable) -> Bool {
        String(describing: lhs.value) == String(describing: rhs.value)
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { value = NSNull() }
        else if let b = try? c.decode(Bool.self) { value = b }
        else if let i = try? c.decode(Int.self) { value = i }
        else if let d = try? c.decode(Double.self) { value = d }
        else if let s = try? c.decode(String.self) { value = s }
        else if let a = try? c.decode([AnyCodable].self) { value = a.map { $0.value } }
        else if let o = try? c.decode([String: AnyCodable].self) { value = o.mapValues { $0.value } }
        else { value = NSNull() }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch value {
        case is NSNull: try c.encodeNil()
        case let b as Bool: try c.encode(b)
        case let i as Int: try c.encode(i)
        case let d as Double: try c.encode(d)
        case let s as String: try c.encode(s)
        case let a as [Any]: try c.encode(a.map { AnyCodable($0) })
        case let o as [String: Any]: try c.encode(o.mapValues { AnyCodable($0) })
        default: try c.encodeNil()
        }
    }
}

enum APIError: LocalizedError {
    case backendOffline
    case badStatus(Int, String)
    case malformedResponse
    case emptyTranscript

    var errorDescription: String? {
        switch self {
        case .backendOffline:
            return "Backend offline. Start the FastAPI server, then retry."
        case .badStatus(let code, let detail):
            return "Server error (\(code)): \(detail)"
        case .malformedResponse:
            return "Could not read the server response."
        case .emptyTranscript:
            return "Nothing was transcribed yet."
        }
    }
}
