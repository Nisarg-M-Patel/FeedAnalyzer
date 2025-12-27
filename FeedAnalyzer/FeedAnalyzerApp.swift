//
//  FeedAnalyzerApp.swift
//  FeedAnalyzer
//
//  Created by Nisarg Patel on 12/26/25.
//

import SwiftUI

@main
struct FeedAnalyzerApp: App {
    
    init() {
        // Register background task for processing screenshots
        BackgroundProcessor.shared.registerBackgroundTask()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
