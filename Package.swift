// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "TalkingAlarm", platforms: [.macOS(.v13)], products: [.executable(name: "TalkingAlarm", targets: ["TalkingAlarm"])], targets: [.executableTarget(name: "TalkingAlarm", swiftSettings: [.swiftLanguageMode(.v5)]), .testTarget(name: "TalkingAlarmTests", dependencies: ["TalkingAlarm"])])
