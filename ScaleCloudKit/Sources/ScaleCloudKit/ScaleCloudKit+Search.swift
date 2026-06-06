// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2023/2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Alamofire
import SwiftyJSON

public extension ScaleCloudKit {


    /// Performs a unified search using multiple providers and returns results asynchronously.
    ///
    /// - Parameters:
    ///   - timeout: The individual request timeout per provider.
    ///   - account: The Nextcloud account performing the search.
    ///   - options: Optional configuration for the request (headers, queue, etc.).
    ///   - handle: Optional operation handle that receives the underlying DataRequest and URLSessionTask
    ///             as soon as they are created. Use it to cancel the request while it’s in flight
    ///             (via handle.cancel()) or to observe the task/request lifecycle.
    ///   - filter: A closure to filter which `SCKSearchProvider` are enabled.
    ///
    /// - Returns: SCKSearchProvider, SCKError
    func unifiedSearchProviders(timeout: TimeInterval = 30,
                                account: String,
                                options: SCKRequestOptions = SCKRequestOptions(),
                                handle: SCKOperationHandle? = nil,
                                filter: @escaping (SCKSearchProvider) -> Bool = { _ in true }
    ) async -> (providers: [SCKSearchProvider]?, error: SCKError) {
        let endpoint = "ocs/v2.php/search/providers"
        guard let nkSession = nkCommonInstance.nksessions.session(forAccount: account),
              let url = nkCommonInstance.createStandardUrl(serverUrl: nkSession.urlBase, endpoint: endpoint),
              let headers = nkCommonInstance.getStandardHeaders(account: account, options: options) else {
            return (nil, .urlError)
        }

        let request = nkSession.sessionData
            .request(url, headers: headers, interceptor: SCKInterceptor(nkCommonInstance: nkCommonInstance))
            .onURLSessionTaskCreation { task in
                task.taskDescription = options.taskDescription
                Task {
                    if let handle {
                        await handle.set(task: task)
                    }
                }
            }
            .validate(statusCode: 200..<300)

        await handle?.set(request: request)
        let response = await request.serializingData().response

        switch response.result {
        case .success(let jsonData):
            let json = JSON(jsonData)
            let providerData = json["ocs"]["data"]
            let providers = SCKSearchProvider.factory(jsonArray: providerData)?.filter(filter)

            return(providers, .success)
        case .failure(let error):
            let nkError = SCKError(error: error, afResponse: response, responseData: response.data)

            return (nil, nkError)
        }
    }

