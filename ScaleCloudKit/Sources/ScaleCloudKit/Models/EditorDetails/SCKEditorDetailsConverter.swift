// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

public enum SCKEditorDetailsConverter {

    /// Parses and converts raw JSON `Data` into `[SCKEditorDetailsEditors]` and `[SCKEditorDetailsCreators]`.
    /// - Parameter data: Raw JSON `Data` from the editors/creators endpoint.
    /// - Returns: A tuple with editors and creators.
    /// - Throws: Decoding error if parsing fails.
    public static func from(data: Data) throws -> (editors: [SCKEditorDetailsEditor], creators: [SCKEditorDetailsCreator]) {
        let decoded = try JSONDecoder().decode(SCKEditorDetailsResponse.self, from: data)
        let editors = decoded.ocs.data.editorsArray()
        let creators = decoded.ocs.data.creatorsArray()

        if SCKLogFileManager.shared.logLevel == .verbose {
            data.printJson()
        }
        
        return (editors, creators)
    }
}
