//
//  ViewController.swift
//  PoseEstimation-CoreML
//
//  Created by GwakDoyoung on 05/07/2018.
//  Copyright © 2018 tucan9389. All rights reserved.
//

import UIKit
import Vision
import CoreMedia
import os.signpost

class JointViewController: UIViewController {
    
    let refreshLog = OSLog(subsystem: "com.tucan9389.PoseEstimation-CoreML", category: "InferenceOperations")
    
    public typealias DetectObjectsCompletion = ([PredictedPoint?]?, Error?) -> Void
    
    // MARK: - UI Properties
    @IBOutlet weak var videoPreview: UIView!
    @IBOutlet weak var jointView: DrawingJointView!
    
    @IBOutlet weak var recordButton: UIButton!
    @IBOutlet weak var redoButton: UIButton!
    @IBOutlet weak var finishButton: UIButton!
    
    // MARK: - Performance Measurement Property
    private let 👨‍🔧 = 📏()
    var isInferencing = false
    
    // MARK: - AV Property
    var videoCapture: VideoCapture!
    
    // MARK: - ML Properties
    // Core ML model
    typealias EstimationModel = model_cpm
    
    // Preprocess and Inference
    var request: VNCoreMLRequest?
    var visionModel: VNCoreMLModel?
    
    // Postprocess
    var postProcessor: HeatmapPostProcessor = HeatmapPostProcessor()
    var mvfilters: [MovingAverageFilter] = []
    