    /// Performs a search using a specified provider with pagination and timeout support.
    ///
    /// - Parameters:
    ///   - providerId: The identifier of the search provider to use.
    ///   - term: The search term.
    ///   - limit: Optional maximum number of results to return.
    ///   - cursor: Optional pagination cursor for subsequent requests.
    ///   - timeout: The timeout interval for the search request.
    ///   - account: The Nextcloud account performing the search.
    ///   - options: Optional request configuration such as headers and queue.
    ///   - handle: Optional operation handle that receives the underlying DataRequest and URLSessionTask
    ///             as soon as they are created. Use it to cancel the request while it’s in flight
    ///             (via handle.cancel()) or to observe the task/request lifecycle.
    ///
    /// - Returns: SCKSearchResult, SCKError
    func unifiedSearch(providerId: String,
                       term: String,
                       limit: Int? = nil,
                       cursor: Int? = nil,
                       timeout: TimeInterval = 60,
                       account: String,
                       options: SCKRequestOptions = SCKRequestOptions(),
                       handle: SCKOperationHandle? = nil)
    async -> (searchResult: SCKSearchResult?, error: SCKError) {
        guard let term = term.urlEncoded,
              let nkSession = nkCommonInstance.nksessions.session(forAccount: account),
              let headers = nkCommonInstance.getStandardHeaders(account: account, options: options) else {
            return(nil, .urlError)
        }
        var endpoint = "ocs/v2.php/search/providers/\(providerId)/search?term=\(term)"
        if let limit = limit {
            endpoint += "&limit=\(limit)"
        }
        if let cursor = cursor {
            endpoint += "&cursor=\(cursor)"
        }
        guard let url = self.nkCommonInstance.createStandardUrl(serverUrl: nkSession.urlBase, endpoint: endpoint)
        else {
            return(nil, .urlError)
        }
        var urlRequest: URLRequest

        do {
            try urlRequest = URLRequest(url: url, method: .get, headers: headers)
            urlRequest.timeoutInterval = timeout
        } catch {
            return(nil, SCKError(error: error))
        }

        let request = nkSession.sessionData
            .request(urlRequest, interceptor: SCKInterceptor(nkCommonInstance: nkCommonInstance))
            .validate(statusCode: 200..<300)
            .onURLSessionTaskCreation { task in
                task.taskDescription = options.taskDescription
                Task {
                    if let handle {
                        await handle.set(task: task)
                    }
                }
            }

        await handle?.set(request: request)
        let response = await request.serializingData().response

        switch response.result {
        case .success(let jsonData):
            let json = JSON(jsonData)
            let searchData = json["ocs"]["data"]
            let searchResult = SCKSearchResult(json: searchData, id: providerId)

            return (searchResult, .success)
        case .failure(let error):
            let nkError = SCKError(error: error, afResponse: response, responseData: response.data)

            return (nil, nkError)
        }
    }
}

public class SCKSearchResult: NSObject {
    public let id: String
    public let name: String
    public let isPaginated: Bool
    public let entries: [SCKSearchEntry]
    public let cursor: Int?

    init?(json: JSON, id: String) {
        guard let isPaginated = json["isPaginated"].bool,
              let name = json["name"].string,
              let entries = SCKSearchEntry.factory(jsonArray: json["entries"])
        else { return nil }
        self.id = id
        self.cursor = json["cursor"].int
        self.name = name
        self.isPaginated = isPaginated
        self.entries = entries
    }
}

public class SCKSearchEntry: NSObject {
    public let thumbnailURL: String
    public let title, subline: String
    public let resourceURL: String
    public let icon: String
    public let rounded: Bool
    public let attributes: [String: Any]?
    public var fileId: Int? {
        guard let fileAttribute = attributes?["fileId"] as? String else { return nil }
        return Int(fileAttribute)
    }
    public var filePath: String? {
        attributes?["path"] as? String
    }

    init?(json: JSON) {
        guard let thumbnailURL = json["thumbnailUrl"].string,
              let title = json["title"].string,
              let subline = json["subline"].string,
              let resourceURL = json["resourceUrl"].string,
              let icon = json["icon"].string,
              let rounded = json["rounded"].bool
        else { return nil }

        self.thumbnailURL = thumbnailURL
        self.title = title
        self.subline = subline
        self.resourceURL = resourceURL
        self.icon = icon
        self.rounded = rounded
        self.attributes = json["attributes"].dictionaryObject
    }

    static func factory(jsonArray: JSON) -> [SCKSearchEntry]? {
        guard let allProvider = jsonArray.array else { return nil }
        return allProvider.compactMap(SCKSearchEntry.init)
    }
}

public class SCKSearchProvider: NSObject {
    public let id, name: String
    public let order: Int

    // Initialize from JSON
    init?(json: JSON) {
        guard let id = json["id"].string,
              let name = json["name"].string,
              let order = json["order"].int
        else { return nil }
        self.id = id
        self.name = name
        self.order = order
    }

    // Classic initializer
    public init(id: String, name: String, order: Int) {
        self.id = id
        self.name = name
        self.order = order
        super.init()
    }

    static func factory(jsonArray: JSON) -> [SCKSearchProvider]? {
        guard let allProvider = jsonArray.array else { return nil }
        return allProvider.compactMap(SCKSearchProvider.init)
    }
}

