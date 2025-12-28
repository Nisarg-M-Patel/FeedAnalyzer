import Foundation

class WordPieceTokenizer {
    private var vocab: [String: Int] = [:]
    private var idsToTokens: [Int: String] = [:]
    
    private let clsToken = "[CLS]"
    private let sepToken = "[SEP]"
    private let padToken = "[PAD]"
    private let unkToken = "[UNK]"
    
    private var clsTokenId: Int = 0
    private var sepTokenId: Int = 0
    private var padTokenId: Int = 0
    private var unkTokenId: Int = 0
    
    init?() {
        guard loadVocab() else {
            NSLog("❌ Failed to load vocabulary")
            return nil
        }
        
        // Cache special token IDs
        clsTokenId = vocab[clsToken] ?? 0
        sepTokenId = vocab[sepToken] ?? 0
        padTokenId = vocab[padToken] ?? 0
        unkTokenId = vocab[unkToken] ?? 0
        
        NSLog("✅ Tokenizer loaded with \(vocab.count) tokens")
    }
    
    private func loadVocab() -> Bool {
        guard let vocabPath = Bundle.main.path(forResource: "vocab", ofType: "txt"),
              let vocabContent = try? String(contentsOfFile: vocabPath, encoding: .utf8) else {
            return false
        }
        
        let lines = vocabContent.components(separatedBy: .newlines)
        for (index, token) in lines.enumerated() {
            let trimmed = token.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            vocab[trimmed] = index
            idsToTokens[index] = trimmed
        }
        
        return !vocab.isEmpty
    }
    
    func encode(text: String, maxLength: Int = 128) -> (ids: [Int], attentionMask: [Int]) {
        // Step 1: Basic tokenization (split on whitespace and punctuation)
        let tokens = basicTokenize(text: text)
        
        // Step 2: WordPiece tokenization
        var subwordTokens: [String] = []
        for token in tokens {
            let pieces = wordpieceTokenize(token: token)
            subwordTokens.append(contentsOf: pieces)
        }
        
        // Step 3: Convert to IDs
        var ids = [clsTokenId]
        for token in subwordTokens {
            if ids.count >= maxLength - 1 { break }
            ids.append(vocab[token] ?? unkTokenId)
        }
        ids.append(sepTokenId)
        
        // Step 4: Create attention mask (1 for real tokens, 0 for padding)
        var attentionMask = [Int](repeating: 1, count: ids.count)
        
        // Step 5: Pad to maxLength
        while ids.count < maxLength {
            ids.append(padTokenId)
            attentionMask.append(0)
        }
        
        // Truncate if needed
        if ids.count > maxLength {
            ids = Array(ids[..<maxLength])
            attentionMask = Array(attentionMask[..<maxLength])
            // Ensure last token is [SEP]
            ids[maxLength - 1] = sepTokenId
        }
        
        return (ids: ids, attentionMask: attentionMask)
    }
    
    private func basicTokenize(text: String) -> [String] {
        // Lowercase and split on whitespace/punctuation
        let lowercased = text.lowercased()
        var tokens: [String] = []
        var currentToken = ""
        
        for char in lowercased {
            if char.isWhitespace {
                if !currentToken.isEmpty {
                    tokens.append(currentToken)
                    currentToken = ""
                }
            } else if char.isPunctuation {
                if !currentToken.isEmpty {
                    tokens.append(currentToken)
                    currentToken = ""
                }
                tokens.append(String(char))
            } else {
                currentToken.append(char)
            }
        }
        
        if !currentToken.isEmpty {
            tokens.append(currentToken)
        }
        
        return tokens
    }
    
    private func wordpieceTokenize(token: String, maxInputCharsPerWord: Int = 100) -> [String] {
        if token.count > maxInputCharsPerWord {
            return [unkToken]
        }
        
        var subTokens: [String] = []
        var start = 0
        let chars = Array(token)
        
        while start < chars.count {
            var end = chars.count
            var foundSubtoken: String?
            
            // Greedy longest-match-first
            while start < end {
                let substr = String(chars[start..<end])
                let candidate = start > 0 ? "##\(substr)" : substr
                
                if vocab[candidate] != nil {
                    foundSubtoken = candidate
                    break
                }
                end -= 1
            }
            
            if let subtoken = foundSubtoken {
                subTokens.append(subtoken)
                start = end
            } else {
                // Unknown token
                subTokens.append(unkToken)
                break
            }
        }
        
        return subTokens
    }
}
