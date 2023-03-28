//
//  VideoProcessor.swift
//  ObjectDetection
//
//  Created by Noujan Fakhri on 3/24/23.
//

import Foundation
import UIKit
import AVFoundation
import Vision

// VideoProcessor class handles video processing, object detection, and processing results.
class VideoProcessor {
    
    private(set) var objectDetections: [VNRecognizedObjectObservation] = []
    
    // Setting up the model
    private let model: VNCoreMLModel
    
    private weak var videoPreviewView: VideoPreviewView?
    
    init(videoPreviewView: VideoPreviewView? = nil) {
        do {
            let modelConfig = MLModelConfiguration()
            guard let coreMLModel = try? YOLOv3FP16(configuration: modelConfig) else {
                fatalError("Failed to load the Core ML model.")
            }
            model = try VNCoreMLModel(for: coreMLModel.model)
        } catch {
            fatalError("Failed to create the VNCoreMLModel: \(error.localizedDescription)")
        }

        self.videoPreviewView = videoPreviewView
    }
    
    // Processes the video and applies the model to each frame
    func processVideo(completion: @escaping ([VNRecognizedObjectObservation], CMSampleBuffer) -> Void) {
        // Load the video file and create an 'AVAsset'
        let videoURL = Bundle.main.url(forResource: "video_1", withExtension: "mp4")!
        let asset = AVAsset(url: videoURL)

        // Set up an 'AVAssetReader' to read the video frames
        var assetReader: AVAssetReader!
        
        do {
            assetReader = try AVAssetReader(asset: asset)
        } catch {
            print("Error creating asset reader: \(error.localizedDescription)")
        }
        
        // Create an 'AVAssetReaderTrackOutput' to read the video track
        let videoTrack = asset.tracks(withMediaType: .video).first!
        let readerOutputSettings: [String: Any] = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        let trackOutput = AVAssetReaderTrackOutput(track: videoTrack, outputSettings: readerOutputSettings)
        assetReader.add(trackOutput)
        
        // Start sending the frames and apply the model to each frame
        assetReader.startReading()
        print("Asset reader started")
        
        while assetReader.status == .reading {
            if let sampleBuffer = trackOutput.copyNextSampleBuffer() {
                if let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
                    detectObjects(pixelBuffer: pixelBuffer) { results in
                        DispatchQueue.main.async {
                            completion(results, sampleBuffer)
                        }
                    }
                }
                CMSampleBufferInvalidate(sampleBuffer)
            }
        }
        
        if assetReader.status == .completed {
            print("Video processing completed")
        } else {
            print("Video processing failed with status: \(assetReader.status.rawValue)")
        }
    }

    // Detects objects in a given pixel buffer using the Core ML model
    func detectObjects(pixelBuffer: CVPixelBuffer, completion: @escaping ([VNRecognizedObjectObservation]) -> Void) {
        
        let request = VNCoreMLRequest(model: model) { (request, error) in
            if let error = error {
                print("Error processing the image: \(error.localizedDescription)")
                return
            }
            
            if let results = request.results as? [VNRecognizedObjectObservation] {
                completion(results)
            }
        }
        
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        
        do {
            try handler.perform([request])
        } catch {
            print("Error performing object detection: \(error.localizedDescription)")
        }
    }
    
    // Calculates the distance between two given points
    func calculateDistanceBetweenPoints(_ point1: CGPoint, _ point2: CGPoint) -> CGFloat {
        let xDistance = point1.x - point2.x
        let yDistance = point1.y - point2.y
        return sqrt(xDistance * xDistance + yDistance * yDistance)
    }
}
