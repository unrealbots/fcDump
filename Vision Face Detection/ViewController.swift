//
//  ViewController.swift
//  Vision Face Detection
//
//  Created by Pawel Chmiel on 21.06.2017.
//  Copyright © 2017 Droids On Roids. All rights reserved.
//

import UIKit
import AVFoundation
import Vision

final class ViewController: UIViewController {
    fileprivate var state: Bool = false
    
    fileprivate var noseLayer = CALayer()
    fileprivate var leftEarLayer = CALayer()
    fileprivate var rightEarLayer = CALayer()
    
    var filterView: UIView? = nil
    
    var session: AVCaptureSession?
    let shapeLayer = CAShapeLayer()
    
    let faceDetection = VNDetectFaceRectanglesRequest()
    let faceLandmarks = VNDetectFaceLandmarksRequest()
    let faceLandmarksDetectionRequest = VNSequenceRequestHandler()
    let faceDetectionRequest = VNSequenceRequestHandler()
    
    lazy var previewLayer: AVCaptureVideoPreviewLayer? = {
        guard let session = self.session else { return nil }
        
        var previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        
        return previewLayer
    }()
    
    var frontCamera: AVCaptureDevice? = {
        return AVCaptureDevice.default(AVCaptureDevice.DeviceType.builtInWideAngleCamera, for: AVMediaType.video, position: .front)
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        
        sessionPrepare()
        session?.startRunning()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.frame
        noseLayer.frame = view.frame
        leftEarLayer.frame = view.frame
        rightEarLayer.frame = view.frame
        shapeLayer.frame = view.frame
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard let previewLayer = previewLayer else { return }
        view.layer.addSublayer(previewLayer)
        
        shapeLayer.strokeColor = UIColor.red.cgColor
        shapeLayer.lineWidth = 2.0
        
        //needs to filp coordinate system for Vision
        shapeLayer.setAffineTransform(CGAffineTransform(scaleX: -1, y: -1))
        
        filterView = UIView(frame: self.view.frame)
        filterView?.layer.addSublayer(noseLayer)
        filterView?.layer.addSublayer(leftEarLayer)
        filterView?.layer.addSublayer(rightEarLayer)
        filterView?.transform = CGAffineTransform(scaleX: -1, y: -1)
        self.view.addSubview(filterView!)
        
        view.layer.addSublayer(shapeLayer)
    }
    
    func sessionPrepare() {
        session = AVCaptureSession()
        guard let session = session, let captureDevice = frontCamera else { return }
        
        do {
            let deviceInput = try AVCaptureDeviceInput(device: captureDevice)
            session.beginConfiguration()
            
            if session.canAddInput(deviceInput) {
                session.addInput(deviceInput)
            }
            
            let output = AVCaptureVideoDataOutput()
            output.videoSettings = [
                String(kCVPixelBufferPixelFormatTypeKey) : Int(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)
            ]
            
            output.alwaysDiscardsLateVideoFrames = true
            
            if session.canAddOutput(output) {
                session.addOutput(output)
            }
            
            session.commitConfiguration()
            let queue = DispatchQueue(label: "output.queue")
            output.setSampleBufferDelegate(self, queue: queue)
            print("setup delegate")
        } catch {
            print("can't setup session")
        }
    }
}

extension ViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        
        let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
        
        let attachments = CMCopyDictionaryOfAttachments(allocator: kCFAllocatorDefault, target: sampleBuffer, attachmentMode: kCMAttachmentMode_ShouldPropagate)
        let ciImage = CIImage(cvImageBuffer: pixelBuffer!, options: attachments as! [CIImageOption : Any]?)
        
        //leftMirrored for front camera
        let ciImageWithOrientation = ciImage.oriented(forExifOrientation: Int32(UIImage.Orientation.leftMirrored.rawValue))
        
        detectFace(on: ciImageWithOrientation)
    }
}

extension ViewController {
    
    func detectFace(on image: CIImage) {
        try? faceDetectionRequest.perform([faceDetection], on: image)
        if let results = faceDetection.results as? [VNFaceObservation] {
            if !results.isEmpty {
                if state == false {
                    
                    DispatchQueue.main.async {
                        self.view.addSubview(self.filterView!)
                        self.state = true
                    }
                }
                
                faceLandmarks.inputFaceObservations = results
                detectLandmarks(on: image)
                
                DispatchQueue.main.async {
                    self.shapeLayer.sublayers?.removeAll()
                    self.noseLayer.sublayers?.removeAll()
                    self.leftEarLayer.sublayers?.removeAll()
                    self.rightEarLayer.sublayers?.removeAll()
                }
            } else{
                DispatchQueue.main.async {
                    self.filterView?.removeFromSuperview()
                    self.state = false
                }
            }
        }
    }
    
    func detectLandmarks(on image: CIImage) {
        try? faceLandmarksDetectionRequest.perform([faceLandmarks], on: image)
        if let landmarksResults = faceLandmarks.results as? [VNFaceObservation] {
            for observation in landmarksResults {
                DispatchQueue.main.async {
                    if let boundingBox = self.faceLandmarks.inputFaceObservations?.first?.boundingBox {
                        let faceBoundingBox = boundingBox.scaled(to: self.view.bounds.size)
                        
                        /*
                         let faceContour = observation.landmarks?.faceContour
                         self.convertPointsForFace(faceContour, faceBoundingBox)
                         
                         let leftEye = observation.landmarks?.leftEye
                         self.convertPointsForFace(leftEye, faceBoundingBox)
                         
                         let rightEye = observation.landmarks?.rightEye
                         self.convertPointsForFace(rightEye, faceBoundingBox)
                         */
                        
                        let nose = observation.landmarks?.medianLine
                        self.convertPointsForFace(nose, faceBoundingBox, type: "nose")
                        
                        let leftEyebrow = observation.landmarks?.leftEyebrow
                        self.convertPointsForFace(leftEyebrow, faceBoundingBox, type: "rightEar")
                        
                        let rightEyebrow = observation.landmarks?.rightEyebrow
                        self.convertPointsForFace(rightEyebrow, faceBoundingBox, type: "leftEar")
                        
                        /*
                         let noseCrest = observation.landmarks?.noseCrest
                         self.convertPointsForFace(noseCrest, faceBoundingBox)
                         
                         let outerLips = observation.landmarks?.outerLips
                         self.convertPointsForFace(outerLips, faceBoundingBox)
                        */
                        
                    }
                }
            }
        }
    }
    
