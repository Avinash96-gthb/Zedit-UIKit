//
//  CreateProjectViewController.swift
//  Zedit-UIKit
//
//  Created by Avinash on 29/10/24.
//

import UIKit
import AVKit
import MobileCoreServices
import UniformTypeIdentifiers

class CreateProjectViewController: UIViewController, UINavigationControllerDelegate, UIImagePickerControllerDelegate, UIDocumentPickerDelegate {

    @IBOutlet weak var selectVideoButton: UIButton!
    @IBOutlet weak var videoPreviewView: UIView!
    @IBOutlet weak var projectNameTextField: UITextField!
    @IBOutlet weak var saveProjectButton: UIButton!
    @IBOutlet weak var nameExistsLabel: UILabel!  // New label to show "name already exists" message
    
    var player: AVPlayer?
    var playerViewController: AVPlayerViewController?
    var selectedVideoURL: URL?
    let mainSegueIdentifier = "MainViewCreate"
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupVideoPreviewView()
        saveProjectButton.isEnabled = false  // Disable button initially
        nameExistsLabel.isHidden = true  // Hide the label initially
        projectNameTextField.addTarget(self, action: #selector(textFieldDidChange(_:)), for: .editingChanged)
    }
    
    private func setupVideoPreviewView() {
        videoPreviewView.layer.borderWidth = 1
        videoPreviewView.layer.borderColor = UIColor.lightGray.cgColor
    }
    
    // Action for the select video button
    @IBAction func selectVideoButtonTapped(_ sender: UIButton) {
        presentVideoSourceOptions()
    }
    
    // Action for the create project button
    @IBAction func createProjectButtonTapped(_ sender: UIButton) {
        saveProject() // Call saveProject; if successful, segue will happen automatically
    }
    
    // Show action sheet for video source options
    private func presentVideoSourceOptions() {
        let actionSheet = UIAlertController(title: "Select Video", message: "Choose a video source", preferredStyle: .actionSheet)
        
        actionSheet.addAction(UIAlertAction(title: "Camera", style: .default, handler: { _ in
            self.presentVideoPicker(sourceType: .camera)
        }))
        
        actionSheet.addAction(UIAlertAction(title: "Photo Library", style: .default, handler: { _ in
            self.presentVideoPicker(sourceType: .savedPhotosAlbum)
        }))
        
        actionSheet.addAction(UIAlertAction(title: "Documents", style: .default, handler: { _ in
            self.presentDocumentPicker()
        }))
        
        actionSheet.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        
        present(actionSheet, animated: true, completion: nil)
    }
    
    // Helper function to present UIImagePickerController
    private func presentVideoPicker(sourceType: UIImagePickerController.SourceType) {
        let picker = UIImagePickerController()
        picker.delegate = self
        picker.sourceType = sourceType
        picker.mediaTypes = [UTType.movie.identifier]
        present(picker, animated: true, completion: nil)
    }
    
    // Helper function to present UIDocumentPicker
    private func presentDocumentPicker() {
        let documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: [.movie])
        documentPicker.delegate = self
        present(documentPicker, animated: true, completion: nil)
    }
    
    // Prepare for segue
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == mainSegueIdentifier,
           let destination = segue.destination as? MainPageViewController,
           let projectName = projectNameTextField.text {
            destination.projectname = projectName
        }
    }
}

// Extension for saving project
extension CreateProjectViewController {
    private func saveProject() {
        guard let projectName = projectNameTextField.text, !projectName.isEmpty else {
            // Do not proceed if the project name is empty
            return
        }
        
        guard let videoURL = selectedVideoURL else {
            // Do not proceed if no video is selected
            return
        }
        
        let fileManager = FileManager.default
        guard let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }
        
        let projectDirectory = documentsDirectory.appendingPathComponent(projectName)
        
        if fileManager.fileExists(atPath: projectDirectory.path) {
            // Do not proceed if a project with this name already exists
            return
        }
        
        do {
            try fileManager.createDirectory(at: projectDirectory, withIntermediateDirectories: true, attributes: nil)
            let destinationURL = projectDirectory.appendingPathComponent(videoURL.lastPathComponent)
            try fileManager.copyItem(at: videoURL, to: destinationURL)
            
            let project = ["name": projectName, "videoURL": destinationURL.path]
            var projects = UserDefaults.standard.array(forKey: "projects") as? [[String: String]] ?? []
            projects.append(project)
            UserDefaults.standard.setValue(projects, forKey: "projects")
        } catch {
            // Handle errors as needed
            print("Error creating project: \(error.localizedDescription)")
        }
    }
}

// Extension for handling video selection
extension CreateProjectViewController {
    // Handle video selection from UIImagePickerController
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        if let videoURL = info[.mediaURL] as? URL {
            selectedVideoURL = videoURL
            playVideo(url: videoURL)
        }
        picker.dismiss(animated: true, completion: nil)
    }

    // Handle video selection from UIDocumentPicker
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        if let videoURL = urls.first {
            selectedVideoURL = videoURL
            playVideo(url: videoURL)
        }
    }

    // Use AVPlayerViewController to play video with controls
    private func playVideo(url: URL) {
        player = AVPlayer(url: url)
        playerViewController = AVPlayerViewController()
        playerViewController?.player = player
        playerViewController?.showsPlaybackControls = true

        videoPreviewView.subviews.forEach { $0.removeFromSuperview() }

        if let playerVC = playerViewController {
            addChild(playerVC)
            playerVC.view.frame = videoPreviewView.bounds
            videoPreviewView.addSubview(playerVC.view)
            playerVC.didMove(toParent: self)
        }

        player?.play()
    }
}

// MARK: - UITextField Delegate Methods
extension CreateProjectViewController {
    @objc func textFieldDidChange(_ textField: UITextField) {
        // Check if the project name is not empty and a video is selected
        let isProjectNameValid = !(projectNameTextField.text?.isEmpty ?? true)
        
        // Check if the project name already exists
        let existingProjects = UserDefaults.standard.array(forKey: "projects") as? [[String: String]] ?? []
        let projectNameExists = existingProjects.contains { $0["name"] == projectNameTextField.text }
        
        saveProjectButton.isEnabled = isProjectNameValid && selectedVideoURL != nil && !projectNameExists
        
        // Update the nameExistsLabel visibility and text
        if projectNameExists {
            nameExistsLabel.isHidden = false
            nameExistsLabel.text = "Name already exists."
        } else {
            nameExistsLabel.isHidden = true
        }
    }
}
