//
//  ViewController.swift
//  ObjectDetectionYOLO
//
//  Created by Andi Xu on 12/22/21.
//

import UIKit
import Vision
import CoreMedia
import AVFoundation

class ViewController: UIViewController, VideoCaptureDelegate {
    
    
    
    @IBOutlet weak var videoPreview: UIView!
    
    @IBOutlet weak var boxesView: DrawingBoundingBoxView!
    
    let objectDectectionModel = YOLOv3()
    
    var request: VNCoreMLRequest?
    var visionModel: VNCoreMLModel?
    var isInferencing = false
    var videoCapture: VideoCapture!
    let semaphore = DispatchSemaphore(value: 1)
    var lastExecution = Date()
    var predictions: [VNRecognizedObjectObservation] = []
    var requiredItem: Set<String> = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.boxesView.requiredItem=self.requiredItem
        // setup the model
        setUpModel()
        
        // setup camera
        setUpCamera()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.videoCapture.start()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.videoCapture.stop()
    }
    
    // MARK: - Setup Core ML
    func setUpModel() {
        if let visionModel = try? VNCoreMLModel(for: objectDectectionModel.model) {
            self.visionModel = visionModel
            request = VNCoreMLRequest(model: visionModel, completionHandler: visionRequestDidComplete)
            request?.imageCropAndScaleOption = .scaleFill
        } else {
            fatalError("fail to create vision model")
        }
    }

    // MARK: - SetUp Video
    func setUpCamera() {
        videoCapture = VideoCapture()
        videoCapture.delegate = self
        videoCapture.fps = 30
        videoCapture.setUp(sessionPreset: .vga640x480) { success in
            
            if success {
                // add preview view on the layer
                if let previewLayer = self.videoCapture.previewLayer {
                    self.videoPreview.layer.addSublayer(previewLayer)
                    self.resizePreviewLayer()
                }
                
                // start video preview when setup is done
                self.videoCapture.start()
            }
        }
        
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        resizePreviewLayer()
    }
    
    func resizePreviewLayer() {
        videoCapture.previewLayer?.frame = videoPreview.bounds
    }
    


}


extension ViewController {
    func predictUsingVision(pixelBuffer: CVPixelBuffer) {
        guard let request = request else { fatalError() }
        self.semaphore.wait()
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer)
        try? handler.perform([request])
    }
    
    // MARK: - Post-processing
    func visionRequestDidComplete(request: VNRequest, error: Error?) {
       
       
        if let predictions = request.results as? [VNRecognizedObjectObservation] {
            self.predictions = predictions
            print(predictions)
            DispatchQueue.main.async {
                self.boxesView.predictedObjects = predictions
                self.isInferencing = false
                
                
                
            }
        } else {
            // end of measure
            
            
            self.isInferencing = false
        }
        self.semaphore.signal()
    }
    
    func videoCapture(_ capture: VideoCapture, didCaptureVideoFrame pixelBuffer: CVPixelBuffer?, timestamp: CMTime) {
        if !self.isInferencing, let pixelBuffer = pixelBuffer {
            self.isInferencing = true
            
            // predict!
            self.predictUsingVision(pixelBuffer: pixelBuffer)
        }
    }
    
    
}
