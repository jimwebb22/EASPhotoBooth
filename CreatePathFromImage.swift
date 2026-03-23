//
//  CreatePathFromImage.swift
//  EAS Photo Booth
//
//  Created by Jim Webb on 11/28/15.
//  Copyright © 2015 Jim Webb. All rights reserved.
//

import Foundation
import UIKit

class ImageCreatePath {
    
    var totalPointsToPaint: Int = 0 {
        didSet {
            remainingPoints = totalPointsToPaint
        }
    }
    var remainingPoints = Int()
    var drawingGrid = [[Bool]]()
    var visitedGrid = [[Bool]]()
    var buildPath = [Location]()
    let image: UIImage
    let opacity:  Float
    
    init (imageToConvert: UIImage, atOpactiy: Float) {
        image = imageToConvert
        opacity = atOpactiy
        determineTotalPaintedPoints()
    }
    
    func buildImagePath() -> [Location]? {
        
        var currentPoint: Location?
        currentPoint = Location(x: 0, y: 0)
        buildPath.append(currentPoint!)
        
        while currentPoint != nil {
            if let nextNeighbors = findNearestUnpaintedNeighbors(currentPoint!) {
                let nextChosenPoint = choseNextPoint(currentPoint!, neighborArray: nextNeighbors)
                buildPath += createPathToPoint(currentPoint!, endPoint: nextChosenPoint)
                currentPoint = nextChosenPoint
            } else {
                currentPoint = nil
            }
        }
        
        return buildPath.isEmpty ? nil : buildPath

    }
    
    func findNearestUnpaintedNeighbors(_ toThisCoord: Location) -> [Location]? {

        var stepAway = 1
        var nearestNeighbors = [Location]()
        var testPoint = toThisCoord {
            didSet {
                if drawingGrid[testPoint.x][testPoint.y] && !visitedGrid[testPoint.x][testPoint.y] {
                        nearestNeighbors.append(testPoint)
                }
            }
        }

        repeat {
            
            let smallestX = max(toThisCoord.x - stepAway, 0)
            let largestX = min(toThisCoord.x + stepAway, Int(image.size.width)-1)
            let smallestY = max(toThisCoord.y - stepAway, 0)
            let largestY = min(toThisCoord.y + stepAway, Int(image.size.height)-1)
            
            for i in smallestX..<largestX {
                testPoint = Location(x: i, y: largestY)
            }
            for j in (smallestY..<largestY).reversed() {
                testPoint = Location(x: largestX, y: j)
            }
            for i in (smallestX..<largestX).reversed() {
                testPoint = Location(x: i, y: smallestY)
            }
            for j in smallestY..<largestY {
                testPoint = Location(x: smallestX, y: j)
            }
            
            stepAway += 1
            
        } while nearestNeighbors.count < 1 && (stepAway <= Int(max(image.size.height, image.size.width)))
        
        return nearestNeighbors.isEmpty ? nil : nearestNeighbors
        
    }
    
    func determinePainted(_ pointToTest: Location) -> Bool {
        
        var imageComponent: (r: Double, g: Double, b: Double, a: Double)
        let xPos = CGFloat(pointToTest.x)
        let yPos = CGFloat(pointToTest.y)
        
        imageComponent = image.determineComponents(CGPoint(x: xPos, y: yPos))
        
        return ((imageComponent.r + imageComponent.g + imageComponent.b) / 3) < Double(opacity) ? true : false
        
    }
    
    func choseNextPoint(_ currentPoint: Location, neighborArray: [Location]) -> Location {
        var neighbors = neighborArray
        
        for neighbor in neighbors {
            neighbor.imageDisruption = pathToPointDisruption(currentPoint, endPoint: neighbor)
        }
        
        neighbors.sort(by: {$0.imageDisruption < $1.imageDisruption})
        
        if !neighbors.isEmpty {
            var f = 1
            if neighbors.count > 1 {
                while f < neighbors.count {
                    if neighbors[f].imageDisruption > neighbors[f - 1].imageDisruption {
                        neighbors.remove(at: f)
                    } else {
                        f += 1
                    }
                }
            }
        }
        
        let chooseRandomRemainingElement = Int(arc4random_uniform(UInt32(neighbors.count)))
        return neighbors[chooseRandomRemainingElement]
    }
    
