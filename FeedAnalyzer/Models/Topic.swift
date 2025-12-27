//
//  Topic.swift
//  FeedAnalyzer
//
//  Created by Nisarg Patel on 12/26/25.
//

import Foundation

struct Topic: Codable, Identifiable {
    let id: Int
    let keywords: [String]
    let keywordWeights: [Float]
    var postCount: Int
    let firstSeen: Date
    var lastSeen: Date
    
    init(
        id: Int,
        keywords: [String],
        keywordWeights: [Float],
        postCount: Int = 1,
        firstSeen: Date = Date(),
        lastSeen: Date = Date()
    ) {
        self.id = id
        self.keywords = keywords
        self.keywordWeights = keywordWeights
        self.postCount = postCount
        self.firstSeen = firstSeen
        self.lastSeen = lastSeen
    }
}
