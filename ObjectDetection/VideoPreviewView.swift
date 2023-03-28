//
//  VideoPreviewView.swift
//  ObjectDetection
//
//  Created by Noujan Fakhri on 3/24/23.
//

import UIKit
import AVFoundation
import Vision

// VideoPreviewView class handles displaying the video and drawing bounding boxes.
class VideoPreviewView: UIView {
    
    private var overlayLayer: CAShapeLayer!
    private var videoLayer: CALayer!
    private var boundingBoxesLayer = CALayer()
    
    private var previousBoundingBoxes: [VNRecognizedObjectObservation] = []
    
    override class var layerClass: AnyClass {
        return AVPlayerLayer.self
    }
    
    var playerLayer: AVPlayerLayer {
        return layer as! AVPlayerLayer
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupOverlayLayer()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        videoLayer.frame = bounds
        overlayLayer.frame = bounds
    }
    
    // Set up the layers for video and bounding boxes
    private func setupOverlayLayer() {
        videoLayer = CALayer()
        videoLayer.contentsGravity = .resizeAspectFill
        layer.addSublayer(videoLayer)
        
        overlayLayer = CAShapeLayer()
        overlayLayer.strokeColor = UIColor.red.cgColor
        overlayLayer.lineWidth = 20
        overlayLayer.fillColor = UIColor.clear.cgColor
        overlayLayer.lineJoin = .round
        overlayLayer.lineDashPattern = [4, 4]
        layer.addSublayer(overlayLayer)
        layer.addSublayer(boundingBoxesLayer)
    }
    
    // Draws bounding boxes for object detections on the video
    func drawBoundingBoxes(_ objectDetections: [VNRecognizedObjectObservation]) {
        DispatchQueue.main.async {
            guard let playerLayer = self.layer as? AVPlayerLayer else {
                fatalError("Invalid layer type")
            }
            
            let videoRect = playerLayer.videoRect
            let videoSize = CGSize(width: videoRect.width, height: videoRect.height)
            
            // Remove any existing sublayers in the boundingBoxesLayer
            self.boundingBoxesLayer.sublayers?.forEach { $0.removeFromSuperlayer() }
            
            for (index, objectDetection) in objectDetections.enumerated() {
                let boundingBox = objectDetection.boundingBox
                let rect = VNImageRectForNormalizedRect(boundingBox, Int(videoSize.height), Int(videoSize.width))
                let convertedRect = CGRect(x: rect.origin.y, y: rect.origin.x, width: rect.height, height: rect.width)
                
                let shapeLayer = CAShapeLayer()
                
                // Check if the object has moved less
                if index < self.previousBoundingBoxes.count {
                    let previousBoundingBox = self.previousBoundingBoxes[index].boundingBox
                    let previousRect = VNImageRectForNormalizedRect(previousBoundingBox, Int(videoSize.height), Int(videoSize.width))
                    let convertedPreviousRect = CGRect(x: previousRect.origin.y, y: previousRect.origin.x, width: previousRect.height, height: previousRect.width)
                    
                    let movementThreshold: CGFloat = 10
                    let deltaX = abs(convertedRect.origin.x - convertedPreviousRect.origin.x)
                    let deltaY = abs(convertedRect.origin.y - convertedPreviousRect.origin.y)
                    
                    if deltaX < movementThreshold && deltaY < movementThreshold {
                        shapeLayer.strokeColor = UIColor.green.cgColor
                    } else {
                        shapeLayer.strokeColor = UIColor.red.cgColor
                    }
                } else {
                    shapeLayer.strokeColor = UIColor.red.cgColor
                }
                
                shapeLayer.lineWidth = 2
                shapeLayer.fillColor = UIColor.clear.cgColor
                shapeLayer.path = UIBezierPath(rect: convertedRect).cgPath
                // Add the shape layer to the boundingBoxesLayer instead of the main layer
                self.boundingBoxesLayer.addSublayer(shapeLayer)
            }
            
            // Update previousBoundingBoxes
            self.previousBoundingBoxes = objectDetections
        }
    }
    
}
