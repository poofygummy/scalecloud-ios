// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

public extension ScaleCloudKit {
    /// Shared logger accessible via ScaleCloudKit.logger
    static var logger: SCKLogFileManager {
        return SCKLogFileManager.shared
    }

    /// Configure the shared logger from ScaleCloudKit
    static func configureLogger(logLevel: SCKLogLevel = .normal) {
        SCKLogFileManager.configure(logLevel: logLevel)
    }

    /// Configure the shared logger blacklist from ScaleCloudKit
    static func configureLoggerBlacklist(blacklist: [String]) {
        SCKLogFileManager.setBlacklist(blacklist: blacklist)
    }

    /// Configure the shared logger whitelist from ScaleCloudKit
    static func configureLoggerWhitelist(whitelist: [String]) {
        SCKLogFileManager.setCandidate(whitelist: whitelist)
    }
}