    // Inference Result Data
    private var tableData: [PredictedPoint?] = []
    
    
    var recordButtonTransparent = false
    var timer = Timer()
    var timestamp: Float = 0.0
    var latestPredictions: [Int:(CGFloat,CGFloat)?] = [:]
    var predictionsWTimestamp: [Float:[Int:(CGFloat, CGFloat)?]] = [:]
    var isRecording = false{
        didSet{
            if isRecording{
                flipButtons()
                timer = Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(recordPredictions), userInfo: nil, repeats: true)
            }else{
                flipButtons()
            }
        }
    }
    
    @IBAction func recordButtonClicked(_ sender: Any) {
        isRecording = true
    }
    
    @IBAction func redoButtonClicked(_ sender: Any) {
        timer.invalidate()
        predictionsWTimestamp = [:]
        isRecording = false
    }
    
    @objc func recordPredictions(){
        predictionsWTimestamp[timestamp] = latestPredictions
        timestamp += 0.1
    }
    
    func flipButtons(){
        recordButtonTransparent = !recordButtonTransparent
        if recordButtonTransparent{
            recordButton.alpha = 0
            redoButton.alpha = 1.0
            finishButton.alpha = 1.0
        }else{
            recordButton.alpha = 1.0
            redoButton.alpha = 0
            finishButton.alpha = 0
        }
    }
    
    
    
    
    // MARK: - View Controller Life Cycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        redoButton.alpha = 0
        finishButton.alpha = 0
        
        // setup the model
        setUpModel()
        
        // setup camera
        setUpCamera()
        
        // setup delegate for performance measurement
        👨‍🔧.delegate = self
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
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
        if let visionModel = try? VNCoreMLModel(for: EstimationModel().model) {
            self.visionModel = visionModel
            request = VNCoreMLRequest(model: visionModel, completionHandler: visionRequestDidComplete)
            request?.imageCropAndScaleOption = .scaleFill
        } else {
            fatalError("cannot load the ml model")
        }
    }
    
    // MARK: - SetUp Video
    func setUpCamera() {
        videoCapture = VideoCapture()
        videoCapture.delegate = self
        videoCapture.fps = 30
        videoCapture.setUp(sessionPreset: .hd1920x1080) { success in
            
            if success {
                if let previewLayer = self.videoCapture.previewLayer {
                    DispatchQueue.main.async {
                        self.videoPreview.layer.addSublayer(previewLayer)
                        self.resizePreviewLayer()
                    }
                }
                
                // start video preview when setup is done
                self.videoCapture.start()
            }
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?){
        if let identifier = segue.identifier {
            if identifier == "GoToDanceSegue"{
                if let vc = segue.destination as? DanceScreenViewController{
                    vc.predictionsWTimestamp = predictionsWTimestamp
                }
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

// MARK: - VideoCaptureDelegate
extension JointViewController: VideoCaptureDelegate {
    func videoCapture(_ capture: VideoCapture, didCaptureVideoFrame pixelBuffer: CVPixelBuffer, timestamp: CMTime) {
        // the captured image from camera is contained on pixelBuffer
        if !isInferencing {
            
            isInferencing = true
            
            // start of measure
            self.👨‍🔧.🎬👏()
            
            // predict!
            self.predictUsingVision(pixelBuffer: pixelBuffer)
        }
    }
}

extension JointViewController {
    // MARK: - Inferencing
    func predictUsingVision(pixelBuffer: CVPixelBuffer) {
        guard let request = request else { fatalError() }
        // vision framework configures the input size of image following our model's input configuration automatically
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer)
        
        if #available(iOS 12.0, *) {
            os_signpost(.begin, log: refreshLog, name: "PoseEstimation")
        }
        try? handler.perform([request])
    }
    
    // MARK: - Postprocessing
    func visionRequestDidComplete(request: VNRequest, error: Error?) {
        if #available(iOS 12.0, *) {
            os_signpost(.event, log: refreshLog, name: "PoseEstimation")
        }
        self.👨‍🔧.🏷(with: "endInference")
        if let observations = request.results as? [VNCoreMLFeatureValueObservation],
            let heatmaps = observations.first?.featureValue.multiArrayValue {

            /* =================================================================== */
            /* ========================= post-processing ========================= */

            /* ------------------ convert heatmap to point array ----------------- */
            var predictedPoints = postProcessor.convertToPredictedPoints(from: heatmaps)

            /* --------------------- moving average filter ----------------------- */
            if predictedPoints.count != mvfilters.count {
                mvfilters = predictedPoints.map { _ in MovingAverageFilter(limit: 3) }
            }
            for (predictedPoint, filter) in zip(predictedPoints, mvfilters) {
                filter.add(element: predictedPoint)
            }
            predictedPoints = mvfilters.map { $0.averagedValue() }
            
            /* =================================================================== */

            /* =================================================================== */
            /* ======================= display the results ======================= */
            DispatchQueue.main.sync {
                // draw line
                self.jointView.bodyPoints = predictedPoints
                
                latestPredictions = self.jointView.latestBodyPointPredictions
                
                // show key points description
                self.showKeypointsDescription(with: predictedPoints)
                
                // end of measure
                self.👨‍🔧.🎬🤚()
                self.isInferencing = false
                
                if #available(iOS 12.0, *) {
                    os_signpost(.end, log: refreshLog, name: "PoseEstimation")
                }
            }
            /* =================================================================== */
        } else {
            // end of measure
            self.👨‍🔧.🎬🤚()
            self.isInferencing = false
            
            if #available(iOS 12.0, *) {
                os_signpost(.end, log: refreshLog, name: "PoseEstimation")
            }
        }
    }
    
    func showKeypointsDescription(with n_kpoints: [PredictedPoint?]) {
        self.tableData = n_kpoints
    }
}

// MARK: - UITableView Data Source
extension JointViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return tableData.count// > 0 ? 1 : 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: UITableViewCell = tableView.dequeueReusableCell(withIdentifier: "LabelCell", for: indexPath)
        cell.textLabel?.text = PoseEstimationForMobileConstant.pointLabels[indexPath.row]
        if let body_point = tableData[indexPath.row] {
            let pointText: String = "\(String(format: "%.3f", body_point.maxPoint.x)), \(String(format: "%.3f", body_point.maxPoint.y))"
            cell.detailTextLabel?.text = "(\(pointText)), [\(String(format: "%.3f", body_point.maxConfidence))]"
        } else {
            cell.detailTextLabel?.text = "N/A"
        }
        return cell
    }
}

// MARK: - 📏(Performance Measurement) Delegate
extension JointViewController: 📏Delegate {
    func updateMeasure(inferenceTime: Double, executionTime: Double, fps: Int) {
        
    }
}
