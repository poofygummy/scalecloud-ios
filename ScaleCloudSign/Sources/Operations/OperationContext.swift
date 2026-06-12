//
//  OperationContext.swift
//  AltStore
//
//  Created by Riley Testut on 6/7/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

import Foundation
import AltSign

class OperationContext
{
    var error: Error?
    
    init()
    {
    }
}

class AuthenticatedOperationContext: OperationContext
{
    var session: ALTAppleAPISession?
    var team: ALTTeam?
    var certificate: ALTCertificate?
    
    override init()
    {
        super.init()
    }
}

class AppOperationContext: AuthenticatedOperationContext
{
    var app: ALTApplication?
    var profiles: [String: ALTProvisioningProfile]?
    var provisioningProfiles: [String: ALTProvisioningProfile]?
    var resignedApp: ALTApplication?
    
    override init()
    {
        super.init()
    }
}
