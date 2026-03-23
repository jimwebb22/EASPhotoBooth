//
//  Motor.swift
//  EAS Photo Booth
//
//  Created by Jim Webb on 8/11/15.
//  Copyright (c) 2015 Jim Webb All rights reserved.
//

import Foundation

class Motor {
    
    var lastDirection: direction
    
    enum axis {
        case x
        case y
    }
    
    enum direction{
        case clockwise
        case antiClockwise
    }
    
    let motionChangeDrift: Int
    let thisMotorAxis: axis
    
    init (thisMotorAxis: axis, motionChangeDrift: Int) {
        self.thisMotorAxis = thisMotorAxis
        self.motionChangeDrift = motionChangeDrift
        lastDirection = thisMotorAxis == .x ? .antiClockwise : .clockwise
    }
    
}
