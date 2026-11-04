// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Plinth",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.10.1")
    ],
    targets: [
        // Resources live in App/Resources and are copied into the .app by
        // scripts/build_app.sh, so the code loads them from Bundle.main.
        .executableTarget(
            name: "Plinth",
            dependencies: [.product(name: "Sparkle", package: "Sparkle")],
            path: "Sources/Plinth",
            // Sparkle.framework sits next to the binary after `swift build`,
            // and in Contents/Frameworks in the app.
            linkerSettings: [.unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@loader_path",
                                           "-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"])]),
        // The desktop widget, an app extension that scripts/build_app.sh
        // packs into Contents/PlugIns.
        .executableTarget(
            name: "PlinthWidget",
            path: "Sources/PlinthWidget",
            swiftSettings: [.unsafeFlags(["-application-extension"])],
            linkerSettings: [.unsafeFlags(["-Xlinker", "-application_extension"])]),
    ]
)
