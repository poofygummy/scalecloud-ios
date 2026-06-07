import ProjectDescription

let project = Project(
    name: "ScaleCloudKit",
    settings: .settings(base: [
        "IPHONEOS_DEPLOYMENT_TARGET": "14.0",
        "FRAMEWORK_SEARCH_PATHS": "$(inherited) $(BUILT_PRODUCTS_DIR) $(PROJECT_DIR)/../ScaleCloudGo/prebuilt"
    ]),
    targets: [
        .target(
            name: "ScaleCloudKit",
            destinations: .iOS,
            product: .framework,
            bundleId: "com.scalecloud.ScaleCloudKit",
            deploymentTargets: .iOS("14.0"),
            sources: ["Sources/**"],
            dependencies: [
                .xcframework(path: "../ScaleCloudGo/prebuilt/ScaleCloudGo.xcframework"),
                .external(name: "Alamofire"),
                .external(name: "SwiftyJSON"),
                .external(name: "SwiftyXMLParser")
            ]
        )
    ]
)
