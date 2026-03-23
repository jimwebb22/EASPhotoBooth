//
//  EASScreen.swift
//  EAS Photo Booth
//
//  Created by Jim Webb on 7/31/15.
//  Copyright (c) 2015 Jim Webb All rights reserved.
//

import Foundation
import UIKit

struct EASScreen {
    
    let maxWidth = 480
    let maxHeight = 320
    let minWidth = 0
    let minHeight = 0
    
    func size() -> CGSize {
        return CGSize(width: maxWidth, height: maxHeight)
    }
    
}
