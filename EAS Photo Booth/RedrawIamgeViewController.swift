//
//  RedrawIamgeViewController.swift
//  EAS Photo Booth
//
//  Created by Jim Webb on 5/30/15.
//  Copyright (c) 2015 Jim Webb All rights reserved.
//

import UIKit

class RedrawImageViewController: UIViewController, UIScrollViewDelegate, RedrawImageDataSource  {
    
    var newScreen = EASScreen()
    
//    var redrawImage: RedrawImageView! {
//        didSet {
//         redrawImage.dataSource = self
//        }
//    }
    
    
    func dataForImage() -> [Location]? {
        return drawingPoints
    }
    
     weak var redrawImageContainer: UIScrollView! {
        didSet {
            view.addSubview(redrawImage)
        }
    }
    
//    @IBOutlet var scrollView: UIScrollView! {
//        didSet {
//            view.addSubview(redrawImage)
//        }
//    }
    
    @IBOutlet var redrawImage: RedrawImageView! {
        didSet {
            redrawImage.dataSource = self
        }
    }
    
    
    var drawingPoints = [Location]?()
    
//    var incomingGrid = [[CoOrd]]()
    
    var drawingDirectionsForBlueTooth = String()
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(true)
        
        print ("Incoming to VC: \(drawingPoints!.count)")
//        if incomingGrid.count > 0 {
//            newPath.withinCoordGrid = incomingGrid
//            drawingPoints = newPath.startPathBuilder()
//        }
        print("Coming out of path builder: \(drawingPoints?.count)")
        
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
    }
    
    @IBAction func sendToBluetooth(sender: AnyObject) {
        
        let xMotor = Motor(thisMotorAxis: .x, motionChangeDrift: 0)
        let yMotor = Motor(thisMotorAxis: .y, motionChangeDrift: 0)
        
        //drawingDirectionsForBlueTooth = newPath.createTextDirections(xMotor, yMotor: yMotor)
        print(drawingDirectionsForBlueTooth)
                
        //print("Compressed:")
        //let compressedPath = newPath.createCompressedDirections()
        //print("\(compressedPath)")
        
    }


}
