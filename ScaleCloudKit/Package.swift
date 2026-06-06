// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ScaleCloud",
    platforms: [
        .iOS(.v14)
    ],
    dependencies: [
        .package(url: "https://github.com/Alamofire/Alamofire.git", from: "5.10.2"),
        .package(url: "https://github.com/SwiftyJSON/SwiftyJSON.git", from: "5.0.2"),
        .package(url: "https://github.com/yahoojapan/SwiftyXMLParser.git", from: "5.6.0"),
    ]
)
