//
//  CoOrd.swift
//  EAS Photo Booth
//
//  Created by Jim Webb on 5/25/15.
//  Copyright (c) 2015 Jim Webb All rights reserved.
//

import Foundation

class CoOrd{
    
    var location = (x: Int(), y: Int())
    var painted = false
    var alreadyVisited = false
    var imageDisruption = 0
    
    func distanceToCoord (checkCoord: CoOrd) -> Double {
        let a = abs(self.location.x  - checkCoord.location.x)
        let b = abs(self.location.y  - checkCoord.location.y)
        let c = sqrt(Double(a*a + b*b))
        return c
    }
    
    init(x: Int, y: Int){
        location.x = x
        location.y = y
    }
    
}