//
//  ViewController.swift
//  ObjectDetection
//
//  Created by Noujan Fakhri on 3/24/23.
//

import UIKit
import Vision
import AVFoundation

class ViewController: UIViewController {
    
    private var videoProcessor: VideoProcessor!
    
    private var player: AVPlayer!
    
    private var playerItemObservation: NSKeyValueObservation?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Initialize the VideoProcessor
        videoProcessor = VideoProcessor()
    }
    
    // Process video button tap action
    @IBAction func processVideoButtonTapped(_ sender: UIButton) {
        print("Processing video...")
        playVideo()
    }
    
    @IBOutlet weak var resultLabel: UILabel!
    
    @IBOutlet weak var videoPreviewView: VideoPreviewView!
    
    // Play video and apply the VideoProcessor to process the video frames
    private func playVideo() {
        guard let videoURL = Bundle.main.url(forResource: "video_1", withExtension: "mp4") else {
            print("Video not found")
            return
        }
        
        player = AVPlayer(url: videoURL)
        videoPreviewView.playerLayer.player = player
        videoPreviewView.playerLayer.videoGravity = .resizeAspectFill
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerDidFinishPlaying),
            name: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem
        )
        
        playerItemObservation = player.currentItem?.observe(\.status, options: [.new]) { [weak self] item, change in
            guard let self = self, item.status == .readyToPlay else { return }
            self.player.play()
            
            DispatchQueue.global(qos: .userInitiated).async {
                self.videoProcessor.processVideo { (objectDetections: [VNRecognizedObjectObservation], _: CMSampleBuffer) in
                    // Update the UI with the object detections
                    DispatchQueue.main.async {
                        self.videoPreviewView.drawBoundingBoxes(objectDetections)
                        let filteredObjects = objectDetections.filter { $0.confidence > 0.8 }
                        print("Filtered objects: \(filteredObjects)")
                        let objectDescriptions = filteredObjects.map { object in
                            "\(object.labels.first!.identifier): \(object.confidence)"
                        }
                        print("Object descriptions: \(objectDescriptions)")
                        self.resultLabel.text = "Detected objects: \(objectDescriptions.joined(separator: ", "))"
                    }
                }
            }
        }
    }
    
    // Callback when the video finishes playing
    @objc private func playerDidFinishPlaying(_ notification: Notification) {
        print("Video finished playing")
        if let playerItem = notification.object as? AVPlayerItem, let error = playerItem.error {
            print("Error while playing video: \(error.localizedDescription)")
        }
    }
    
    // Helper function to fix the video orientation for display
    private func fixedVideoOrientationComposition(asset: AVAsset) -> AVMutableVideoComposition {
        let videoTrack = asset.tracks(withMediaType: .video).first!
        let size = videoTrack.naturalSize
        let preferredTransform = videoTrack.preferredTransform
        
        let composition = AVMutableVideoComposition()
        composition.renderSize = CGSize(width: size.width, height: size.height)
        composition.frameDuration = CMTimeMake(value: 1, timescale: 30)
        
        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRange(start: .zero, duration: asset.duration)
        
        let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack)
        layerInstruction.setTransform(preferredTransform, at: .zero)
        
        instruction.layerInstructions = [layerInstruction]
        composition.instructions = [instruction]
        
        return composition
    }
}


