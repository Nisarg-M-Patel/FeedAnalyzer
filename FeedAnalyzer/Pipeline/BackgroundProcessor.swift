//
//  BackgroundProcessor.swift
//  FeedAnalyzer
//
//  Created by Nisarg Patel on 12/26/25.
//

import Foundation
import BackgroundTasks

class BackgroundProcessor {
    static let shared = BackgroundProcessor()
    
    private let taskIdentifier = "com.nisarg.feedanalyzer.process"
    
    private init() {}
    
    func registerBackgroundTask() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: taskIdentifier,
            using: nil
        ) { task in
            self.handleBackgroundTask(task: task as! BGProcessingTask)
        }
    }
    
    func scheduleBackgroundProcessing() {
        let request = BGProcessingTaskRequest(identifier: taskIdentifier)
        request.requiresNetworkConnectivity = false
        request.requiresExternalPower = false
        
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("Could not schedule background task: \(error)")
        }
    }
    
    private func handleBackgroundTask(task: BGProcessingTask) {
        scheduleBackgroundProcessing() // Schedule next run
        
        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }
        
        processQueuedPosts { success in
            task.setTaskCompleted(success: success)
        }
    }
    
    private func processQueuedPosts(completion: @escaping (Bool) -> Void) {
        // Fetch posts without embeddings
        let posts = PostDatabase.shared.fetchRecentPosts(limit: 100)
        let unprocessed = posts.filter { $0.embedding == nil }
        
        guard !unprocessed.isEmpty else {
            completion(true)
            return
        }
        
        // TODO: Process with ML models
        // For now, just mark as complete
        completion(true)
    }
}
