// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2024 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Alamofire
import SwiftyJSON

public extension ScaleCloudKit {
    /// - Parameters:
    ///   - account: The account to query.
    ///   - options: Optional request options (defaults to standard).
    /// - Returns: Tuple with SCKError and optional SCKTermsOfService.
    func getTermsOfService(account: String,
                           options: SCKRequestOptions = SCKRequestOptions(),
                           request: @escaping (DataRequest?) -> Void = { _ in },
                           taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                           completion: @escaping (_ account: String, _ tos: SCKTermsOfService?, _ responseData: AFDataResponse<Data>?, _ error: SCKError) -> Void) {
        let endpoint = "ocs/v2.php/apps/terms_of_service/terms"
        guard let nkSession = nkCommonInstance.nksessions.session(forAccount: account),
              let url = nkCommonInstance.createStandardUrl(serverUrl: nkSession.urlBase, endpoint: endpoint),
              let headers = nkCommonInstance.getStandardHeaders(account: account, options: options) else {
            return options.queue.async { completion(account, nil, nil, .urlError) }
        }

        let tosRequest = nkSession.sessionData.request(url, method: .get, encoding: URLEncoding.default, headers: headers, interceptor: SCKInterceptor(nkCommonInstance: nkCommonInstance)).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
            task.taskDescription = options.taskDescription
            taskHandler(task)
        }.responseData(queue: self.nkCommonInstance.backgroundQueue) { response in
            switch response.result {
            case .success(let jsonData):
                let tos = SCKTermsOfService()
                if tos.loadFromJSON(jsonData), let meta = tos.getMeta() {
                    if meta.statuscode == 200 {
                        options.queue.async { completion(account, tos, response, .success) }
                    } else {
                        options.queue.async { completion(account, tos, response, SCKError(errorCode: meta.statuscode, errorDescription: meta.message, responseData: jsonData)) }
                    }
                } else {
                    options.queue.async { completion(account, nil, response, .invalidData) }
                }
            case .failure(let error):
                let error = SCKError(error: error, afResponse: response, responseData: response.data)
                options.queue.async { completion(account, nil, response, error) }
            }
        }
        options.queue.async { request(tosRequest) }
    }

    /// Async wrapper for `getTermsOfService(account:options:...)`
    /// - Parameters:
    ///   - account: The account to query.
    ///   - options: Optional request options (defaults to standard).
    /// - Returns: Tuple with SCKError and optional SCKTermsOfService.
    func getTermsOfServiceAsync(account: String,
                                options: SCKRequestOptions = SCKRequestOptions(),
                                request: ((DataRequest?) -> Void)? = nil,
                                taskHandler: ((URLSessionTask) -> Void)? = nil
    ) async -> (error: SCKError, tos: SCKTermsOfService?) {
        await withCheckedContinuation { continuation in
            self.getTermsOfService(
                account: account,
                options: options,
                request: request ?? { _ in },
                taskHandler: taskHandler ?? { _ in }
            ) { _, tos, _, error in
                continuation.resume(returning: (error, tos))
            }
        }
    }

    /// - Parameters:
    ///   - termId: The ID of the ToS to sign.
    ///   - account: The user account.
    ///   - options: Optional request options.
    ///   - taskHandler: Optional URLSession task handler.
    /// - Returns: SCKError and AFDataResponse<Data>?
    func signTermsOfService(termId: String,
                            account: String,
                            options: SCKRequestOptions = SCKRequestOptions(),
                            taskHandler: @escaping (_ task: URLSessionTask) -> Void = { _ in },
                            completion: @escaping (_ account: String, _ responseData: AFDataResponse<Data>?, _ error: SCKError) -> Void) {
        let endpoint = "ocs/v2.php/apps/terms_of_service/sign"
        var urlRequest: URLRequest
        guard let nkSession = nkCommonInstance.nksessions.session(forAccount: account),
              let url = nkCommonInstance.createStandardUrl(serverUrl: nkSession.urlBase, endpoint: endpoint),
              let headers = nkCommonInstance.getStandardHeaders(account: account, options: options, contentType: "application/json") else {
            return options.queue.async { completion(account, nil, .urlError) }
        }

        do {
            try urlRequest = URLRequest(url: url, method: .post, headers: headers)
            let parameters = "{\"termId\":\"" + termId + "\"}"
            urlRequest.httpBody = parameters.data(using: .utf8)
        } catch {
            return options.queue.async { completion(account, nil, SCKError(error: error)) }
        }

        nkSession.sessionData.request(urlRequest, interceptor: SCKInterceptor(nkCommonInstance: nkCommonInstance)).validate(statusCode: 200..<300).onURLSessionTaskCreation { task in
            task.taskDescription = options.taskDescription
            taskHandler(task)
        }.responseData(queue: self.nkCommonInstance.backgroundQueue) { response in
            switch response.result {
            case .failure(let error):
                let error = SCKError(error: error, afResponse: response, responseData: response.data)
                options.queue.async { completion(account, response, error) }
            case .success:
                options.queue.async { completion(account, response, .success) }
            }
        }
    }

    /// Async wrapper for `signTermsOfService`
    /// - Parameters:
    ///   - termId: The ID of the ToS to sign.
    ///   - account: The user account.
    ///   - options: Optional request options.
    ///   - taskHandler: Optional URLSession task handler.
    /// - Returns: SCKError and AFDataResponse<Data>?
    func signTermsOfServiceAsync(termId: String,
                                 account: String,
                                 options: SCKRequestOptions = SCKRequestOptions(),
                                 taskHandler: ((URLSessionTask) -> Void)? = nil
    ) async -> (error: SCKError, response: AFDataResponse<Data>?) {
        await withCheckedContinuation { continuation in
            self.signTermsOfService(
                termId: termId,
                account: account,
                options: options,
                taskHandler: taskHandler ?? { _ in }
            ) { _, responseData, error in
                continuation.resume(returning: (error, responseData))
            }
        }
    }
}
