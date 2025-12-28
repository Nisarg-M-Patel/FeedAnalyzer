//
//  PostDatabase.swift
//  FeedAnalyzer
//
//  Created by Nisarg Patel on 12/26/25.
//

import Foundation
import SQLite3

class PostDatabase {
    static let shared = PostDatabase()
    
    private var db: OpaquePointer?
    private let dbPath: String
    
    private init() {
        let fileManager = FileManager.default
        let urls = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
        let documentsDirectory = urls[0]
        dbPath = documentsDirectory.appendingPathComponent("feed_analyzer.db").path
        
        openDatabase()
        createTables()
    }
    
    private func openDatabase() {
        if sqlite3_open(dbPath, &db) != SQLITE_OK {
            print("Error opening database")
        }
    }
    
    private func createTables() {
        let createPostsTable = """
        CREATE TABLE IF NOT EXISTS posts (
            id TEXT PRIMARY KEY,
            timestamp REAL NOT NULL,
            image_path TEXT NOT NULL,
            text_content TEXT NOT NULL,
            embedding BLOB,
            sentiment_score REAL,
            sentiment_label TEXT,
            entities TEXT,
            keywords TEXT,
            topic_id INTEGER,
            topic_probability REAL
        );
        """
        
        let createTopicsTable = """
        CREATE TABLE IF NOT EXISTS topics (
            id INTEGER PRIMARY KEY,
            keywords TEXT NOT NULL,
            keyword_weights TEXT NOT NULL,
            post_count INTEGER NOT NULL,
            first_seen REAL NOT NULL,
            last_seen REAL NOT NULL
        );
        """
        
        let createPatternsTable = """
        CREATE TABLE IF NOT EXISTS patterns (
            id TEXT PRIMARY KEY,
            timestamp REAL NOT NULL,
            pattern_type TEXT NOT NULL,
            details TEXT NOT NULL,
            confidence REAL NOT NULL
        );
        """
        
        executeSQL(createPostsTable)
        executeSQL(createTopicsTable)
        executeSQL(createPatternsTable)
        
        // Create indices
        executeSQL("CREATE INDEX IF NOT EXISTS idx_timestamp ON posts(timestamp);")
        executeSQL("CREATE INDEX IF NOT EXISTS idx_topic ON posts(topic_id);")
    }
    
