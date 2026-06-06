// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2024 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import XCTest
import Alamofire
@testable import ScaleCloudKit

final class ShareIntegrationTests: BaseIntegrationXCTestCase {
//    func test_createShare_withNote_shouldCreateShare() throws {
//        let expectation = expectation(description: "Should finish last callback")
//        
//        let folderName = "Share\(randomInt)"
//        let serverUrl = "\(TestConstants.server)/remote.php/dav/files/\(TestConstants.username)"
//        let serverUrlFileName = "\(serverUrl)/\(folderName)"
//
//        ScaleCloudKit.shared.appendSession(account: TestConstants.account, urlBase: TestConstants.server, user: TestConstants.username, userId: TestConstants.username, password: TestConstants.password, userAgent: "", nextcloudVersion: 0, groupIdentifier: "")
//
//        ScaleCloudKit.shared.createFolder(serverUrlFileName: serverUrlFileName, account: TestConstants.account) { account, ocId, date, _, error in
//            XCTAssertEqual(TestConstants.account, account)
//
//            XCTAssertEqual(NKError.success.errorCode, error.errorCode)
//            XCTAssertEqual(NKError.success.errorDescription, error.errorDescription)
//            
//            Thread.sleep(forTimeInterval: 0.2)
//
//            let note = "Test note"
//
//            ScaleCloudKit.shared.createShare(path: folderName, shareType: 0, shareWith: "nextcloud", note: note, account: "") { account, share, data, error in
//                defer { expectation.fulfill() }
//
//                XCTAssertEqual(TestConstants.account, account)
//                XCTAssertEqual(NKError.success.errorCode, error.errorCode)
//                XCTAssertEqual(NKError.success.errorDescription, error.errorDescription)
//                XCTAssertEqual(note, share?.note)
//            }
//        }
//
//        waitForExpectations(timeout: 100)
//    }
}
