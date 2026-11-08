// swift-tools-version: 5.9
import PackageDescription

// PLINTH_APPSTORE=1 builds for the Mac App Store, which updates the app
// itself: no Sparkle, and the APPSTORE flag for the code.
let appStore = Context.environment["PLINTH_APPSTORE"] == "1"

let package = Package(
    name: "Plinth",
    // iOS only for PlinthCore, which the iPhone app in iOS/ uses; this
    // package's app is the Mac's.
    platforms: [.macOS(.v14), .iOS(.v17)],
    // PlinthCore is a product so that the iPhone app can use it.
    products: [
        .executable(name: "Plinth", targets: ["Plinth"]),
        .library(name: "PlinthCore", targets: ["PlinthCore"])
    ],
    // Declared in every build, though the App Store build doesn't link it,
    // so that build leaves Package.resolved and its Sparkle pin alone.
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.10.1")
    ],
    targets: [
        // What the fish is without a Mac to sit on: the synthesized knock and
        // the hall it rings in, the rhythms and the incense, its few words, and
        // the skin it is drawn in. Nothing in it needs a Mac.
        .target(name: "PlinthCore", path: "Sources/PlinthCore"),
        // Resources live in App/Resources and are copied into the .app by
        // scripts/build_app.sh, so the code loads them from Bundle.main.
        .executableTarget(
            name: "Plinth",
            dependencies: ["PlinthCore"] + (appStore ? [] : [.product(name: "Sparkle", package: "Sparkle")]),
            path: "Sources/Plinth",
            swiftSettings: appStore ? [.define("APPSTORE")] : [],
            // Sparkle.framework sits next to the binary after `swift build`,
            // and in Contents/Frameworks in the app.
            linkerSettings: [.unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@loader_path",
                                           "-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"])]),
        .testTarget(name: "PlinthTests", dependencies: ["Plinth"])
    ]
)
