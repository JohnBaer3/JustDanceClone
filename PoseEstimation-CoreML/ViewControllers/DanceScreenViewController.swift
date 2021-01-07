//
//  DanceScreenViewController.swift
//  PoseEstimation-CoreML
//
//  Created by John Baer on 12/26/20.
//  Copyright © 2020 tucan9389. All rights reserved.
//

import UIKit
import Vision
import CoreMedia
import os.signpost

class DanceScreenViewController: UIViewController {
    
    let refreshLog = OSLog(subsystem: "com.tucan9389.PoseEstimation-CoreML", category: "InferenceOperations")
    
    public typealias DetectObjectsCompletion = ([PredictedPoint?]?, Error?) -> Void
    
    // MARK: - UI Properties
    
    @IBOutlet weak var videoPreview: UIView!
    @IBOutlet weak var jointView: DrawingJointView!
    
    @IBOutlet weak var startRetryButton: UIButton!
    @IBOutlet weak var countdownLabel: UILabel!
    @IBOutlet weak var ratingLabel: UILabel!
    
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
    var predictionsWTimestamp: [Float:[Int:(CGFloat, CGFloat)?]] = [:]
    var latestPredictions: [Int:(CGFloat,CGFloat)?] = [:]
    var startButtonTransparent = false
    var timer = Timer()
    var analysisTimer = Timer()
    var countDownTimer = 4
    var scoreForLast2Seconds: CGFloat = 0.0
    
    var analysisTimeCounter: Float = 0.0
    var totalScore: CGFloat = 0.0
    var avgScore: CGFloat = 0.0
    var everyFour: Float = 4.0
    
