import Foundation
import CoreLocation

// MARK: - Models
struct PredictionResponse: Codable {
    let volumePredictions: [VolumePrediction]
    
    enum CodingKeys: String, CodingKey {
        case volumePredictions = "volume_predictions"
    }
}

struct VolumePrediction: Codable {
    let signalId: Double
    let predictedTotalVolume: Double
    
    enum CodingKeys: String, CodingKey {
        case signalId = "signal_id"
        case predictedTotalVolume = "predicted_total_volume"
    }
}

// MARK: - Network Service
final class PredictionNetworkService {
    static let shared = PredictionNetworkService()
    private let session: URLSession
    
    private init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        self.session = URLSession(configuration: configuration)
    }
    
    func fetchPrediction(for date: Date, year: Int) async throws -> [VolumePrediction] {
        // Create date with specified year
        let calendar = Calendar.current
        var dateComponents = calendar.dateComponents([.month, .day, .hour, .minute], from: date)
        dateComponents.year = year
        dateComponents.second = 0  // Set seconds to 00
        
        guard let dateWithYear = calendar.date(from: dateComponents) else {
            throw NetworkError.invalidResponse
        }
        
        // Format timestamp in local time (don't convert to UTC)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        formatter.timeZone = TimeZone.current  // Use local timezone instead of UTC
        let timestamp = formatter.string(from: dateWithYear)
        
        let urlString = "https://x90tjflflc.execute-api.us-west-1.amazonaws.com/predictions?timestamp=\(timestamp)"
        print("Request URL: \(urlString)")  // Print URL for debugging
        
        guard let url = URL(string: urlString) else {
            throw NetworkError.invalidURL
        }
        
        let (data, response) = try await session.data(for: URLRequest(url: url))
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw NetworkError.serverError("Server error: \(httpResponse.statusCode)")
        }
        
        print("Response data raw: \(String(data: data, encoding: .utf8) ?? "none")")
        
        let decoder = JSONDecoder()
        let predictionResponse = try decoder.decode(PredictionResponse.self, from: data)
        print("Decoded predictions count: \(predictionResponse.volumePredictions.count)")
        print("First few predictions: \(predictionResponse.volumePredictions.prefix(3))")
        return predictionResponse.volumePredictions
    }
}

enum NetworkError: LocalizedError {
    case invalidURL
    case invalidResponse
    case serverError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .serverError(let message):
            return message
        }
    }
}