    private func executeSQL(_ sql: String) {
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            if sqlite3_step(statement) != SQLITE_DONE {
                print("Error executing SQL: \(sql)")
            }
        }
        sqlite3_finalize(statement)
    }
    
    // MARK: - Post Operations
    
    private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    func insertPost(_ post: AnalyzedPost) throws {
        let sql = """
        INSERT INTO posts (id, timestamp, image_path, text_content, embedding,
                          sentiment_score, sentiment_label, entities, keywords,
                          topic_id, topic_probability)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        """

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            let errmsg = String(cString: sqlite3_errmsg(db))
            NSLog("❌ Prepare failed: \(errmsg)")
            throw DatabaseError.prepareFailed
        }
        defer { sqlite3_finalize(statement) }

        // 1) id
        post.id.uuidString.withCString { cstr in
            sqlite3_bind_text(statement, 1, cstr, -1, SQLITE_TRANSIENT)
        }

        // 2) timestamp
        sqlite3_bind_double(statement, 2, post.timestamp.timeIntervalSince1970)

        // 3) image_path
        post.imagePath.withCString { cstr in
            sqlite3_bind_text(statement, 3, cstr, -1, SQLITE_TRANSIENT)
        }

        // 4) text_content (allow NULL if missing)
        post.textContent.withCString { cstr in
            sqlite3_bind_text(statement, 4, cstr, -1, SQLITE_TRANSIENT)
        }

        // 5) embedding
        if let embedding = post.embedding {
            var emb = embedding // ensure contiguous storage for the duration of bind
            emb.withUnsafeBytes { raw in
                sqlite3_bind_blob(statement, 5, raw.baseAddress, Int32(raw.count), SQLITE_TRANSIENT)
            }
        } else {
            sqlite3_bind_null(statement, 5)
        }

        // 6) sentiment_score
        if let score = post.sentimentScore {
            sqlite3_bind_double(statement, 6, Double(score))
        } else {
            sqlite3_bind_null(statement, 6)
        }

        // 7) sentiment_label
        if let label = post.sentimentLabel {
            label.withCString { cstr in
                sqlite3_bind_text(statement, 7, cstr, -1, SQLITE_TRANSIENT)
            }
        } else {
            sqlite3_bind_null(statement, 7)
        }

        // 8) entities JSON
        if let entitiesData = try? JSONEncoder().encode(post.entities),
           let json = String(data: entitiesData, encoding: .utf8) {
            json.withCString { cstr in
                sqlite3_bind_text(statement, 8, cstr, -1, SQLITE_TRANSIENT)
            }
        } else {
            sqlite3_bind_null(statement, 8)
        }

        // 9) keywords JSON
        if let keywordsData = try? JSONEncoder().encode(post.keywords),
           let json = String(data: keywordsData, encoding: .utf8) {
            json.withCString { cstr in
                sqlite3_bind_text(statement, 9, cstr, -1, SQLITE_TRANSIENT)
            }
        } else {
            sqlite3_bind_null(statement, 9)
        }

        // 10) topic_id
        if let topicId = post.topicId {
            sqlite3_bind_int(statement, 10, Int32(topicId))
        } else {
            sqlite3_bind_null(statement, 10)
        }

        // 11) topic_probability
        if let topicProb = post.topicProbability {
            sqlite3_bind_double(statement, 11, Double(topicProb))
        } else {
            sqlite3_bind_null(statement, 11)
        }

        let result = sqlite3_step(statement)
        if result != SQLITE_DONE {
            let errmsg = String(cString: sqlite3_errmsg(db))
            NSLog("❌ Insert failed with code \(result): \(errmsg)")
            throw DatabaseError.insertFailed
        }
    }

    
    // Add this to PostDatabase
    func resetDatabase() {
        let sql = "DELETE FROM posts"
        var stmt: OpaquePointer?
        
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            if sqlite3_step(stmt) == SQLITE_DONE {
                NSLog("✅ All posts deleted from database")
            } else {
                NSLog("❌ Failed to delete posts")
            }
            sqlite3_finalize(stmt)
        } else {
            NSLog("❌ Failed to prepare DELETE statement")
        }
    }
    
    func debugDatabase() {
        let sql = "SELECT id, timestamp FROM posts ORDER BY timestamp DESC LIMIT 10;"
        var statement: OpaquePointer?
        
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            NSLog("❌ Failed to prepare debug query")
            return
        }
        
        defer { sqlite3_finalize(statement) }
        
        NSLog("📊 Database contents:")
        var count = 0
        while sqlite3_step(statement) == SQLITE_ROW {
            let id = String(cString: sqlite3_column_text(statement, 0))
            let timestamp = sqlite3_column_double(statement, 1)
            NSLog("  - ID: \(id), Time: \(Date(timeIntervalSince1970: timestamp))")
            count += 1
        }
        NSLog("  Total rows: \(count)")
    }
    
    func fetchRecentPosts(limit: Int = 100) -> [AnalyzedPost] {
        let sql = "SELECT * FROM posts ORDER BY timestamp DESC LIMIT ?;"
        var posts: [AnalyzedPost] = []
        
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            return []
        }
        
        defer { sqlite3_finalize(statement) }
        
        sqlite3_bind_int(statement, 1, Int32(limit))
        
        while sqlite3_step(statement) == SQLITE_ROW {
            if let post = parsePost(from: statement) {
                posts.append(post)
            }
        }
        
        return posts
    }
    
    private func parsePost(from statement: OpaquePointer?) -> AnalyzedPost? {
        guard let statement = statement else { return nil }
        
        let idString = String(cString: sqlite3_column_text(statement, 0))
        guard let id = UUID(uuidString: idString) else { return nil }
        
        let timestamp = Date(timeIntervalSince1970: sqlite3_column_double(statement, 1))
        let imagePath = String(cString: sqlite3_column_text(statement, 2))
        let textContent = String(cString: sqlite3_column_text(statement, 3))
        
        var embedding: [Float]?
        if let blob = sqlite3_column_blob(statement, 4) {
            let size = sqlite3_column_bytes(statement, 4)
            let data = Data(bytes: blob, count: Int(size))
            embedding = data.withUnsafeBytes { bytes in
                Array(bytes.bindMemory(to: Float.self))
            }
        }
        
        let sentimentScore = sqlite3_column_type(statement, 5) != SQLITE_NULL
            ? Float(sqlite3_column_double(statement, 5)) : nil
        
        let sentimentLabel = sqlite3_column_type(statement, 6) != SQLITE_NULL
            ? String(cString: sqlite3_column_text(statement, 6)) : nil
        
        var entities: [String: [String]] = [:]
        if let entitiesText = sqlite3_column_text(statement, 7) {
            let string = String(cString: entitiesText)
            if let data = string.data(using: .utf8),
               let decoded = try? JSONDecoder().decode([String: [String]].self, from: data) {
                entities = decoded
            }
        }
        
        var keywords: [String] = []
        if let keywordsText = sqlite3_column_text(statement, 8) {
            let string = String(cString: keywordsText)
            if let data = string.data(using: .utf8),
               let decoded = try? JSONDecoder().decode([String].self, from: data) {
                keywords = decoded
            }
        }
        
        let topicId = sqlite3_column_type(statement, 9) != SQLITE_NULL
            ? Int(sqlite3_column_int(statement, 9)) : nil
        
        let topicProbability = sqlite3_column_type(statement, 10) != SQLITE_NULL
            ? Float(sqlite3_column_double(statement, 10)) : nil
        
        return AnalyzedPost(
            id: id,
            timestamp: timestamp,
            imagePath: imagePath,
            textContent: textContent,
            embedding: embedding,
            sentimentScore: sentimentScore,
            sentimentLabel: sentimentLabel,
            entities: entities,
            keywords: keywords,
            topicId: topicId,
            topicProbability: topicProbability
        )
    }
    
    func deleteAllPosts() throws {
        executeSQL("DELETE FROM posts;")
    }
}

enum DatabaseError: Error {
    case prepareFailed
    case insertFailed
    case fetchFailed
}