    @IBAction func startButtonClicked(_ sender: Any) {
        if !startButtonTransparent{
            startRetryButton.alpha = 0
            countdownLabel.alpha = 1.0
            startButtonTransparent = true
        }
        timer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(startCountDown), userInfo: nil, repeats: true)
    }
    
    @objc func startCountDown(){
        countDownTimer -= 1
        if countDownTimer < 1{
            startAnalysis()
            countdownLabel.alpha = 0.0
            timer.invalidate()
        }else{
            countdownLabel.text = String(countDownTimer)
            UIView.animate(withDuration: 0.95) { [weak self] in
                self!.countdownLabel.transform = CGAffineTransform(scaleX: 5, y: 5)
             } completion: { _ in
                if self.countDownTimer > 1{
                    self.countdownLabel.transform = CGAffineTransform(scaleX: 1, y: 1)
                }
            }
        }
    }
    
    func startAnalysis(){
        analysisTimeCounter = 0.0
        analysisTimer = Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(analyze), userInfo: nil, repeats: true)
    }
    
    func finishAnalyzing(){
        //Do confetti
        view.layer.addSublayer(confettiLayer)

        //Fade out to final screen
        let finalScoreVC = storyboard?.instantiateViewController(withIdentifier: "FinalScoreViewController") as! FinalScoreViewController
        finalScoreVC.finalScore = totalScore
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
            let transition: CATransition = CATransition()
            transition.duration = 2.0
            transition.type = CATransitionType.fade
            self.navigationController?.view.layer.add(transition, forKey: nil)
            self.navigationController?.pushViewController(finalScoreVC, animated: false)
       }
    }
    
    
    @objc func analyze(){
        var totalScoreCurrTime:CGFloat = 0.0
        if predictionsWTimestamp[analysisTimeCounter] == nil{
            analysisTimer.invalidate()
            finishAnalyzing()
        }else{
            let predForCurrTime = predictionsWTimestamp[analysisTimeCounter]!
            
            //From 0 to 13, calculate current predictions - different calculations for each
            for (body, predictedPointsTuple) in predForCurrTime {
                if predictedPointsTuple != nil{
                    var connectingBodyPart: Int = 0
                    var modifier: CGFloat = 1.0
                    switch body{
                    case 0: connectingBodyPart = 1
                    case 1: connectingBodyPart = 0
                    case 2: connectingBodyPart = 1
                    case 3: connectingBodyPart = 2
                    case 4: connectingBodyPart = 3; modifier = 3
                    case 5: connectingBodyPart = 1
                    case 6: connectingBodyPart = 5
                    case 7: connectingBodyPart = 6; modifier = 3
                    case 8: connectingBodyPart = 1
                    case 9: connectingBodyPart = 8
                    case 10: connectingBodyPart = 9; modifier = 2
                    case 11: connectingBodyPart = 1
                    case 12: connectingBodyPart = 11
                    case 13: connectingBodyPart = 12; modifier = 2
                    default: connectingBodyPart = 0
                    }
                    //If null, we just add 0. It's our code that's prob wrong
                    if predictionsWTimestamp[analysisTimeCounter]![connectingBodyPart] != nil{
                        if latestPredictions[body] != nil && latestPredictions[connectingBodyPart] != nil{
                            let diffInAngle = calculateDiffInAngle(predictedPointsTuple!, predForCurrTime[connectingBodyPart]!!, startBodyPart:body, connectingBodyPart:connectingBodyPart)
                            totalScoreCurrTime += (diffInAngle / 360 / 13 / modifier)
                        }
                    }
                }
            }
            //Right here, if totalScoreCurrTime > 0.6 then good, > 0.8 then great
            scoreForLast2Seconds += (1-totalScoreCurrTime)
            print(analysisTimeCounter)
            if analysisTimeCounter > everyFour{
                if scoreForLast2Seconds > (8*4){ //80% for 4 seconds
                    ratingLabel.text = "Great!"
                }else if scoreForLast2Seconds > (6*4){ //60% for 4 seconds
                    ratingLabel.text = "Good!"
                }else{
                    ratingLabel.text = "OK"
                }
                UIButton.animate(withDuration: 0.5, delay: 0, options: .curveEaseOut, animations: {
                    self.ratingLabel.alpha = 1.0
                }, completion: { (finished: Bool) in
                    UIButton.animate(withDuration: 0.5, delay: 2, options: .curveEaseOut, animations: {
                        self.ratingLabel.alpha = 0.0
                    }, completion: nil)
                })
                scoreForLast2Seconds = 0
                everyFour += 4
            }
            analysisTimeCounter += 0.1
        }
        totalScore += (1-totalScoreCurrTime)
    }
    
    
    
    func calculateDiffInAngle(_ predictedPointsTuple: (CGFloat, CGFloat), _ connectPointsTuple: (CGFloat, CGFloat), startBodyPart: Int, connectingBodyPart: Int) -> CGFloat{
        let currPoint = CGPoint(x: predictedPointsTuple.0, y: predictedPointsTuple.1)
        let connectPoint = CGPoint(x: connectPointsTuple.0, y: connectPointsTuple.1)
        let anglePred = calculateAngleOf(currPoint, connectPoint)
        
        let latestPredCurrPoint = CGPoint(x: latestPredictions[startBodyPart]!!.0, y: latestPredictions[startBodyPart]!!.1)
        let latestPredConnectPoint = CGPoint(x: latestPredictions[connectingBodyPart]!!.0, y: latestPredictions[connectingBodyPart]!!.1)
        let latestAnglePred = calculateAngleOf(latestPredCurrPoint, latestPredConnectPoint)
        
        let diffInAngle = abs(anglePred - latestAnglePred)
        var modifier: CGFloat = 5.0
        if(startBodyPart == 7 || startBodyPart == 4){
            modifier = 20
        }
        
        return diffInAngle < modifier ? 0 : diffInAngle-modifier
    }
    
    
    func calculateAngleOf(_ firstPoint: CGPoint, _ secondPoint: CGPoint) -> CGFloat{
        return (atan2((secondPoint.y-firstPoint.y), (secondPoint.x-firstPoint.x)) * 180 / CGFloat(Double.pi))
    }
    
    
    func setUpViews(){
        startRetryButton.backgroundColor = UIColor(red: 59/255.0, green: 59/255.0, blue: 59/255.0, alpha: 1)
        startRetryButton.layer.cornerRadius = 20
        startRetryButton.layer.borderColor = UIColor.white.cgColor
        startRetryButton.layer.borderWidth = 1
        startRetryButton.clipsToBounds = true
        
        ratingLabel.alpha = 0
    }
    
    
    
    
    
    
    
    
    lazy var confettiTypes: [ConfettiType] = {
        let confettiColors = [
            (r:149,g:58,b:255), (r:255,g:195,b:41), (r:255,g:101,b:26),
            (r:123,g:92,b:255), (r:76,g:126,b:255), (r:71,g:192,b:255),
            (r:255,g:47,b:39), (r:255,g:91,b:134), (r:233,g:122,b:208)
            ].map { UIColor(red: $0.r / 255.0, green: $0.g / 255.0, blue: $0.b / 255.0, alpha: 1) }

        // For each position x shape x color, construct an image
        return [ConfettiPosition.foreground, ConfettiPosition.background].flatMap { position in
            return [ConfettiShape.rectangle, ConfettiShape.circle].flatMap { shape in
                return confettiColors.map { color in
                    return ConfettiType(color: color, shape: shape, position: position)
                }
            }
        }
    }()
    
    lazy var confettiLayer: CAEmitterLayer = {
        let emitterLayer = CAEmitterLayer()

        emitterLayer.emitterCells = confettiCells
        emitterLayer.emitterPosition = CGPoint(x: view.bounds.midX, y: view.bounds.minY - 500)
        emitterLayer.emitterSize = CGSize(width: view.bounds.size.width, height: 500)
        emitterLayer.emitterShape = .rectangle
        emitterLayer.frame = view.bounds

        emitterLayer.beginTime = CACurrentMediaTime()
        return emitterLayer
    }()

    lazy var confettiCells: [CAEmitterCell] = {
        return confettiTypes.map { confettiType in
            let cell = CAEmitterCell()

            cell.beginTime = 0.1
            cell.birthRate = 10
            cell.contents = confettiType.image.cgImage
            cell.emissionRange = CGFloat(Double.pi)
            cell.lifetime = 10
            cell.spin = 4
            cell.spinRange = 8
            cell.velocityRange = 100
            cell.yAcceleration = 150

            return cell
        }
    }()

    override func viewDidAppear(_ animated: Bool) {
//        super.viewDidAppear(animated)
    }
    
    
    
    // MARK: - View Controller Life Cycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setUpViews()
        
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
        videoCapture.setUp(sessionPreset: .hd1920x1080, cameraPosition: .front) { success in
            
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
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        resizePreviewLayer()
    }
    
    func resizePreviewLayer() {
        videoCapture.previewLayer?.frame = videoPreview.bounds
    }
}

// MARK: - VideoCaptureDelegate
extension DanceScreenViewController: VideoCaptureDelegate {
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

extension DanceScreenViewController {
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
extension DanceScreenViewController: UITableViewDataSource {
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
extension DanceScreenViewController: 📏Delegate {
    func updateMeasure(inferenceTime: Double, executionTime: Double, fps: Int) {
        
    }
}
