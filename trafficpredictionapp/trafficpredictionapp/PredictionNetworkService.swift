import Foundation
import CoreLocation
import MapKit

// MARK: - Models
struct PredictionRequest: Codable {
    let start_time: String
    let end_time: String
    let interval_minutes: Int
}

struct PredictionResponse: Codable {
    let status: String
    let message: String
    let parameters: Parameters
    
    struct Parameters: Codable {
        let start_time: String
        let end_time: String
        let interval_minutes: Int
    }
}

// MARK: - Network Error
enum NetworkError: LocalizedError {
    case invalidURL
    case invalidData
    case encodingError
    case requestFailed(String)
    case invalidResponse
    case serverError(String)
    case invalidDateFormat
    case requestTimeout
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL provided"
        case .invalidData:
            return "Invalid data received from server"
        case .encodingError:
            return "Error encoding request data"
        case .requestFailed(let message):
            return message
        case .invalidResponse:
            return "Invalid response from server"
        case .serverError(let message):
            return message
        case .invalidDateFormat:
            return "Invalid date or time format"
        case .requestTimeout:
            return "Request failed: The request timed out."
        }
    }
}

// MARK: - Network Service
final class PredictionNetworkService {
    // MARK: - Properties
    private let baseURL = "http://localhost:6000"
    static let shared = PredictionNetworkService()
    private let session: URLSession
    
    // MARK: - Initialization
    private init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 300
        self.session = URLSession(configuration: configuration)
    }
    
    // MARK: - Helpers
    private func formatDateTime(_ date: String, time: String, amPm: String) -> String {
        return "\(date) \(time) \(amPm)"
    }
    
    private func calculateEndTime(date: String, time: String, amPm: String) -> String? {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MM/dd hh:mm a"
        
        guard let startDate = dateFormatter.date(from: "\(date) \(time) \(amPm)") else {
            return nil
        }
        
        let endDate = Calendar.current.date(byAdding: .minute, value: 15, to: startDate)
        return dateFormatter.string(from: endDate!)
    }
    
    // MARK: - Public Methods
    func fetchPrediction(
        time: String,
        date: String,
        amPm: String,
        origin: CLLocationCoordinate2D,
        destination: CLLocationCoordinate2D
    ) async throws -> PredictionResponse {
        let startTime = formatDateTime(date, time: time, amPm: amPm)
        
        guard let endTime = calculateEndTime(date: date, time: time, amPm: amPm) else {
            throw NetworkError.invalidDateFormat
        }
        
        let request = PredictionRequest(
            start_time: startTime,
            end_time: endTime,
            interval_minutes: 15
        )
        
        return try await performRequest(
            endpoint: "/fetch-volume",
            method: "POST",
            body: request
        )
    }
    
    // MARK: - Private Methods
    private func performRequest<T: Codable>(
        endpoint: String,
        method: String,
        body: T
    ) async throws -> PredictionResponse {
        guard let url = URL(string: baseURL + endpoint) else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            let encoder = JSONEncoder()
            request.httpBody = try encoder.encode(body)
        } catch {
            throw NetworkError.encodingError
        }
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.invalidResponse
            }
            
            // Handle timeout specifically
            if httpResponse.statusCode == URLError.timedOut.rawValue {
                throw NetworkError.requestTimeout
            }
            
            // Check for timeout in response data
            if let responseString = String(data: data, encoding: .utf8),
               responseString.contains("timed out") {
                throw NetworkError.requestTimeout
            }
            
            // Handle non-200 responses
            if !(200...299).contains(httpResponse.statusCode) {
                if let errorResponse = try? JSONDecoder().decode([String: String].self, from: data),
                   let errorMessage = errorResponse["error"] {
                    throw NetworkError.serverError(errorMessage)
                }
                throw NetworkError.requestFailed("Request failed with status code: \(httpResponse.statusCode)")
            }
            
            // Decode successful response
            let decoder = JSONDecoder()
            return try decoder.decode(PredictionResponse.self, from: data)
            
        } catch let error as NetworkError {
            throw error
        } catch let error as URLError where error.code == .timedOut {
            throw NetworkError.requestTimeout
        } catch {
            throw NetworkError.requestFailed("Request failed: \(error.localizedDescription)")
        }
    }
}
