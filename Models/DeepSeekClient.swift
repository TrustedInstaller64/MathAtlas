import Foundation

// MARK: - Configuration

struct AIConfig {
    var provider: AIProvider = .cloud
    var cloudModel: String = "deepseek-v4-flash"
    var ollamaModel: String = "deepseek-r1:8b"
    var cloudEndpoint: String = "https://api.deepseek.com"
    var ollamaEndpoint: String = "http://localhost:11434"
    var thinkingEnabled: Bool = false
    var thinkingDepth: String = "medium" // low, medium, high
}

enum AIProvider: String, CaseIterable {
    case cloud  = "cloud"
    case ollama = "ollama"

    var displayName: String {
        switch self {
        case .cloud:  return "DeepSeek 云端"
        case .ollama: return "Ollama 本地"
        }
    }
}

// MARK: - API Error

enum AIError: Error, LocalizedError {
    case noAPIKey
    case authFailed(String)      // 401, 403
    case insufficientBalance     // 402
    case rateLimited             // 429
    case serverError(String)     // 5xx
    case networkError(String)
    case timeout
    case unexpected(String)

    var errorDescription: String? {
        switch self {
        case .noAPIKey:              return "未设置 API Key"
        case .authFailed(let msg):   return "认证失败：\(msg)"
        case .insufficientBalance:   return "账户余额不足，请充值"
        case .rateLimited:           return "请求频率过高，请稍后重试"
        case .serverError(let msg):  return "服务器错误：\(msg)"
        case .networkError(let msg): return "网络错误：\(msg)"
        case .timeout:               return "连接超时，请检查网络或防火墙"
        case .unexpected(let msg):   return "未知错误：\(msg)"
        }
    }
}

// MARK: - Client

final class DeepSeekClient {
    var config: AIConfig

    init(config: AIConfig) {
        self.config = config
    }

    /// Send a chat completion request.
    func chat(messages: [[String: String]], maxTokens: Int = 4096) async throws -> String {
        let apiKey: String
        if config.provider == .cloud {
            guard let key = KeychainManager.loadAPIKey(), !key.isEmpty else {
                throw AIError.noAPIKey
            }
            apiKey = key
        } else {
            apiKey = "ollama" // Ollama doesn't need a real key
        }

        let model = config.provider == .cloud ? config.cloudModel : config.ollamaModel
        let baseURL = config.provider == .cloud ? config.cloudEndpoint : config.ollamaEndpoint
        guard let url = URL(string: "\(baseURL)/v1/chat/completions") else {
            throw AIError.unexpected("Invalid URL")
        }

        var body: [String: Any] = [
            "model": model,
            "messages": messages,
            "max_tokens": maxTokens,
            "stream": false
        ]
        if config.provider == .cloud, config.thinkingEnabled {
            body["reasoning_effort"] = config.thinkingDepth
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 60
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw AIError.networkError("Invalid response")
        }

        switch http.statusCode {
        case 200:
            break
        case 400:
            let msg = parseErrorMessage(data) ?? (String(data: data, encoding: .utf8) ?? "HTTP 400")
            throw AIError.unexpected("Bad Request — \(msg)")
        case 401, 403:
            let msg = parseErrorMessage(data) ?? "HTTP \(http.statusCode)"
            throw AIError.authFailed(msg)
        case 402:
            throw AIError.insufficientBalance
        case 429:
            throw AIError.rateLimited
        case 500...599:
            let msg = parseErrorMessage(data) ?? "HTTP \(http.statusCode)"
            throw AIError.serverError(msg)
        default:
            throw AIError.unexpected("HTTP \(http.statusCode)")
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let first = choices.first,
              let message = first["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw AIError.unexpected("Failed to parse response")
        }
        return content
    }

    /// Minimal request to verify API key and connectivity.
    func verify() async throws -> (ok: Bool, latency: Double, model: String) {
        let start = Date()
        // Use a minimal but valid request — max 16 tokens so response is fast
        let result = try await chat(messages: [["role": "user", "content": "1+1=?"]], maxTokens: 16)
        let latency = Date().timeIntervalSince(start) * 1000
        let model = config.provider == .cloud ? config.cloudModel : config.ollamaModel
        return (!result.isEmpty, latency, model)
    }

    /// Fetch available models from Ollama.
    func fetchOllamaModels() async throws -> [String] {
        guard let url = URL(string: "\(config.ollamaEndpoint)/api/tags") else { return [] }
        let (data, _) = try await URLSession.shared.data(from: url)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let models = json["models"] as? [[String: Any]] else { return [] }
        return models.compactMap { $0["name"] as? String }
    }

    private func parseErrorMessage(_ data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let error = json["error"] as? [String: Any],
              let msg = error["message"] as? String else { return nil }
        return msg
    }
}
