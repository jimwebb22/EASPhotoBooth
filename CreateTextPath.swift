//
//  CreateTextPath.swift
//  EAS Photo Booth
//
//  Created by Jim Webb on 4/4/16.
//  Copyright © 2016 Jim Webb All rights reserved.
//

import Foundation

class CreateTextPath {
    
    let buildPath: [Location]
    
    init(pathOfLocations: [Location]) {
        self.buildPath = pathOfLocations
    }
    
    func createTextDirections(_ xMotor: Motor, yMotor: Motor) -> String {
        var textPath: String = ""
        
        if buildPath.count > 1 {
            for i in 1..<buildPath.count {
                if buildPath[i].x < buildPath[i - 1].x {
                    if xMotor.lastDirection != .antiClockwise {
                        for _ in 0..<xMotor.motionChangeDrift {
                            textPath += "L"
                        }
                    }
                    textPath += "L"
                    xMotor.lastDirection = .antiClockwise
                    
                } else if buildPath[i].x > buildPath[i - 1].x {
                    if xMotor.lastDirection != .clockwise {
                        for _ in 0..<xMotor.motionChangeDrift {
                            textPath += "R"
                        }
                    }
                    textPath += "R"
                    xMotor.lastDirection = .clockwise
                    
                } else if buildPath[i].y < buildPath[i - 1].y {
                    if yMotor.lastDirection != .clockwise {
                        for _ in 0..<yMotor.motionChangeDrift {
                            textPath += "U"
                        }
                    }
                    textPath += "U"
                    yMotor.lastDirection = .clockwise
                    
                } else if buildPath[i].y > buildPath[i - 1].y {
                    if yMotor.lastDirection != .antiClockwise {
                        for _ in 0..<yMotor.motionChangeDrift {
                            textPath += "D"
                        }
                    }
                    textPath += "D"
                    yMotor.lastDirection = .antiClockwise
                }
            }
        }
        
        return textPath
    }
    
}
