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
            scripts: [
                .post(
                    script: """
PREBUILT_FRAMEWORK="$PROJECT_DIR/prebuilt/ScaleCloudKit.framework"
TARGET_FRAMEWORK="$BUILT_PRODUCTS_DIR/ScaleCloudKit.framework"

# If prebuilt exists, use it instead of the just-built version
if [ -d "$PREBUILT_FRAMEWORK" ]; then
    echo "Using prebuilt ScaleCloudKit.framework"
    rm -rf "$TARGET_FRAMEWORK"
    cp -R "$PREBUILT_FRAMEWORK" "$TARGET_FRAMEWORK"
    echo "Replaced with prebuilt framework"
else
    echo "Using freshly built ScaleCloudKit.framework"
fi
""",
                    name: "Use Prebuilt Framework If Available"
                )
            ],
            dependencies: [
                .project(target: "ScaleCloudGo", path: "../ScaleCloudGo"),
                .external(name: "Alamofire"),
                .external(name: "SwiftyJSON"),
                .external(name: "SwiftyXMLParser")
            ]
        )
    ]
)
