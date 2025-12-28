import Foundation
import CoreML

class EmbeddingModel {
    static let shared = EmbeddingModel()
    
    private var model: mpnet_embed_int8?
    private var tokenizer: WordPieceTokenizer?
    private let maxLength = 128
    
    private init() {
        loadModel()
        tokenizer = WordPieceTokenizer()
    }
    
    private func loadModel() {
        do {
            let config = MLModelConfiguration()
            config.computeUnits = .all
            model = try mpnet_embed_int8(configuration: config)
            NSLog("✅ Embedding model loaded")
        } catch {
            NSLog("❌ Failed to load embedding model: \(error)")
        }
    }
    
    func generateEmbedding(for text: String) -> [Float]? {
        guard let model = model, let tokenizer = tokenizer else {
            NSLog("❌ Model or tokenizer not loaded")
            return nil
        }
        
        guard !text.isEmpty else {
            NSLog("⚠️ Empty text, skipping embedding")
            return nil
        }
        
        do {
            // Tokenize
            let encoding = tokenizer.encode(text: text, maxLength: maxLength)
            
            // Create MLMultiArrays
            let inputIds = try createMLMultiArray(from: encoding.ids)
            let attentionMask = try createMLMultiArray(from: encoding.attentionMask)
            
            // Run inference
            let input = mpnet_embed_int8Input(
                input_ids: inputIds,
                attention_mask: attentionMask
            )
            
            let output = try model.prediction(input: input)
            
            // Extract embedding - check actual output name in Xcode
            // Open the .mlpackage in Xcode and check "Outputs" section
            let outputName = "var_1085"  // Update this if different
            
            if let embedding = output.featureValue(for: outputName)?.multiArrayValue {
                let embedArray = convertToFloatArray(embedding)
                NSLog("✅ Generated embedding: \(embedArray.count) dimensions")
                return embedArray
            }
            
            NSLog("❌ Could not extract embedding from output")
            return nil
            
        } catch {
            NSLog("❌ Embedding generation failed: \(error)")
            return nil
        }
    }
    
    private func createMLMultiArray(from values: [Int]) throws -> MLMultiArray {
        let array = try MLMultiArray(shape: [1, values.count as NSNumber], dataType: .int32)
        
        for (i, value) in values.enumerated() {
            array[[0, i as NSNumber]] = NSNumber(value: value)
        }
        
        return array
    }
    
    private func convertToFloatArray(_ multiArray: MLMultiArray) -> [Float] {
        let count = multiArray.count
        var array = [Float](repeating: 0, count: count)
        
        for i in 0..<count {
            array[i] = multiArray[i].floatValue
        }
        
        return array
    }
}
