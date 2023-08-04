//
//  ViewController.swift
//  MustacheCam
//
//  Created by Chengxin Wu on 7/20/23.
//
import AVFoundation
import UIKit
import CoreData
import AVKit
import ARKit

class ViewController: UIViewController, AVCaptureFileOutputRecordingDelegate, AVCaptureAudioDataOutputSampleBufferDelegate, ARSCNViewDelegate {
    
    
    // create a capture session
    var captureSession : AVCaptureSession?
    // start button and end button
    var videoButton : UIButton!
    // output file
    let fileOutput = AVCaptureMovieFileOutput()
    // Using AVCaptureVideoPreviewLayer display the real-time camera feed on a ViewController
    let vedioLayer = AVCaptureVideoPreviewLayer()
    // is recording
    var isRecording = false
    
    
    // ------------------------------------------------------------
    var managedObjectContext: NSManagedObjectContext!
    var videoURLs: [URL] = [] // 存储从Core Data中获取的视频URL
    var watchButton : UIButton!
    // ------------------------------------------------------------
    
    // ------------------------------------------------------------
    var selectedVideoURL: URL?
    var deleteButton : UIButton!
    // ------------------------------------------------------------
    
    // ------------------------------------------------------------
    var addButton : UIButton!
    var isAddingMustache = false
    @IBOutlet var sceneView: ARSCNView!
    // ------------------------------------------------------------
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // ---------------------------------------------------
        sceneView.delegate = self
        sceneView.showsStatistics = true
        // ---------------------------------------------------
        
        // Do any additional setup after loading the view.
        self.view.layer.addSublayer(vedioLayer)
        self.setButton()
        // detect camera permission
        detCamPermission()
        
        
        // ------------------------------------------------------
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else {
                fatalError("AppDelegate could not find")
            }
        managedObjectContext = appDelegate.persistentContainer.viewContext
        loadVideoURLs()
        setWatchButton()
        setDeleteButton()
        
        // ------------------------------------------------------

        setAddButton()
    }
    
    // camera displayed correctly and adjust its size to match the current view layout
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        vedioLayer.frame = view.bounds
    }
    
    private func detCamPermission(){
        switch AVCaptureDevice.authorizationStatus(for: .video){
        case .notDetermined:
            // request permission
            AVCaptureDevice.requestAccess(for: .video){ [weak self] granted in
                guard granted else{
                    return
                }
                DispatchQueue.main.async {
                    self?.setupCam()
                }
            }
            break
        case .restricted:
            break
        case .denied:
            break
        case .authorized:
            setupCam()
        @unknown default:
            break
        }
    }
    
    // Setting up Camera device
    private func setupCam(){
        let captureSession = AVCaptureSession()
        if let device = AVCaptureDevice.default(for: .video){
            do{
                let input = try AVCaptureDeviceInput(device: device)
                if captureSession.canAddInput(input){
                    captureSession.addInput(input)
                }
                
                // Add audio input to the capture session
                if let audioDevice = AVCaptureDevice.default(for: .audio),
                    let audioInput = try? AVCaptureDeviceInput(device: audioDevice),
                        captureSession.canAddInput(audioInput) {
                        captureSession.addInput(audioInput)
                }
                
                // Configure audio output
                let audioOutput = AVCaptureAudioDataOutput()
                    if captureSession.canAddOutput(audioOutput) {
                        captureSession.addOutput(audioOutput)
                }
                
                // Set the delegate for audio output
                audioOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "AudioOutputQueue"))
                
                if captureSession.canAddOutput(fileOutput){
                    captureSession.addOutput(fileOutput)
                }
                
                vedioLayer.videoGravity = .resizeAspectFill
                vedioLayer.session = captureSession
                
                captureSession.startRunning()
                self.captureSession = captureSession
            }
            catch{
                print(error)
            }
        }
