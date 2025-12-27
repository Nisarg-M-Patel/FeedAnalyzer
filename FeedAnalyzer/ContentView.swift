//
//  ContentView.swift
//  FeedAnalyzer
//
//  Created by Nisarg Patel on 12/26/25.
//

import SwiftUI

struct ContentView: View {
    @State private var posts: [AnalyzedPost] = []
    @State private var isProcessing = false
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some View {
        NavigationView {
            List {
                if posts.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "photo.stack")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        Text("No screenshots analyzed yet")
                            .font(.headline)
                        Text("Share an Instagram screenshot to get started")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                } else {
                    ForEach(posts) { post in
                        PostRow(post: post)
                    }
                }
            }
            .navigationTitle("Feed Analyzer")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                        Button("Debug") {
                            debugAppGroup()
                        }
                    }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: refreshPosts) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
        }
        .onAppear {
            refreshPosts()
            checkForQueuedScreenshots()
        }
        .onChange(of: scenePhase) {
            if scenePhase == .active {
                checkForQueuedScreenshots()
            }
        }
    }
    
    func debugAppGroup() {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.nisarg.feedanalyzer"
        ) else {
            print("❌ No container URL")
            return
        }
        
        print("✅ Container: \(containerURL.path)")
        
        let queueDir = containerURL.appendingPathComponent("queue")
        if let files = try? FileManager.default.contentsOfDirectory(atPath: queueDir.path) {
            print("📁 Queue files: \(files)")
        } else {
            print("📁 Queue directory doesn't exist or is empty")
        }
        
        if let sharedDefaults = UserDefaults(suiteName: "group.com.nisarg.feedanalyzer"),
           let queue = sharedDefaults.stringArray(forKey: "pendingScreenshots") {
            print("📋 UserDefaults queue: \(queue)")
        } else {
            print("📋 No queue in UserDefaults")
        }
    }
    
    private func refreshPosts() {
        posts = PostDatabase.shared.fetchRecentPosts(limit: 100)
    }
    
    private func checkForQueuedScreenshots() {
        guard let sharedDefaults = UserDefaults(suiteName: "group.com.nisarg.feedanalyzer"),
              let queue = sharedDefaults.stringArray(forKey: "pendingScreenshots"),
              !queue.isEmpty else {
            return
        }
        
        isProcessing = true
        
        // Process queued screenshots
        for imagePath in queue {
            if let image = UIImage(contentsOfFile: imagePath) {
                ScreenshotProcessor.shared.processScreenshot(image) { result in
                    switch result {
                    case .success:
                        print("Processed screenshot")
                    case .failure(let error):
                        print("Failed to process: \(error)")
                    }
                }
            }
            
            // Delete the queued file
            try? FileManager.default.removeItem(atPath: imagePath)
        }
        
        // Clear the queue
        sharedDefaults.set([], forKey: "pendingScreenshots")
        
        // Refresh posts after processing
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            isProcessing = false
            refreshPosts()
        }
    }
}

struct PostRow: View {
    let post: AnalyzedPost
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(post.timestamp, style: .date)
                    .font(.caption)
                    .foregroundColor(.gray)
                Spacer()
                if let sentiment = post.sentimentLabel {
                    SentimentBadge(label: sentiment, score: post.sentimentScore)
                }
            }
            
            Text(post.textContent)
                .font(.body)
                .lineLimit(3)
            
            if !post.keywords.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(post.keywords.prefix(5), id: \.self) { keyword in
                            Text(keyword)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(8)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct SentimentBadge: View {
    let label: String
    let score: Float?
    
    var color: Color {
        guard let score = score else { return .gray }
        if score > 0.3 { return .green }
        if score < -0.3 { return .red }
        return .orange
    }
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label.capitalized)
                .font(.caption)
                .foregroundColor(color)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

#Preview {
    ContentView()
}
