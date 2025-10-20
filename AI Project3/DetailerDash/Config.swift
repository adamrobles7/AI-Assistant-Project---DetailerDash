//
//  Config.swift
//  DetailerDash
//
//  Configuration and API keys for the application
//

import Foundation

struct Config {
    // MARK: - OpenAI Configuration
    
    /// OpenAI API Key
    /// ⚠️ SECURITY NOTE: Hardcoded for demo/educational purposes only
    /// Production apps should use a backend proxy to protect API keys
    /// 
    /// TO ADD YOUR KEY: Replace "YOUR_OPENAI_API_KEY_HERE" with your actual key from https://platform.openai.com/api-keys
    /// It should look like: "sk-proj-..." or "sk-..."
    static let openAIAPIKey = "YOUR_OPENAI_API_KEY_HERE"
    
    /// OpenAI API Endpoint
    static let openAIEndpoint = "https://api.openai.com/v1/chat/completions"
    
    /// Model to use (gpt-3.5-turbo is recommended for cost-effectiveness)
    /// Options: "gpt-3.5-turbo", "gpt-4-turbo", "gpt-4"
    static let openAIModel = "gpt-3.5-turbo"
    
    /// Maximum tokens for response (controls response length and cost)
    static let maxTokens = 500
    
    /// Temperature (0.0-2.0) - controls randomness. 0.7 is balanced.
    static let temperature = 0.7
    
    // MARK: - Security Recommendations
    
    /// For production deployment:
    /// 1. Move API key to backend proxy server
    /// 2. Implement rate limiting per user
    /// 3. Use environment variables for configuration
    /// 4. Add user authentication to backend
    /// 5. Monitor API usage and set billing alerts
    
    // MARK: - Validation
    
    static var isConfigured: Bool {
        return !openAIAPIKey.isEmpty && 
               openAIAPIKey != "YOUR_OPENAI_API_KEY_HERE" &&
               openAIAPIKey.hasPrefix("sk-")
    }
}