//        let configuration = ARFaceTrackingConfiguration()
//        if ARFaceTrackingConfiguration.isSupported {
//            print("Face tracking is supported on this device.")
//        } else {
//            print("Face tracking is not supported on this device.")
//        }
//        print("Attempting to run AR session...")
//        sceneView.session.run(configuration)
    }
    
    private func setButton(){
        self.videoButton = UIButton(frame: CGRect(x:0, y: 0, width: 120, height: 50))
        self.videoButton.backgroundColor = UIColor.white
        self.videoButton.layer.masksToBounds = true
        self.videoButton.layer.cornerRadius = 20.0
        self.videoButton.layer.position = CGPoint(x: view.frame.size.width/2, y: view.frame.size.height - 100)
        
        self.videoButton.addTarget(self, action: #selector(onClickButton(_:)), for: .touchUpInside)
        self.view.addSubview(self.videoButton)
    }
    
    @objc func onClickButton(_ sender : UIButton){
        if !isRecording{
            startRecording()
        }
        else{
            endRecording()
        }
    }
    
    private func startRecording(){
        let paths = NSSearchPathForDirectoriesInDomains(.documentDirectory,
                                                                    .userDomainMask, true)
        let documentsDirectory = paths[0] as String
        let filePath = "\(documentsDirectory)/temp.mp4"
        let fileURL = URL(fileURLWithPath: filePath)
        fileOutput.startRecording(to: fileURL, recordingDelegate: self)
            
        self.isRecording = true
        self.videoButton.backgroundColor = .red
    }
    
    private func endRecording(){
        fileOutput.stopRecording()
                     
        self.isRecording = false
        self.videoButton.backgroundColor = .white
    }
    
    func fileOutput(_ output: AVCaptureFileOutput,
        didStartRecordingTo fileURL: URL,
        from connections: [AVCaptureConnection]) {
    }
    
    class Video: NSManagedObject {
        @NSManaged var filePath: String
        @NSManaged var duration: Double
        @NSManaged var name: String
    }
    
    func fileOutput(_ output: AVCaptureFileOutput,
                    didFinishRecordingTo outputFileURL: URL,
                    from connections: [AVCaptureConnection], error: Error?) {
        // Code when recording finishes...
        // let user change the name
        let alertController = UIAlertController(title: "save video", message: "Please enter the video name", preferredStyle: .alert)
        alertController.addTextField { (textField) in
            textField.placeholder = "video name"
        }
        
        let saveAction = UIAlertAction(title: "Save", style: .default) { [weak self] (_) in
            guard let videoName = alertController.textFields?[0].text else {
                return
            }
            
            // Save Video into Core Data
            guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else {
                return
            }
            
            let managedContext = appDelegate.persistentContainer.viewContext

            // Create a managed object for the Video entity
            let videoEntity = NSEntityDescription.entity(forEntityName: "VIDEO", in: managedContext)!
            let video = NSManagedObject(entity: videoEntity, insertInto: managedContext)
            
            let asset = AVAsset(url: outputFileURL)
            let duration = CMTimeGetSeconds(asset.duration)
            
            video.setValue(outputFileURL.path, forKey: "filePath")
            video.setValue(duration, forKey: "duration")
            video.setValue(videoName, forKey: "name")
            
            // show the output
            var message: String!
//            if error == nil {
//                message = "Save Successfully"
//            } else {
//                message = "Save Faliure：\(error!.localizedDescription)"
//            }
            
            do {
                try managedContext.save()
                message = "Save Successfully"
            } catch let error as NSError {
                print("Unable to save video。 \(error), \(error.userInfo)")
                message = "Save failed：\(error.localizedDescription)"
            }
            
            DispatchQueue.main.async {
                let alertController = UIAlertController(title: message, message: nil,
                                                        preferredStyle: .alert)
                let cancelAction = UIAlertAction(title: "Confirm", style: .cancel, handler: nil)
                alertController.addAction(cancelAction)
                self?.present(alertController, animated: true, completion: nil)
            }
        }
        
        alertController.addAction(saveAction)
        present(alertController, animated: true, completion: nil)
    }
    
    // ---------------------------------------------------------------------------------
    
    private func setWatchButton(){
        self.watchButton = UIButton(frame: CGRect(x: 0, y: 0, width: 100, height: 50))
//        self.watchButton.center = view.center
        self.watchButton.layer.cornerRadius = 20.0
        self.watchButton.setTitle("Video", for: .normal)
        self.watchButton.backgroundColor = .blue
        self.watchButton.layer.position = CGPoint(x: view.frame.size.width/2 - 130, y: view.frame.size.height - 100)
        self.watchButton.addTarget(self, action: #selector(watchButtonTapped), for: .touchUpInside)
        self.view.addSubview(watchButton)
    }
    
    // Load video URLs from Core Data.
    func loadVideoURLs() {
        let fetchRequest: NSFetchRequest<VIDEO> = VIDEO.fetchRequest()
        do {
            let videos = try managedObjectContext.fetch(fetchRequest)
            videoURLs = videos.compactMap { URL(fileURLWithPath: $0.filePath ?? "") }
        } catch {
            print("从Core Data加载视频时出错：\(error)")
        }
    }
    
    func playVideo(url: URL) {
        let player = AVPlayer(url: url)
        let playerViewController = AVPlayerViewController()
        playerViewController.player = player
        present(playerViewController, animated: true) {
            player.play()
        }
    }
    
    @objc private func watchButtonTapped() {
        // load video data
        loadVideoURLs()

        // Display video selection popup window.
        showVideoSelectionAlert()
    }
    
    private func showVideoSelectionAlert() {
        let alertController = UIAlertController(title: "Choose Vidoe", message: "select the video you want to watch", preferredStyle: .actionSheet)
        
        for (index, videoURL) in videoURLs.enumerated() {
            let action = UIAlertAction(title: "Video \(index + 1)", style: .default) { [weak self] _ in
                self?.playVideo(url: videoURL)
            }
            alertController.addAction(action)
        }
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        alertController.addAction(cancelAction)
        
        
        present(alertController, animated: true, completion: nil)
    }
    
    // ------------------------------------------------------------
    
    private func setDeleteButton(){
        self.deleteButton = UIButton(frame: CGRect(x: 0, y: 0, width: 100, height: 50))
        self.deleteButton.layer.cornerRadius = 20.0
        self.deleteButton.setTitle("Delete", for: .normal)
        self.deleteButton.backgroundColor = .blue
        self.deleteButton.layer.position = CGPoint(x: view.frame.size.width/2 + 130, y: view.frame.size.height - 100)
        self.deleteButton.addTarget(self, action: #selector(deleteButtonTapped), for: .touchUpInside)
        self.view.addSubview(deleteButton)
    }
    
    private func showDeleteVideoSelectionAlert() {
        let alertController = UIAlertController(title: "Choose Video", message: "select the video you want to delete", preferredStyle: .actionSheet)
        
        for (index, videoURL) in videoURLs.enumerated() {
            let action = UIAlertAction(title: "Video \(index + 1)", style: .default) { [weak self] _ in
                self?.deleteSelectedVideo(url: videoURL)
            }
            alertController.addAction(action)
        }
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        alertController.addAction(cancelAction)
        
        
        present(alertController, animated: true, completion: nil)
    }

    
    @objc func deleteButtonTapped() {
        loadVideoURLs()
        showDeleteVideoSelectionAlert()
    }
    
    private func deleteSelectedVideo(url: URL) {
        
        // Delete the entity from Core Data
        let fetchRequest: NSFetchRequest<VIDEO> = VIDEO.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "filePath == %@", url.path)
        
        do {
            let videos = try managedObjectContext.fetch(fetchRequest)
            for video in videos {
                managedObjectContext.delete(video)
            }
            try managedObjectContext.save()
        } catch {
            print("Error occurred while deleting the Core Data entity.：\(error)")
            return
        }
        
        // Delete the video file from the file system.
        let fileManager = FileManager.default
        do {
            try fileManager.removeItem(at: url)
            selectedVideoURL = nil
        } catch {
            print("Error occurred while deleting the video file.：\(error)")
        }
        
        // Remind after delete the video
        let alertController = UIAlertController(title: "Delete Successfully", message: nil, preferredStyle: .alert)
        let okAction = UIAlertAction(title: "Confirm", style: .default, handler: nil)
        alertController.addAction(okAction)
        present(alertController, animated: true, completion: nil)
    }
    
    // ------------------------------------------------------------
    private func setAddButton(){
        self.addButton = UIButton(frame: CGRect(x: 0, y: 0, width: 100, height: 50))
        self.addButton.layer.cornerRadius = 20.0
        self.addButton.setTitle("Add", for: .normal)
        self.addButton.backgroundColor = .blue
        self.addButton.layer.position = CGPoint(x: view.frame.size.width/2 + 130, y: view.frame.size.height - 600)
        self.addButton.addTarget(self, action: #selector(addButtonTapped), for: .touchUpInside)
        self.view.addSubview(addButton)
    }
    
    @objc func addButtonTapped() {
        isAddingMustache = !isAddingMustache
        if isAddingMustache{
            self.addButton.backgroundColor = .red
        } else {
            self.addButton.backgroundColor = .blue
        }
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        // Check if the detected anchor is ARFaceAnchor
        guard isAddingMustache, let faceAnchor = anchor as? ARFaceAnchor else { return }

        // Perform the mustache addition on a background queue
        DispatchQueue.global().async {
            // Load the mustache image
            guard let mustacheImage = UIImage(named: "mustache.png") else { return }

            // Create a SceneKit node for the mustache
            let mustacheNode = SCNNode(geometry: SCNPlane(width: 0.1, height: 0.05))

            // Set the mustache material with the loaded image
            let mustacheMaterial = SCNMaterial()
            mustacheMaterial.diffuse.contents = mustacheImage
            mustacheNode.geometry?.materials = [mustacheMaterial]

            // Get the transform of the face anchor
            let transform = faceAnchor.transform

            // Apply the transform to the mustache node
            mustacheNode.simdTransform = transform

            // Adjust the position and scale of the mustache node based on the face geometry
            // You may need to further adjust the position and size of the mustache node
            // to match the specific location and size of the detected face feature

            // Add the mustache node to the scene on the main thread
            DispatchQueue.main.async {
                self.sceneView.scene.rootNode.addChildNode(mustacheNode)
            }
        }
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        // Check if the detected anchor is ARFaceAnchor
        guard isAddingMustache, let faceAnchor = anchor as? ARFaceAnchor else { return }

        // Perform the mustache addition on a background queue
        DispatchQueue.global().async {
            // Load the mustache image
            guard let mustacheImage = UIImage(named: "mustache.png") else { return }

            // Create a SceneKit node for the mustache
            let mustacheNode = SCNNode(geometry: SCNPlane(width: 0.1, height: 0.05))

            // Set the mustache material with the loaded image
            let mustacheMaterial = SCNMaterial()
            mustacheMaterial.diffuse.contents = mustacheImage
            mustacheNode.geometry?.materials = [mustacheMaterial]

            // Get the transform of the face anchor
            let transform = faceAnchor.transform

            // Apply the transform to the mustache node
            mustacheNode.simdTransform = transform

            // Adjust the position and scale of the mustache node based on the face geometry
            // You may need to further adjust the position and size of the mustache node
            // to match the specific location and size of the detected face feature

            // Add the mustache node to the scene on the main thread
            DispatchQueue.main.async {
                node.addChildNode(mustacheNode)
            }
        }
    }
}
