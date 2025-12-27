//
//  AnalyzedPost.swift
//  FeedAnalyzer
//
//  Created by Nisarg Patel on 12/26/25.
//

import Foundation

struct AnalyzedPost: Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    let imagePath: String
    let textContent: String
    
    let embedding: [Float]?
    let sentimentScore: Float?
    let sentimentLabel: String?
    let entities: [String: [String]]
    let keywords: [String]
    
    var topicId: Int?
    var topicProbability: Float?
    
    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        imagePath: String,
        textContent: String,
        embedding: [Float]? = nil,
        sentimentScore: Float? = nil,
        sentimentLabel: String? = nil,
        entities: [String: [String]] = [:],
        keywords: [String] = [],
        topicId: Int? = nil,
        topicProbability: Float? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.imagePath = imagePath
        self.textContent = textContent
        self.embedding = embedding
        self.sentimentScore = sentimentScore
        self.sentimentLabel = sentimentLabel
        self.entities = entities
        self.keywords = keywords
        self.topicId = topicId
        self.topicProbability = topicProbability
    }
}
