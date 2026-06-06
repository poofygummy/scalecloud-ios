// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2024 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import XCTest
import Foundation
import Alamofire
import ScaleCloudKit

class BaseXCTestCase: XCTestCase {
    var appToken = ""
    var ncKit: ScaleCloudKit!

    func setupAppToken() async {
        let expectation = expectation(description: "Should get app token")
#if swift(<6.0)
        ncKit = ScaleCloudKit.shared
#else
        ncKit = ScaleCloudKit()
#endif

        ncKit.getAppPassword(url: TestConstants.server, user: TestConstants.username, password: TestConstants.password) { token, _, error in
            XCTAssertEqual(error.errorCode, 0)
            XCTAssertNotNil(token)

            guard let token else { return XCTFail() }
            
            self.appToken = token
            expectation.fulfill()
        }

        await fulfillment(of: [expectation], timeout: TestConstants.timeoutLong)
    }

    override func setUp() async throws {
        await setupAppToken()
    }
}
