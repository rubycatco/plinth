// swift-tools-version: 5.9
import PackageDescription

// PLINTH_APPSTORE=1 builds for the Mac App Store, which updates the app
// itself: no Sparkle, and the APPSTORE flag for the code.
let appStore = Context.environment["PLINTH_APPSTORE"] == "1"

let package = Package(
    name: "Plinth",
    platforms: [.macOS(.v14)],
    // Declared in every build, though the App Store build doesn't link it,
    // so that build leaves Package.resolved and its Sparkle pin alone.
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.10.1")
    ],
    targets: [
        // Resources live in App/Resources and are copied into the .app by
        // scripts/build_app.sh, so the code loads them from Bundle.main.
        .executableTarget(
            name: "Plinth",
            dependencies: appStore ? [] : [.product(name: "Sparkle", package: "Sparkle")],
            path: "Sources/Plinth",
            swiftSettings: appStore ? [.define("APPSTORE")] : [],
            // Sparkle.framework sits next to the binary after `swift build`,
            // and in Contents/Frameworks in the app.
            linkerSettings: [.unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@loader_path",
                                           "-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"])]),
        .testTarget(name: "PlinthTests", dependencies: ["Plinth"])
    ]
)
