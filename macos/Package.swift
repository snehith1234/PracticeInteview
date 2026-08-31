// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "InterviewPracticeListener",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "InterviewPracticeListener",
            targets: ["InterviewPracticeListener"]
        )
    ],
    targets: [
        .executableTarget(
            name: "InterviewPracticeListener",
            path: "Sources/InterviewPracticeListener"
        )
    ]
)
