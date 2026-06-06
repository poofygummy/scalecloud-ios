// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

public extension SCKEditorDetailsResponse.OCS.DataClass {
    func editorsArray() -> [SCKEditorDetailsEditor] {
        Array(editors.values)
    }

    func creatorsArray() -> [SCKEditorDetailsCreator] {
        Array(creators.values)
    }
}
