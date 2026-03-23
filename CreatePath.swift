//
//  CreatePath.swift
//  EAS Photo Booth
//
//  Created by Jim Webb on 7/31/15.
//  Copyright (c) 2015 Jim Webb All rights reserved.
//

import Foundation
import UIKit

class CreatePath {
    
    typealias location = (x: Int, y: Int)
    var withinCoordGrid = [[CoOrd]]()
    var ofScreenSize = EASScreen()
    var buildPath = [location]()
    let opacity = Float()
    
    func startPathBuilder() -> [location]? {
        
        var currentPoint: CoOrd? = withinCoordGrid[0][0]
        
        while currentPoint != nil {
            if findNearestUnpaintedNeighbor(currentPoint!) != nil {
                let nextNeighbors = findNearestUnpaintedNeighbor(currentPoint!)
                let nextChosenPoint = choseNextPoint(currentPoint!, neighborArray: nextNeighbors!)
                buildPath += createPathToPoint(currentPoint!.location, endPoint: nextChosenPoint.location)
                currentPoint = nextChosenPoint
            } else {
                currentPoint = nil
            }
        }
        
        if !buildPath.isEmpty {
            return buildPath
        } else {
            return nil
        }
    }
    
    func findNearestUnpaintedNeighbor(toThisCoord: CoOrd) -> [CoOrd]? {

        var stepAway = 1
        var largestX = Int()
        var largestY = Int()
        var smallestX = Int()
        var smallestY = Int()
        var nearestNeighbors = [CoOrd]()
        
        repeat {
            
            smallestX = max(toThisCoord.location.x - stepAway, ofScreenSize.minWidth)
            largestX = min(toThisCoord.location.x + stepAway, ofScreenSize.maxWidth)
            smallestY = max(toThisCoord.location.y - stepAway, ofScreenSize.minHeight)
            largestY = min(toThisCoord.location.y + stepAway, ofScreenSize.maxHeight)
            
            for var i = smallestX; i <= largestX; i++ {
                if withinCoordGrid[i][largestY].painted && !withinCoordGrid[i][largestY].alreadyVisited {
                    nearestNeighbors.append(withinCoordGrid[i][largestY])
                }
            }
            for var j = largestY; j >= smallestY; j-- {
                if withinCoordGrid[largestX][j].painted && !withinCoordGrid[largestX][j].alreadyVisited {
                    nearestNeighbors.append(withinCoordGrid[largestX][j])
                }
            }
            for var i = largestX; i >= smallestX; i-- {
                if withinCoordGrid[i][smallestY].painted && !withinCoordGrid[i][smallestY].alreadyVisited {
                    nearestNeighbors.append(withinCoordGrid[i][smallestY])
                }
            }
            for var j = smallestY; j <= largestY; j++ {
                if withinCoordGrid[smallestX][j].painted && !withinCoordGrid[smallestX][j].alreadyVisited {
                    nearestNeighbors.append(withinCoordGrid[smallestX][j])
                }
            }
            
            stepAway++
            
        } while nearestNeighbors.count == 0 && (stepAway <= max(ofScreenSize.maxHeight, ofScreenSize.maxWidth))
        
        if !nearestNeighbors.isEmpty {
            return nearestNeighbors
        } else {
            return nil
        }
        
    }
    
    func choseNextPoint(currentPoint: CoOrd, neighborArray: [CoOrd]) -> CoOrd {
        var neighbors = neighborArray
        
        for neighbor in neighbors {
            neighbor.imageDisruption = pathToPointDisruption(currentPoint.location, endPoint: neighbor.location)
        }
        
        neighbors.sortInPlace({$0.imageDisruption < $1.imageDisruption})
        
        if !neighbors.isEmpty {
            var f = 1
            if neighbors.count > 1 {
                while f < neighbors.count {
                    if neighbors[f].imageDisruption > neighbors[f - 1].imageDisruption {
                        neighbors.removeAtIndex(f)
                    } else {
                        f++
                    }
                }
            }
        }
        
        let chooseRandomRemainingElement = Int(arc4random_uniform(UInt32(neighbors.count)))
        return neighbors[chooseRandomRemainingElement]
        
    }
    
