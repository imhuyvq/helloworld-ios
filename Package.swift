// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "HelloWorld",
    platforms: [
        // MinimumOSVersion trong Info.plist được xtool lấy từ dòng này.
        // Đổi ở đây thì nhớ đổi "minOSVersion" trong repo.json (release script tự đọc lại từ IPA).
        .iOS(.v16),
        .macOS(.v14),
    ],
    products: [
        // An xtool project should contain exactly one library product,
        // representing the main app.
        .library(
            name: "HelloWorld",
            targets: ["HelloWorld"]
        ),
    ],
    targets: [
        .target(
            name: "HelloWorld"
        ),
    ]
)