    func pathToPointDisruption(_ startPoint: Location, endPoint: Location) -> Int {
        
        var pathArray = [Location]()
        let xDistance = endPoint.x -  startPoint.x
        let yDistance = endPoint.y - startPoint.y
        let xIncrementer = xDistance / max(abs(xDistance), 1)
        let yIncrementer = yDistance / max(abs(yDistance), 1)
        let distanceRatio = abs(Double(xDistance / max(abs(yDistance), 1)))
        var disturbanceMonitor = 0
        var currentPoint: Location = startPoint{
            didSet {
                disturbanceMonitor += checkPointDistruption(currentPoint)
            }
        }
        
        
        while currentPoint.x != endPoint.x || currentPoint.y != endPoint.y {
            if distanceRatio >= 1 {
                var i = 1.0
                while i <= distanceRatio {
                    if currentPoint.x != endPoint.x {
                        currentPoint = Location(x: currentPoint.x + xIncrementer, y: currentPoint.y)
                    } else {
                        break
                    }
                    i += 1
                }
                if currentPoint.y != endPoint.y {
                    currentPoint = Location(x: currentPoint.x, y: currentPoint.y + yIncrementer)
                }
            } else {
                var i = distanceRatio
                while i <= 1 {
                    if currentPoint.y != endPoint.y {
                        currentPoint = Location(x: currentPoint.x, y: currentPoint.y + yIncrementer)
                    } else {
                        break
                    }
                    i += distanceRatio
                }
                if currentPoint.x != endPoint.x {
                    currentPoint = Location(x: currentPoint.x + xIncrementer, y: currentPoint.y)
                }
            }
        }
        
        return disturbanceMonitor
        
    }
    
    func createPathToPoint(_ startPoint: Location, endPoint: Location) -> [Location] {
        
        var pathArray = [Location]()
        let xDistance = endPoint.x - startPoint.x
        let yDistance = endPoint.y - startPoint.y
        let xIncrementer = xDistance / max(abs(xDistance), 1)
        let yIncrementer = yDistance / max(abs(yDistance), 1)
        let distanceRatio = abs(Double(xDistance / max(abs(yDistance), 1)))
        var disturbanceMonitor = 0
        
        var currentPoint: Location = startPoint {
            didSet {
                pathArray.append(currentPoint)
                visitedGrid[currentPoint.x][currentPoint.y] = true
            }
        }
        
        while currentPoint.x != endPoint.x || currentPoint.y != endPoint.y {
            if distanceRatio >= 1 {
                var i = 1.0
                while i <= distanceRatio {
                    if currentPoint.x != endPoint.x {
                        currentPoint = Location(x: currentPoint.x + xIncrementer, y: currentPoint.y)
                    } else {
                        break
                    }
                    i += 1
                }
                if currentPoint.y != endPoint.y {
                    currentPoint = Location(x: currentPoint.x, y: currentPoint.y + yIncrementer)
                }
            } else {
                var i = distanceRatio
                while i <= 1 {
                    if currentPoint.y != endPoint.y {
                        currentPoint = Location(x: currentPoint.x, y: currentPoint.y + yIncrementer)
                    } else {
                        break
                    }
                    i += distanceRatio
                }
                if currentPoint.x != endPoint.x {
                    currentPoint = Location(x: currentPoint.x + xIncrementer, y: currentPoint.y)
                }
            }
        }
        
        remainingPoints -= 1
        return pathArray
        
    }
    
    func checkPointDistruption(_ point: (Location)) -> Int {
        
        return !drawingGrid[point.x][point.y] || !visitedGrid[point.x][point.y] ? 1 : 0
    
    }
    
    func determineTotalPaintedPoints() {
        
        for i in 0..<Int(image.size.width) {
            drawingGrid.append([Bool]())
            visitedGrid.append([Bool]())
            
            for j in 0..<Int(image.size.height) {
                
                if determinePainted(Location(x: i, y: j)) {
                    totalPointsToPaint += 1
                    drawingGrid[i].append(true)
                } else {
                    drawingGrid[i].append(false)
                }
                visitedGrid[i].append(false)
            }
        }
        visitedGrid[0][0] = true
    }
    
}

extension UIImage {
    
    func determineComponents(_ pos: CGPoint) -> (r: Double, g: Double, b: Double, a: Double) {
        
        let pixelData = self.cgImage?.dataProvider?.data
        let data: UnsafePointer<UInt8> = CFDataGetBytePtr(pixelData)
        
        let pixelInfo: Int = ((Int(self.size.width) * Int(pos.y)) + Int(pos.x)) * 4
        
        let r = Double(CGFloat(data[pixelInfo]) / CGFloat(255.0))
        let g = Double(CGFloat(data[pixelInfo+1]) / CGFloat(255.0))
        let b = Double(CGFloat(data[pixelInfo+2]) / CGFloat(255.0))
        let a = Double(CGFloat(data[pixelInfo+3]) / CGFloat(255.0))
        
        return (r, g, b, a)
        
    }
    
}