    func pathToPointDisruption(startPoint: location, endPoint: location) -> Int {
        
        var pathArray = [location]()
        let xDistance = endPoint.x -  startPoint.x
        let yDistance = endPoint.y - startPoint.y
        let xIncrementer = xDistance / max(abs(xDistance), 1)
        let yIncrementer = yDistance / max(abs(yDistance), 1)
        let distanceRatio = abs(Double(xDistance / max(abs(yDistance), 1)))
        var disturbanceMonitor = 0
        var currentPoint: location = startPoint{
            didSet {
                disturbanceMonitor += checkPointDistruption(currentPoint)
            }
        }
        
        
        while currentPoint.x != endPoint.x || currentPoint.y != endPoint.y {
            if distanceRatio >= 1 {
                for var i = 1.0; i <= distanceRatio; i++ {
                    if currentPoint.x != endPoint.x {
                        currentPoint.x += xIncrementer
                    } else {
                        break
                    }
                }
                if currentPoint.y != endPoint.y {
                    currentPoint.y += yIncrementer
                }
            } else {
                for var i = distanceRatio; i <= 1; i = i + distanceRatio {
                    if currentPoint.y != endPoint.y {
                        currentPoint.y += yIncrementer
                    } else {
                        break
                    }
                }
                if currentPoint.x != endPoint.x {
                    currentPoint.x += xIncrementer
                }
            }
        }
        
        return disturbanceMonitor
        
    }
    
    
    func createPathToPoint(startPoint: location, endPoint: location) -> [location] {
        
        var pathArray = [location]()
        let xDistance = endPoint.x - startPoint.x
        let yDistance = endPoint.y - startPoint.y
        let xIncrementer = xDistance / max(abs(xDistance), 1)
        let yIncrementer = yDistance / max(abs(yDistance), 1)
        let distanceRatio = abs(Double(xDistance / max(abs(yDistance), 1)))
        var disturbanceMonitor = 0
        withinCoordGrid[startPoint.x][startPoint.y].alreadyVisited = true
        
        var currentPoint: location = startPoint {
            didSet {
                pathArray.append(currentPoint)
                withinCoordGrid[currentPoint.x][currentPoint.y].alreadyVisited = true
            }
        }

        while currentPoint.x != endPoint.x || currentPoint.y != endPoint.y {
            if distanceRatio >= 1 {
                for var i = 1.0; i <= distanceRatio; i++ {
                    if currentPoint.x != endPoint.x {
                        currentPoint.x += xIncrementer
                    } else {
                        break
                    }
                }
                if currentPoint.y != endPoint.y {
                    currentPoint.y += yIncrementer
                }
            } else {
                for var i = distanceRatio; i <= 1; i = i + distanceRatio {
                    if currentPoint.y != endPoint.y {
                        currentPoint.y += yIncrementer
                    } else {
                        break
                    }
                }
                if currentPoint.x != endPoint.x {
                    currentPoint.x += xIncrementer
                }
            }
        }
        
        return pathArray
        
    }

    
    func checkPointDistruption(point: (location)) -> Int {
        if !withinCoordGrid[point.x][point.y].painted || !withinCoordGrid[point.x][point.y].alreadyVisited {
            return 1
        }
        return 0
    }
    
    func createTextDirections(xMotor: Motor, yMotor: Motor) -> String {
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
    
    func createCompressedDirections() -> String {
        var compressedPath: String = ""
        var newByte: UInt8 = 0b00000000
        
//            {
//            didSet {
//                if countBytes == 4 {
//                    compressedPath.append(Character(UnicodeScalar(newByte)))
//                    countBytes = 1
//                    newByte = 0
//                }
//            }
//        }
        
//        for letter in textPath.characters {
//            select case letter{
//            }
//        }
        if buildPath.count > 1 {
            print("In Compressor")
            for i in 1..<buildPath.count {
                if (buildPath.count - i) > 4 {
                    if buildPath[i].x < buildPath[i - 1].x {
                        newByte | 0b00000000
                    } else if buildPath[i].x > buildPath[i - 1].x {
                        newByte | 0b00000001
                    } else if buildPath[i].y < buildPath[i - 1].y {
                        newByte | 0b00000010
                    } else if buildPath[i].y > buildPath[i - 1].y {
                        newByte | 0b00000011
                    }
                    if i % 4 == 0 {
                        compressedPath.append(Character(UnicodeScalar(newByte)))
                        print("\(Character(UnicodeScalar(newByte)))")
                        newByte = 0
                    }

                }
            }
        }
        print("# Characters: \(compressedPath.characters)")
        return compressedPath
    }
    
}


