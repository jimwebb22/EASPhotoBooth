//
//  RedrawImage.swift
//  EAS Photo Booth
//
//  Created by Jim Webb on 5/29/15.
//  Copyright (c) 2015 Jim Webb All rights reserved.
//

import UIKit

protocol RedrawImageDataSource: class {
    func dataForImage() -> ([Location]?)
}


@IBDesignable class RedrawImageView: UIView {
    
    weak var dataSource: RedrawImageDataSource?
    let aEASScreen = EASScreen()
    
    override func drawRect(rect: CGRect) {
        
        if let drawingPoints = dataSource?.dataForImage() {
        
            if !drawingPoints.isEmpty {
                print("number of points in UI: \(drawingPoints.count)")
                print("Size of UIView: \(self.bounds.size)")
                
                self.backgroundColor = UIColor.lightGrayColor()
                let context = UIGraphicsGetCurrentContext()
                
                CGContextSetLineWidth(context, 1.0)
                CGContextSetStrokeColorWithColor(context, UIColor.darkGrayColor().CGColor)
                CGContextMoveToPoint(context, CGFloat(drawingPoints[0].x), CGFloat(drawingPoints[0].y))
        
                for i in 1..<drawingPoints.count {
                    CGContextAddLineToPoint(context, CGFloat(drawingPoints[i].x), CGFloat(drawingPoints[i].y))
                }
                
                CGContextStrokePath(context)
                UIGraphicsEndImageContext()
                
            }
        }
    }

}




