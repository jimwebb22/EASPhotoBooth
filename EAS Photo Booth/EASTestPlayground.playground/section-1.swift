// Playground - noun: a place where people can play

import Cocoa
import Foundation

var str = "Hello, playground"


func fibonacci(input: Int) -> Int{
    switch input {
        case 0: return 0
        case 1: return 1
        default: return (fibonacci(input-2) + fibonacci(input-1))
    }
}

fibonacci(10)

class EASScreen {
    
    let MaxWidth = 10
    let MaxHeight = 10
    let MinWidth = 0
    let MinHeight = 0

}


let newScreen = EASScreen()

class CoOrd{
    var location = (x: Int() ,y: Int())
    var painted = false
    var alreadyVisited = false
    var nearestNeighbors = [CoOrd]()
    
    func distanceToCoord (checkCoord: CoOrd) -> Double{
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



class RankedCoOrd: CoOrd {
    var disturbance = 0
}


//MARK:  Succesful 2 Dimensional Implementation

var grid = [[CoOrd]]()

for i in 0..<newScreen.MaxWidth {
    grid.append([CoOrd]())
    for j in 0..<newScreen.MaxHeight {
        grid[i].append(CoOrd(x: i, y: j))
        print("Coord, \(grid[i][j].location.x), \(grid[i][j].location.y)")
    }
}

class Motor {
}

let checkDistance = grid[0][0].distanceToCoord(grid[3][4])
print("\(checkDistance)")




