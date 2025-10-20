//
//  OpenAIService.swift
//  DetailerDash
//
//  Service layer for OpenAI API integration
//

import Foundation
import Combine

// MARK: - OpenAI Request/Response Models

struct OpenAIRequest: Codable {
    let model: String
    let messages: [OpenAIMessage]
    let temperature: Double
    let maxTokens: Int
    
    enum CodingKeys: String, CodingKey {
        case model, messages, temperature
        case maxTokens = "max_tokens"
    }
}

struct OpenAIMessage: Codable {
    let role: String
    let content: String
}

struct OpenAIResponse: Codable {
    let id: String
    let choices: [OpenAIChoice]
    let usage: OpenAIUsage?
    
    struct OpenAIChoice: Codable {
        let message: OpenAIMessage
        let finishReason: String?
        
        enum CodingKeys: String, CodingKey {
            case message
            case finishReason = "finish_reason"
        }
    }
    
    struct OpenAIUsage: Codable {
        let promptTokens: Int
        let completionTokens: Int
        let totalTokens: Int
        
        enum CodingKeys: String, CodingKey {
            case promptTokens = "prompt_tokens"
            case completionTokens = "completion_tokens"
            case totalTokens = "total_tokens"
        }
    }
}

// MARK: - OpenAI Service

class OpenAIService {
    static let shared = OpenAIService()
    
    private init() {}
    
    enum OpenAIError: LocalizedError {
        case invalidConfiguration
        case invalidResponse
        case apiError(String)
        case networkError(Error)
        
        var errorDescription: String? {
            switch self {
            case .invalidConfiguration:
                return "OpenAI API key not configured. Please add your API key in Config.swift"
            case .invalidResponse:
                return "Invalid response from OpenAI API"
            case .apiError(let message):
                return "OpenAI API Error: \(message)"
            case .networkError(let error):
                return "Network error: \(error.localizedDescription)"
            }
        }
    }
    
    /// Send a chat completion request to OpenAI
    func sendChatCompletion(messages: [OpenAIMessage]) -> AnyPublisher<String, OpenAIError> {
        // Validate configuration
        guard Config.isConfigured else {
            return Fail(error: .invalidConfiguration).eraseToAnyPublisher()
        }
        
        // Create request
        let request = OpenAIRequest(
            model: Config.openAIModel,
            messages: messages,
            temperature: Config.temperature,
            maxTokens: Config.maxTokens
        )
        
        // Create URL request
        guard let url = URL(string: Config.openAIEndpoint) else {
            return Fail(error: .invalidResponse).eraseToAnyPublisher()
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.addValue("Bearer \(Config.openAIAPIKey)", forHTTPHeaderField: "Authorization")
        urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Encode body
        guard let httpBody = try? JSONEncoder().encode(request) else {
            return Fail(error: .invalidResponse).eraseToAnyPublisher()
        }
        urlRequest.httpBody = httpBody
        
        // Make request
        return URLSession.shared.dataTaskPublisher(for: urlRequest)
            .mapError { OpenAIError.networkError($0) }
            .flatMap { data, response -> AnyPublisher<String, OpenAIError> in
                // Check HTTP response
                guard let httpResponse = response as? HTTPURLResponse else {
                    return Fail(error: .invalidResponse).eraseToAnyPublisher()
                }
                
                // Handle error status codes
                guard (200...299).contains(httpResponse.statusCode) else {
                    // Try to parse error message
                    if let errorDict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let error = errorDict["error"] as? [String: Any],
                       let message = error["message"] as? String {
                        return Fail(error: .apiError(message)).eraseToAnyPublisher()
                    }
                    return Fail(error: .apiError("HTTP \(httpResponse.statusCode)")).eraseToAnyPublisher()
                }
                
                // Parse response
                guard let openAIResponse = try? JSONDecoder().decode(OpenAIResponse.self, from: data),
                      let firstChoice = openAIResponse.choices.first else {
                    return Fail(error: .invalidResponse).eraseToAnyPublisher()
                }
                
                return Just(firstChoice.message.content)
                    .setFailureType(to: OpenAIError.self)
                    .eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }
    
    /// Helper to create a chat message
    static func createMessage(role: String, content: String) -> OpenAIMessage {
        return OpenAIMessage(role: role, content: content)
    }
}

