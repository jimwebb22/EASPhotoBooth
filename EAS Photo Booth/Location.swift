//
//  Location.swift
//  EAS Photo Booth
//
//  Created by Jim Webb on 12/30/15.
//  Copyright © 2015 Jim Webb All rights reserved.
//

import Foundation

class Location {
    let x: Int
    let y: Int
    var imageDisruption = 0
    
    init(x: Int, y: Int){
        self.x = x
        self.y = y
    }
    
}

extension Location: Equatable {}

func == (lhs: Location, rhs: Location) -> Bool {
    return lhs.x == rhs.x && lhs.y == rhs.y
}