import UIKit
import UniformTypeIdentifiers

@objc(ShareViewController)
class ShareViewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        NSLog("📱 ShareVC: viewDidLoad")
        view.backgroundColor = .systemBackground
        processSharedImage()
    }
    
    private func processSharedImage() {
        NSLog("📱 ShareVC: processSharedImage started")
        
        guard let extensionItem = extensionContext?.inputItems.first as? NSExtensionItem else {
            NSLog("❌ No extension item")
            completeRequest()
            return
        }
        
        guard let itemProvider = extensionItem.attachments?.first else {
            NSLog("❌ No attachments")
            completeRequest()
            return
        }
        
        NSLog("📱 Has attachment, loading...")
        
        itemProvider.loadItem(forTypeIdentifier: UTType.image.identifier, options: nil) { [weak self] (item, error) in
            if let error = error {
                NSLog("❌ Load error: \(error)")
                self?.completeRequest()
                return
            }
            
            NSLog("📱 Item type: \(type(of: item))")
            
            let image: UIImage?
            if let url = item as? URL {
                NSLog("📱 Got URL: \(url)")
                image = UIImage(contentsOfFile: url.path)
            } else if let data = item as? Data {
                NSLog("📱 Got Data: \(data.count) bytes")
                image = UIImage(data: data)
            } else if let img = item as? UIImage {
                NSLog("📱 Got UIImage")
                image = img
            } else {
                NSLog("❌ Unknown type")
                image = nil
            }
            
            if let image = image {
                NSLog("✅ Have image: \(image.size)")
                self?.saveToAppGroup(image)
            } else {
                NSLog("❌ No image")
            }
            
            self?.completeRequest()
        }
    }
    
    private func saveToAppGroup(_ image: UIImage) {
        NSLog("📱 saveToAppGroup called")
        
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.nisarg.feedanalyzer"
        ) else {
            NSLog("❌ No container URL")
            return
        }
        
        NSLog("✅ Container: \(containerURL.path)")
        
        guard let data = image.jpegData(compressionQuality: 0.8) else {
            NSLog("❌ Failed to get JPEG data")
            return
        }
        
        NSLog("✅ JPEG data: \(data.count) bytes")
        
        let queueDir = containerURL.appendingPathComponent("queue")
        try? FileManager.default.createDirectory(at: queueDir, withIntermediateDirectories: true)
        
        let fileURL = queueDir.appendingPathComponent("\(UUID().uuidString).jpg")
        
        do {
            try data.write(to: fileURL)
            NSLog("✅ Saved to: \(fileURL.path)")
        } catch {
            NSLog("❌ Write failed: \(error)")
            return
        }
        
        guard let defaults = UserDefaults(suiteName: "group.com.nisarg.feedanalyzer") else {
            NSLog("❌ No shared defaults")
            return
        }
        
        var queue = defaults.stringArray(forKey: "pendingScreenshots") ?? []
        queue.append(fileURL.path)
        defaults.set(queue, forKey: "pendingScreenshots")
        NSLog("✅ Queue updated: \(queue)")
    }
    
    private func completeRequest() {
        NSLog("📱 Completing request")
        extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
    }
}
