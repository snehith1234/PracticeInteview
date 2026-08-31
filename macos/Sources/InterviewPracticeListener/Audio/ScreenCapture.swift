import Foundation
import AppKit
import Vision

/// Captures the entire screen to a PNG file and runs on-device OCR (Apple
/// Vision) to extract the text. Uses the built-in `screencapture` tool for the
/// image and VNRecognizeTextRequest for text — no network, no dependencies.
///
/// Requires the "Screen Recording" permission (System Settings › Privacy &
/// Security › Screen Recording) to capture other apps' windows.
enum ScreenCapture {

    struct Result {
        let imageURL: URL
        let text: String
    }

    enum CaptureError: LocalizedError {
        case captureFailed
        case ocrFailed(String)

        var errorDescription: String? {
            switch self {
            case .captureFailed:
                return "Screen capture failed. Grant Screen Recording permission in System Settings › Privacy & Security › Screen Recording, then try again."
            case .ocrFailed(let m):
                return "Could not read text from the screenshot: \(m)"
            }
        }
    }

    /// Default save location: ~/Pictures/InterviewPracticeListener.
    static func defaultSaveDirectory() -> URL {
        let base = FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let dir = base.appendingPathComponent("InterviewPracticeListener", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// Captures the full screen, saves a PNG, and returns the file URL + OCR text.
    static func captureFullScreenAndOCR() async throws -> Result {
        let dir = defaultSaveDirectory()
        let stamp = ISO8601DateFormatter().string(from: Date())
            .replacingOccurrences(of: ":", with: "-")
        let imageURL = dir.appendingPathComponent("screenshot-\(stamp).png")

        try await runScreencapture(to: imageURL)

        guard FileManager.default.fileExists(atPath: imageURL.path) else {
            throw CaptureError.captureFailed
        }
        let text = try await ocr(imageURL: imageURL)
        return Result(imageURL: imageURL, text: text)
    }

    // MARK: - screencapture

    /// `screencapture -x <path>`: full screen, no capture sound.
    private static func runScreencapture(to url: URL) async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
            proc.arguments = ["-x", url.path]
            proc.terminationHandler = { p in
                if p.terminationStatus == 0 {
                    cont.resume(returning: ())
                } else {
                    cont.resume(throwing: CaptureError.captureFailed)
                }
            }
            do { try proc.run() }
            catch { cont.resume(throwing: CaptureError.captureFailed) }
        }
    }

    // MARK: - OCR (Vision)

    private static func ocr(imageURL: URL) async throws -> String {
        guard let image = NSImage(contentsOf: imageURL),
              let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil)
        else {
            throw CaptureError.ocrFailed("could not load image")
        }
        return try await withCheckedThrowingContinuation { (cont: CheckedContinuation<String, Error>) in
            let request = VNRecognizeTextRequest { req, err in
                if let err {
                    cont.resume(throwing: CaptureError.ocrFailed(err.localizedDescription))
                    return
                }
                let observations = (req.results as? [VNRecognizedTextObservation]) ?? []
                let lines = observations.compactMap { $0.topCandidates(1).first?.string }
                cont.resume(returning: lines.joined(separator: "\n"))
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            DispatchQueue.global(qos: .userInitiated).async {
                do { try handler.perform([request]) }
                catch { cont.resume(throwing: CaptureError.ocrFailed(error.localizedDescription)) }
            }
        }
    }
}
