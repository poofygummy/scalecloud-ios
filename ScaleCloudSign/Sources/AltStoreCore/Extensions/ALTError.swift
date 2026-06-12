//
//  ALTError.swift
//  AltStore
//
//  Created by Riley Testut on 3/9/20.
//  Copyright © 2020 Riley Testut. All rights reserved.
//

import Foundation

public protocol ALTErrorCode
{
    var rawValue: Int { get }
}

public protocol ALTErrorEnum: ALTErrorCode, CaseIterable
{
    associatedtype Error: ALTLocalizedError where Error.Code == Self
}

public protocol ALTLocalizedError: LocalizedError
{
    associatedtype Code: ALTErrorCode
    
    var errorCode: Code? { get }
    var errorTitle: String? { get }
    var errorFailure: String? { get }
}

public extension ALTLocalizedError
{
    var errorDescription: String? {
        return self.errorFailure
    }
    
    var failureReason: String? {
        return self.errorFailure
    }
    
    var recoverySuggestion: String? {
        return nil
    }
}

public extension ALTErrorEnum
{
    static var errorDomain: String {
        return Bundle.main.bundleIdentifier ?? "com.scalecloud"
    }
    
    func callAsFunction(_ userInfo: [String: Any] = [:]) -> Error
    {
        return Error(self, userInfo: userInfo)
    }
}

public struct ALTWrappedError<Code: ALTErrorCode>: ALTLocalizedError
{
    public let errorCode: Code?
    public let errorTitle: String?
    public let errorFailure: String?
    
    public init(_ code: Code?, errorTitle: String? = nil, errorFailure: String? = nil, userInfo: [String: Any] = [:])
    {
        self.errorCode = code
        self.errorTitle = errorTitle
        self.errorFailure = errorFailure
    }
}
