//: Playground - noun: a place where people can play

import UIKit

var str = "Hello, playground"

typealias location = (x: Int, y: Int)

let startPoint: location = (x: 1, y: 1)
var pathArray: [location] = []

    var currentPoint: location = startPoint {
        didSet(lastPoint) {
            if currentPoint.x != startPoint.x || currentPoint.y != startPoint.y {
                pathArray.append(currentPoint)
            }
            println("I Changed")
        }
    }
    

currentPoint = (5,3)
currentPoint = (1, 1)

 