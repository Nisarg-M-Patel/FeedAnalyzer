//
//  ShareViewController.swift
//  ShareExtension
//
//  Created by Nisarg Patel on 12/26/25.
//

import UIKit
import UniformTypeIdentifiers

class ShareViewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .systemBackground
        
        let label = UILabel()
        label.text = "Processing screenshot..."
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
        
        handleSharedContent()
    }
    
    private func handleSharedContent() {
        guard let extensionItem = extensionContext?.inputItems.first as? NSExtensionItem,
              let itemProvider = extensionItem.attachments?.first else {
            completeRequest()
            return
        }
        
        // Check for image
        if itemProvider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
            itemProvider.loadItem(forTypeIdentifier: UTType.image.identifier, options: nil) { [weak self] (item, error) in
                guard let self = self else { return }
                
                if let error = error {
                    print("Error loading image: \(error)")
                    self.completeRequest()
                    return
                }
                
                var image: UIImage?
                
                if let url = item as? URL {
                    image = UIImage(contentsOfFile: url.path)
                } else if let data = item as? Data {
                    image = UIImage(data: data)
                } else if let img = item as? UIImage {
                    image = img
                }
                
                if let image = image {
                    self.processImage(image)
                } else {
                    self.completeRequest()
                }
            }
        } else {
            completeRequest()
        }
    }
    
    private func processImage(_ image: UIImage) {
        // Queue for background processing
        queueImageForProcessing(image)
        
        // Show success and dismiss
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.completeRequest()
        }
    }
    
    private func queueImageForProcessing(_ image: UIImage) {
        // Save to shared container for main app to process
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.nisarg.feedanalyzer"
        ) else {
            print("Failed to get shared container")
            return
        }
        
        let queueDir = containerURL.appendingPathComponent("queue")
        try? FileManager.default.createDirectory(at: queueDir, withIntermediateDirectories: true)
        
        let filename = "\(UUID().uuidString).jpg"
        let fileURL = queueDir.appendingPathComponent(filename)
        
        if let data = image.jpegData(compressionQuality: 0.8) {
            try? data.write(to: fileURL)
            
            // Notify main app via UserDefaults
            if let sharedDefaults = UserDefaults(suiteName: "group.com.nisarg.feedanalyzer") {
                var queue = sharedDefaults.stringArray(forKey: "pendingScreenshots") ?? []
                queue.append(fileURL.path)
                sharedDefaults.set(queue, forKey: "pendingScreenshots")
            }
        }
    }
    
    private func completeRequest() {
        extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
    }
}
