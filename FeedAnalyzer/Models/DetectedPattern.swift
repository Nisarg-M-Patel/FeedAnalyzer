//
//  DetectedPattern.swift
//  FeedAnalyzer
//
//  Created by Nisarg Patel on 12/26/25.
//

import Foundation

enum PatternType: String, Codable {
    case topicAcceleration
    case topicShift
    case echoChamber
    case sentimentManipulation
    case entityRepetition
}

struct DetectedPattern: Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    let patternType: PatternType
    let details: [String: String]
    let confidence: Float
    
    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        patternType: PatternType,
        details: [String: String],
        confidence: Float
    ) {
        self.id = id
        self.timestamp = timestamp
        self.patternType = patternType
        self.details = details
        self.confidence = confidence
    }
}
