import PackageDescription

let package = Package(
    name: "ScaleCloudDependencies",
    dependencies: [
        .package(url: "https://github.com/Alamofire/Alamofire", .upToNextMajor(from: "5.10.2")),
        .package(url: "https://github.com/SwiftyJSON/SwiftyJSON", .upToNextMajor(from: "5.0.2")),
        .package(url: "https://github.com/yahoojapan/SwiftyXMLParser", .upToNextMajor(from: "5.6.0")),
        .package(url: "https://github.com/WeTransfer/Mocker.git", .upToNextMajor(from: "3.0.2"))
    ]
)