    func convertPointsForFace(_ landmark: VNFaceLandmarkRegion2D?, _ boundingBox: CGRect, type: String) {
        if let points = landmark?.normalizedPoints {
            let convertedPoints = convert(points)
            
            /* UIImageView Bat
             filterView!.subviews.forEach{
             $0.removeFromSuperview()
             }
             let imageview = UIImageView(frame: boundingBox)
             imageview.image = #imageLiteral(resourceName: "bat")
             filterView!.addSubview(imageview)
             */
            
            let faceLandmarkPoints = convertedPoints.map { (point: (x: CGFloat, y: CGFloat)) -> (x: CGFloat, y: CGFloat) in
                let pointX = point.x * boundingBox.width + boundingBox.origin.x
                let pointY = point.y * boundingBox.height + boundingBox.origin.y
                return (x: pointX, y: pointY)
            }
            
            DispatchQueue.global(qos: .background).async {
                DispatchQueue.main.async {
                    self.draw(points: faceLandmarkPoints, type: type, size: boundingBox)
                }
            }
        }
    }
    
    func convert(_ points: [CGPoint]) -> [(x: CGFloat, y: CGFloat)] {
        var convertedPoints: [(x: CGFloat, y: CGFloat)] = []
        points.forEach { convertedPoints.append((CGFloat($0.x), CGFloat($0.y))) }
        return convertedPoints
    }
    
    func draw(points: [(x: CGFloat, y: CGFloat)], type: String, size: CGRect) {
        
        /*
         let newLayer = CAShapeLayer()
         newLayer.strokeColor = UIColor.red.cgColor
         newLayer.lineWidth = 12.0
         
         let path = UIBezierPath()
         path.move(to: CGPoint(x: points[0].x, y: points[0].y))
         for i in 0..<points.count - 1 {
         let point = CGPoint(x: points[i].x, y: points[i].y)
         path.addLine(to: point)
         path.move(to: point)
         }
         path.addLine(to: CGPoint(x: points[0].x, y: points[0].y))
         newLayer.path = path.cgPath
         */
        
        
        if type == "nose" {
            let noseImage = #imageLiteral(resourceName: "nose")
            let filter = CIFilter(name: "CISepiaTone")
            filter?.setValue(CIImage(image: noseImage), forKey: kCIInputImageKey)
            filter?.setValue(0.8, forKey: kCIInputIntensityKey)
            let ctx = CIContext(options:nil)
            let cgImage = ctx.createCGImage(filter!.outputImage!, from: filter!.outputImage!.extent)
            
            
            let ratio = size.width
            let x:CGFloat = ratio / 400
            let h = size.height / 10
            noseLayer.position = CGPoint(x: points[points.count/2].x, y: points[points.count/2].y + h)
            noseLayer.transform = CATransform3DMakeScale(-x, -x, -1)
            
            noseLayer.contents = cgImage
            noseLayer.contentsGravity = .center
            noseLayer.isGeometryFlipped = true
        }
        
        if type == "leftEar" {
            let leftEarImage = #imageLiteral(resourceName: "leftEar")
            let filter = CIFilter(name: "CISepiaTone")
            filter?.setValue(CIImage(image: leftEarImage), forKey: kCIInputImageKey)
            filter?.setValue(0.8, forKey: kCIInputIntensityKey)
            let ctx = CIContext(options:nil)
            let cgImage = ctx.createCGImage(filter!.outputImage!, from: filter!.outputImage!.extent)
            
            let ratio = size.width
            let h = size.height / 2
            let x:CGFloat = ratio / 350
            
            leftEarLayer.position = CGPoint(x: points.last!.x + 10, y: points.last!.y + h)
            leftEarLayer.transform = CATransform3DMakeScale(-x, -x, -1)
            
            leftEarLayer.contents = cgImage
            leftEarLayer.contentsGravity = .center
            leftEarLayer.isGeometryFlipped = true
        }
        
        if type == "rightEar" {
            let rightEarImage = #imageLiteral(resourceName: "rightEar")
            let filter = CIFilter(name: "CISepiaTone")
            filter?.setValue(CIImage(image: rightEarImage), forKey: kCIInputImageKey)
            filter?.setValue(0.8, forKey: kCIInputIntensityKey)
            let ctx = CIContext(options:nil)
            let cgImage = ctx.createCGImage(filter!.outputImage!, from: filter!.outputImage!.extent)
            
            let ratio = size.width
            let x:CGFloat = ratio / 375
            let h = size.height / 2
            rightEarLayer.position = CGPoint(x: points.first!.x - 10, y: points.first!.y + h)
            rightEarLayer.transform = CATransform3DMakeScale(-x, -x, -1)
            
            rightEarLayer.contents = cgImage
            rightEarLayer.contentsGravity = .center
            rightEarLayer.isGeometryFlipped = true
        }
        
        //*CALayer Bat
        //shapeLayer.addSublayer(newLayer)
    }
}
