//
//  ChooseImageViewController.swift
//  EAS Photo Booth
//
//  Created by Jim Webb on 1/19/15.
//  Copyright (c) 2015 Jim Webb All rights reserved.
//

import UIKit
import AssetsLibrary
import AudioToolbox

class ChooseImageViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate, UIScrollViewDelegate {
    
    //MARK:  View set up
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        updateEasFrameView()
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        
        if !easDisplay.isHidden {
            easDisplay.removeFromSuperview()
        }
        
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        if !frameHolder.subviews.contains(easDisplay) {
            updateEasFrameView()
            frameHolder.addSubview(easDisplay)
        }
        
    }
    
    override func motionEnded(_ motion: UIEventSubtype, with event: UIEvent?) {
        if motion == .motionShake {
            if redrawImageView?.frame != nil {
                redrawImageView?.removeFromSuperview()
                redrawImageView = nil
            }
            if userImage?.image != nil {
                userImage?.image = nil
            }
            sendToBluetoothButton.isEnabled = false
            captureImageButton.isEnabled = false
            userImageContainer.backgroundColor = UIColor.lightGray
            AudioServicesPlayAlertSound(SystemSoundID(kSystemSoundID_Vibrate))
        }
    }
    
    //MARK:  Outlet and Variable Declarations
    
    var easDisplay: UIView!
    var userImage:  UIImageView? = nil
    var userImageContainer: UIScrollView!
    var redrawImageView: UIImageView? = nil
    var processView = UIActivityIndicatorView(activityIndicatorStyle: UIActivityIndicatorViewStyle.whiteLarge)
    var testScreen = EASScreen()
    
    @IBOutlet weak var frameHolder: UIScrollView!
    @IBOutlet weak var opacityLabel: UILabel!
    @IBOutlet weak var sendToBluetoothButton: UIButton!
    @IBOutlet weak var captureImageButton: UIButton!
    @IBOutlet weak var chooseImageButton: UIButton!
    @IBOutlet weak var opacitySlider: UISlider! {
        didSet {
            updateSliderValue(opacitySlider)
        }
    }
    
    @IBAction func updateSliderValue(_ sender: UISlider!){
            opacityLabel.text = "Opacity: \(Int(sender.value * 100))%"
            if self.redrawImageView?.frame != nil {
                redrawImageView!.removeFromSuperview()
                sendToBluetoothButton.isEnabled = false
            }
    }
    
    //MARK:  Create EAS Frame View
    
    func updateEasFrameView() {
        
        let frameHolderSize = frameHolder.bounds
        
        let testScreenMathWidth = CGFloat(testScreen.maxWidth) + 0.000
        let testScreenMathHeight = CGFloat(testScreen.maxHeight) + 0.000
        let heightRatio = testScreenMathHeight / testScreenMathWidth
        var frameSize = CGRect()
        
        if frameHolderSize.width < frameHolderSize.height {
            frameSize = CGRect(
                x: frameHolderSize.minX,
                y: frameHolderSize.midY - (frameHolderSize.width * heightRatio / 2),
                width: frameHolderSize.width,
                height: frameHolderSize.width * heightRatio)
        } else {
            frameSize = CGRect(
                x: frameHolderSize.midX - (frameHolderSize.height * (1 / heightRatio) / 2),
                y: frameHolderSize.minY,
                width: frameHolderSize.height * (1 / heightRatio),
                height: frameHolderSize.height)
        }
        
        let easFrame = UIView(frame: frameSize)
        easFrame.backgroundColor = UIColor.red
        easFrame.layer.shadowColor = UIColor.black.cgColor
        easFrame.layer.shadowOpacity = 0.5
        easFrame.layer.shadowOffset = CGSize(width: 2.0, height: 2.0)
        easFrame.layer.shadowRadius = 5.0
        easFrame.layer.cornerRadius = 10.0
        
        let rightKnob = UIView(frame: CGRect(
            x: easFrame.bounds.maxX - (easFrame.bounds.width * 0.12),
            y: easFrame.bounds.maxY - (easFrame.bounds.width * 0.12),
            width: easFrame.bounds.width * 0.1,
            height: easFrame.bounds.width * 0.1))
        rightKnob.backgroundColor = UIColor.white
        rightKnob.layer.cornerRadius = rightKnob.frame.width / 2
        rightKnob.layer.shadowColor = UIColor.black.cgColor
        rightKnob.layer.shadowOffset = CGSize.zero
        rightKnob.layer.shadowRadius = 2.0
        rightKnob.layer.shadowOpacity = 0.5
        
        let leftKnob = UIView(frame: CGRect(
            x: easFrame.bounds.minX + (easFrame.bounds.width * 0.02),
            y: easFrame.bounds.maxY - (easFrame.bounds.width * 0.12),
            width: easFrame.bounds.width * 0.1,
            height: easFrame.bounds.width * 0.1))
        leftKnob.backgroundColor = UIColor.white
        leftKnob.layer.cornerRadius = leftKnob.frame.width / 2
        leftKnob.layer.shadowColor = UIColor.black.cgColor
        leftKnob.layer.shadowOffset = CGSize.zero
        leftKnob.layer.shadowRadius = 2.0
        leftKnob.layer.shadowOpacity = 0.5
        
        let easLogoImage = UIImage(named: "etch_a_sketch_logo_sans_background.png")
        let logoHeight = easLogoImage!.size.height + 0.000
        let logoWidth = easLogoImage!.size.width + 0.000
        let logoHeightRatio = logoWidth / logoHeight

        let easLogo = UIImageView(image: easLogoImage)
        easLogo.frame = CGRect(
            x: easFrame.bounds.midX - (easFrame.bounds.height * 0.15 * logoHeightRatio / 2),
            y: easFrame.bounds.minY,
            width: easFrame.bounds.height * 0.15 * logoHeightRatio,
            height: easFrame.bounds.height * 0.15)
        easLogo.tintColor = UIColor.clear
        
        self.userImageContainer = UIScrollView(frame: CGRect(
            x: easFrame.bounds.midX - ((rightKnob.frame.minY - easLogo.frame.maxY) * (1 / heightRatio) / 2),
            y: easLogo.frame.maxY,
            width: (rightKnob.frame.minY - easLogo.frame.maxY) * (1 / heightRatio),
            height: rightKnob.frame.minY - easLogo.frame.maxY ))
        userImageContainer.backgroundColor = UIColor.lightGray
        
        
        easFrame.addSubview(rightKnob)
        easFrame.addSubview(leftKnob)
        easFrame.addSubview(easLogo)
        easFrame.addSubview(userImageContainer)
        
        if userImage?.image != nil {
            
            userImageContainer.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            userImageContainer.backgroundColor = UIColor.white
            userImageContainer.contentSize = userImage!.bounds.size
            userImageContainer.addSubview(userImage!)

            userImageContainer.delegate = self
            
            setScrollViewParameters(userImageContainer.bounds.size)
        }
        
        if redrawImageView?.frame != nil {
            self.redrawImageView!.contentMode = .scaleAspectFit
            self.redrawImageView!.frame = userImageContainer.frame
            easFrame.addSubview(redrawImageView!)
        }
        
        self.easDisplay = easFrame
        
    }
    
    //MARK:  Add Image to frame
    
    func addPhotoToFrame(_ photo: UIImage) {
        userImageContainer.subviews.forEach({ $0.removeFromSuperview() })
        
        self.userImage = UIImageView(image: photo)
        userImageContainer.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        userImageContainer.backgroundColor = UIColor.white
        userImageContainer.contentSize = userImage!.bounds.size
        userImageContainer.addSubview(userImage!)
        
        userImageContainer.delegate = self
        
        setScrollViewParameters(userImageContainer.bounds.size)

    }
    
    func recenterImage() {
        if let imageSize = self.userImage?.frame.size {
            let scrollViewSize = userImageContainer.bounds.size
            let horizontalSpace = imageSize.width < scrollViewSize.width ? (scrollViewSize.width - imageSize.width) / 2 : 0
            let verticleSpace = imageSize.height < scrollViewSize.height ? (scrollViewSize.height - imageSize.height) / 2 : 0
            userImageContainer.contentInset = UIEdgeInsets(top: verticleSpace, left: horizontalSpace, bottom: verticleSpace, right: horizontalSpace)
        }
    }
    
    func setScrollViewParameters(_ scrollViewSize: CGSize) {
        if let imageSize = userImage?.bounds.size {
        
            let widthScale = scrollViewSize.width / imageSize.width
            let heightScale = scrollViewSize.height / imageSize.height
            let minScale = min(widthScale, heightScale)
        
            userImageContainer.minimumZoomScale = minScale
            userImageContainer.maximumZoomScale = 3.0
            userImageContainer.zoomScale = minScale
        }
    }
    
    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        recenterImage()
    }
    
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return userImage
    }
    
    //MARK:  Send to Bluetooth

    @IBAction func sendToBluetoothButton(_ sender: AnyObject) {
        
        DispatchQueue.global(qos: DispatchQoS.QoSClass.default).async {
            
            DispatchQueue.main.async(execute: { () -> Void in
                self.processView.backgroundColor = UIColor.clear
                self.processView.frame = self.userImageContainer.frame
                self.easDisplay.addSubview(self.processView)
                self.processView.startAnimating()
            })
        
        
            let xMotor = Motor(thisMotorAxis: .x, motionChangeDrift: 13)
            let yMotor = Motor(thisMotorAxis: .y, motionChangeDrift: 13)
            let textPath = CreateTextPath(pathOfLocations: self.grid)
            var textDirections = "X"
            textDirections += textPath.createTextDirections(xMotor, yMotor: yMotor)
            textDirections += "O"
            UIPasteboard.general.string = textDirections
            
            DispatchQueue.main.async(execute: { () -> Void in

                self.processView.stopAnimating()
                self.processView.removeFromSuperview()
                
            })
        
        }
        
        let alert = UIAlertController(title: "Ready!", message: "Open Adafruit Connector and paste directions into text message", preferredStyle: UIAlertControllerStyle.alert)
        alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: nil))
        let savePictureAction: UIAlertAction = UIAlertAction(title: "Save Image", style: .default) { action -> Void in
            UIImageWriteToSavedPhotosAlbum(UIImage(view: self.easDisplay), nil, nil, nil)
            let savedToPhotoAlert = UIAlertController(title: "Saved", message: "Image saved to your Photo Roll", preferredStyle: UIAlertControllerStyle.alert)
            savedToPhotoAlert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: nil))
            self.present(savedToPhotoAlert, animated: true, completion: nil)
        }
        alert.addAction(savePictureAction)
        self.present(alert, animated: true, completion: nil)
        
    }

    //MARK:  Capture Image
    
    var grid = [Location]() {
        didSet{
            sendToBluetoothButton.isEnabled = grid.count > 0 ? true : false
            sendToBluetoothButton.setNeedsDisplay()
        }
    }
    
    @IBAction func createImageGrid(_ sender: AnyObject) {
        
        if redrawImageView?.frame != nil {
            redrawImageView!.removeFromSuperview()
        }
        
        var croppedImage: UIImage?
        
        DispatchQueue.global(qos: DispatchQoS.QoSClass.default).async {
            
            DispatchQueue.main.async(execute: { () -> Void in
                self.processView.backgroundColor = UIColor.clear
                self.processView.frame = self.userImageContainer.frame
                self.easDisplay.addSubview(self.processView)
                self.processView.startAnimating()
            })
        
            if let imageToEdit = self.userImage?.image?.cgImage {
                let scale = 1 / self.userImageContainer.zoomScale
                let visibleRect = CGRect(x: self.userImageContainer.contentOffset.x * scale,
                    y: self.userImageContainer.contentOffset.y * scale,
                    width: self.userImageContainer.bounds.size.width * scale,
                    height: self.userImageContainer.bounds.size.height * scale)
                let imageRef: CGImage = imageToEdit.cropping(to: visibleRect)!
                croppedImage = UIImage(cgImage: imageRef)
            }
        
            if let resizedImage = croppedImage?.resizedImageWithBounds(self.testScreen.size()) {
                let imagePath = ImageCreatePath(imageToConvert: resizedImage, atOpactiy: self.opacitySlider.value)
                let returnedPath = imagePath.buildImagePath()
                if returnedPath != nil {
                    self.grid = returnedPath!
                }
            }
            
            DispatchQueue.main.async(execute: { () -> Void in
                
                self.redrawImageView?.contentMode = .scaleAspectFit
                self.redrawImageView = UIImageView(image: self.createRedrawnImage(self.testScreen.size()))
                self.redrawImageView!.frame = self.userImageContainer.frame
                self.easDisplay.addSubview(self.redrawImageView!)
                
                self.processView.stopAnimating()
                self.processView.removeFromSuperview()
                
            })
            
        }
        
    }
    
    func createRedrawnImage(_ size: CGSize) -> UIImage {

        let bounds = CGRect(origin: CGPoint.zero, size: size)
        let opaque = false
        let scale: CGFloat = 0
        UIGraphicsBeginImageContextWithOptions(size, opaque, scale)
        let context = UIGraphicsGetCurrentContext()
        
        context?.setFillColor(UIColor.lightGray.cgColor)
        context?.fill(bounds)
        
        context?.setLineWidth(1.0)
        context?.setStrokeColor(UIColor.darkGray.cgColor)
        context?.move(to: CGPoint(x: CGFloat(grid[0].x), y: CGFloat(grid[0].y)))
        
        for i in 1..<grid.count {
            context?.addLine(to: CGPoint(x: CGFloat(grid[i].x), y: CGFloat(grid[i].y)))
        }
        
        context?.strokePath()
        
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image!
        
    }
    
    //MARK: Update Photos  {
    
    func useCamera() {
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            let picker = UIImagePickerController()
            picker.allowsEditing = false
            picker.sourceType = .camera
            picker.delegate = self

            self.present(picker, animated: true, completion: nil)
        
        }
    }
    
    func usePhotoLibrary() {
        if UIImagePickerController.isSourceTypeAvailable(.photoLibrary) {
            let picker = UIImagePickerController()
            picker.allowsEditing = false
            picker.sourceType = .photoLibrary
            picker.delegate = self

            self.present(picker, animated: true, completion: nil)
        
        }
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        
        if self.redrawImageView?.frame != nil {
                redrawImageView!.removeFromSuperview()
                sendToBluetoothButton.isEnabled = false
        }
        if self.userImage?.image != nil {
            userImage = nil
        }
        grid.removeAll()
        
        let image = info[UIImagePickerControllerOriginalImage] as? UIImage
        if image == nil {
            captureImageButton.isEnabled = false
        } else {
            captureImageButton.isEnabled = true
            addPhotoToFrame(image!)
        }
        
        self.dismiss(animated: true, completion: nil)
    
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        self.dismiss(animated: true, completion: nil)
    }
    
    @IBAction func pickImage(_ sender: AnyObject) {
        let pickImageSheet: UIAlertController = UIAlertController(title: nil, message: "Choose an Image Source", preferredStyle: .actionSheet)
        
        let cancelAction: UIAlertAction = UIAlertAction(title: "Cancel", style: .cancel) { action -> Void in
        }
        
        let takePictureAction: UIAlertAction = UIAlertAction(title: "Take Picture", style: .default) { action -> Void in
            self.useCamera()
        }
        
        let choosePictureAction: UIAlertAction = UIAlertAction(title: "Choose From Photo Library", style: .default) { action -> Void in
            self.usePhotoLibrary()
        }
        
        pickImageSheet.addAction(cancelAction)
        
        pickImageSheet.addAction(takePictureAction)
        
        pickImageSheet.addAction(choosePictureAction)
        
        pickImageSheet.popoverPresentationController?.sourceView = sender as? UIView;

        self.present(pickImageSheet, animated: true, completion: nil)

    }

}

//MARK: UIImage Extensions for Processing

extension UIImage {
    
    func resizedImageWithBounds(_ bounds: CGSize) -> UIImage {
        let horizontalRatio = bounds.width / size.width
        let verticalRatio = bounds.height / size.height
        let ratio = min(horizontalRatio, verticalRatio)
        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
        
        UIGraphicsBeginImageContext(newSize)
        draw(in: CGRect(origin: CGPoint.zero, size: newSize))
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return newImage!
    }
    
    convenience init(view: UIView) {
        UIGraphicsBeginImageContextWithOptions(view.bounds.size, true, 0)
        let context = UIGraphicsGetCurrentContext()
        context?.setFillColor(UIColor.white.cgColor)
        context?.fill(view.bounds)
        view.drawHierarchy(in: view.bounds, afterScreenUpdates: true)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        self.init(cgImage: image!.cgImage!)
        
    }
    
}
