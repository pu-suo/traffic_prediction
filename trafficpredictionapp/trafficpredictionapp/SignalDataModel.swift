import Foundation
import MapKit

struct TrafficSignal {
    let id: Int
    let coordinate: CLLocationCoordinate2D
}

class SignalDataModel {
    static func loadSignals() -> [TrafficSignal] {
        guard let path = Bundle.main.path(forResource: "atlanta_signals_long_lat", ofType: "csv") else {
            print("Failed to find CSV file")
            return []
        }
        
        do {
            let content = try String(contentsOfFile: path, encoding: .utf8)
            let lines = content.components(separatedBy: .newlines)
            
            // Convert each line (after skipping header) into a TrafficSignal
            let allSignals = lines.dropFirst().compactMap { line -> TrafficSignal? in
                let components = line.components(separatedBy: ",")
                guard components.count == 3,
                      let id = Int(components[0]),
                      let latitude = Double(components[1]),
                      let longitude = Double(components[2]) else {
                    return nil
                }
                
                return TrafficSignal(
                    id: id,
                    coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
                )
            }
            
            // If you want to keep them sorted by distance to Georgia Tech, but load *all* signals:
            let centerCoordinate = CLLocationCoordinate2D(latitude: 33.7756, longitude: -84.3963)
            return allSignals
                .sorted { signal1, signal2 in
                    let distance1 = distance(from: centerCoordinate, to: signal1.coordinate)
                    let distance2 = distance(from: centerCoordinate, to: signal2.coordinate)
                    return distance1 < distance2
                }
            
            // If you don't even need them sorted, you can return allSignals directly:
            // return allSignals
            
        } catch {
            print("Error reading CSV file: \(error)")
            return []
        }
    }
    
    // Helper method to calculate distance between two coordinates
    private static func distance(from coord1: CLLocationCoordinate2D, to coord2: CLLocationCoordinate2D) -> CLLocationDistance {
        let location1 = CLLocation(latitude: coord1.latitude, longitude: coord1.longitude)
        let location2 = CLLocation(latitude: coord2.latitude, longitude: coord2.longitude)
        return location1.distance(from: location2)
    }
}

