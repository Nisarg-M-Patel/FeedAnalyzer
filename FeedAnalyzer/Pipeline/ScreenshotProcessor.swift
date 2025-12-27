//
//  ScreenshotProcessor.swift
//  FeedAnalyzer
//
//  Created by Nisarg Patel on 12/26/25.
//

import UIKit
import Vision

class ScreenshotProcessor {
    static let shared = ScreenshotProcessor()
    
    private init() {}
    
    func processScreenshot(_ image: UIImage, completion: @escaping (Result<AnalyzedPost, Error>) -> Void) {
        // Save image to documents directory
        guard let imagePath = saveImage(image) else {
            completion(.failure(ProcessingError.imageSaveFailed))
            return
        }
        
        // Extract text using Vision OCR
        extractText(from: image) { result in
            switch result {
            case .success(let text):
                let post = AnalyzedPost(
                    imagePath: imagePath,
                    textContent: text
                )
                
                // Save to database
                do {
                    try PostDatabase.shared.insertPost(post)
                    completion(.success(post))
                } catch {
                    completion(.failure(error))
                }
                
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    private func saveImage(_ image: UIImage) -> String? {
        guard let data = image.jpegData(compressionQuality: 0.8) else { return nil }
        
        let fileManager = FileManager.default
        let urls = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
        let documentsDirectory = urls[0]
        
        let filename = "\(UUID().uuidString).jpg"
        let filePath = documentsDirectory.appendingPathComponent("screenshots").appendingPathComponent(filename)
        
        // Create screenshots directory if needed
        let screenshotsDir = documentsDirectory.appendingPathComponent("screenshots")
        try? fileManager.createDirectory(at: screenshotsDir, withIntermediateDirectories: true)
        
        do {
            try data.write(to: filePath)
            return filePath.path
        } catch {
            print("Error saving image: \(error)")
            return nil
        }
    }
    
    private func extractText(from image: UIImage, completion: @escaping (Result<String, Error>) -> Void) {
        guard let cgImage = image.cgImage else {
            completion(.failure(ProcessingError.invalidImage))
            return
        }
        
        let request = VNRecognizeTextRequest { request, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let observations = request.results as? [VNRecognizedTextObservation] else {
                completion(.failure(ProcessingError.ocrFailed))
                return
            }
            
            let recognizedStrings = observations.compactMap { observation in
                observation.topCandidates(1).first?.string
            }
            
            let fullText = recognizedStrings.joined(separator: "\n")
            completion(.success(fullText))
        }
        
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try handler.perform([request])
            } catch {
                completion(.failure(error))
            }
        }
    }
}

enum ProcessingError: Error {
    case imageSaveFailed
    case invalidImage
    case ocrFailed
}
