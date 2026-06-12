//
//  ResultOperation.swift
//  Roxas
//
//  Created by Riley Testut on 6/27/17.
//  Copyright © 2017 Riley Testut. All rights reserved.
//

import Foundation

open class ResultOperation<Success>: RSTOperation
{
    public private(set) var result: Result<Success, Error>?
    
    open var resultHandler: ((Result<Success, Error>) -> Void)?
    
    override public init()
    {
        super.init()
    }
    
    open func finish(_ result: Result<Success, Error>)
    {
        self.result = result
        
        if let resultHandler = self.resultHandler
        {
            resultHandler(result)
        }
    }
}
