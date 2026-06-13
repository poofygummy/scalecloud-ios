//
//  ViewApp+Generated.swift
//  AltStoreCore
//
//  Generated from ViewApp.intentdefinition
//  This file mimics Xcode's intentdefinition code generation
//

import Foundation
import Intents

// MARK: - App (INObject)

@available(iOS 13.0, macOS 10.16, *)
public class App: INObject {
    
    @NSManaged public var identifier: String?
    @NSManaged public var displayString: String?
    @NSManaged public var pronunciationHint: String?
    @NSManaged public var alternativeSpeakableMatches: [INSpeakableString]?
    
    public convenience init(identifier: String, display displayString: String) {
        self.init()
        self.identifier = identifier
        self.displayString = displayString
    }
}

// MARK: - ViewAppIntent

@available(iOS 13.0, macOS 10.16, *)
public class ViewAppIntent: INIntent {
    
    @NSManaged public var app: App?
}

// MARK: - ViewAppIntentHandling Protocol

@available(iOS 13.0, macOS 10.16, *)
public protocol ViewAppIntentHandling: NSObjectProtocol {
    
    func provideAppOptionsCollection(for intent: ViewAppIntent, with completion: @escaping (INObjectCollection<App>?, Error?) -> Void)
    
    optional func handle(intent: ViewAppIntent, completion: @escaping (ViewAppIntentResponse) -> Void)
    
    optional func confirm(intent: ViewAppIntent, completion: @escaping (ViewAppIntentResponse) -> Void)
    
    optional func resolveApp(for intent: ViewAppIntent, with completion: @escaping (AppResolutionResult) -> Void)
}

// MARK: - ViewAppIntentResponse

@available(iOS 13.0, macOS 10.16, *)
public class ViewAppIntentResponse: INIntentResponse {
    
    public enum Code: Int {
        case success = 0
        case failure = 1
    }
    
    @NSManaged public var code: Code
    
    public convenience init(code: Code, userActivity: NSUserActivity?) {
        self.init()
        self.code = code
        self.userActivity = userActivity
    }
}

// MARK: - AppResolutionResult

@available(iOS 13.0, macOS 10.16, *)
public class AppResolutionResult: INObjectResolutionResult {
    
    public class func success(with resolvedObject: App) -> AppResolutionResult {
        return self.success(with: resolvedObject) as! AppResolutionResult
    }
    
    public class func disambiguation(with objectsToDisambiguate: [App]) -> AppResolutionResult {
        return self.disambiguation(with: objectsToDisambiguate) as! AppResolutionResult
    }
    
    public class func confirmationRequired(with objectToConfirm: App?) -> AppResolutionResult {
        return self.confirmationRequired(with: objectToConfirm) as! AppResolutionResult
    }
}
