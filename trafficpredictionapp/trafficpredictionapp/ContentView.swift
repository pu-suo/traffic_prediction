private let amPmOptions = ["AM", "PM"]
import SwiftUI
import MapKit

// Supporting Types and Models
enum MapItemType {
    case place
    case signal
}

struct MapAnnotationItem: Identifiable {
    let id: String
    let coordinate: CLLocationCoordinate2D
    let type: MapItemType
    let name: String?
    
    init(place: Place) {
        self.id = place.id.uuidString
        self.coordinate = place.coordinate
        self.type = .place
        self.name = place.name
    }
    
    init(signal: TrafficSignal) {
        self.id = String(signal.id)
        self.coordinate = signal.coordinate
        self.type = .signal
        self.name = nil
    }
}

struct Place {
    let id = UUID()
    let name: String
    let coordinate: CLLocationCoordinate2D
}

struct SignalAnnotationView: View {
    let signalId: Int
    let isSelected: Bool
    let onTap: () -> Void
    let volume: Double?
    
    // Color thresholds for traffic volume
    private func getSignalColor(_ volume: Double) -> Color {
        switch volume {
        case ..<20:
            return .green
        case 20..<40:
            return .yellow
        case 40..<60:
            return .orange
        default:
            return .red
        }
    }
    
    private func getGlowOpacity(_ volume: Double) -> Double {
        switch volume {
        case ..<20:
            return 0.2
        case 20..<40:
            return 0.3
        case 40..<60:
            return 0.4
        default:
            return 0.5
        }
    }
    
    var body: some View {
        Button(action: onTap) {
            ZStack {
                // Outer glowing circle
                Circle()
                    .fill(volume.map(getSignalColor) ?? .gray)
                    .opacity(volume.map(getGlowOpacity) ?? 0.2)
                    .frame(width: 100, height: 100)
                
                // Inner circle
                Circle()
                    .fill(volume.map(getSignalColor) ?? .gray)
                    .frame(width: 24, height: 24)
                
                // Center dot
                Circle()
                    .fill(.white)
                    .frame(width: 8, height: 8)
            }
        }
        .overlay(alignment: .top) {
            if isSelected || volume != nil {
                VStack(spacing: 4) {
                    if isSelected {
                        Text("Signal ID")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text("\(signalId)")
                            .font(.caption.bold())
                            .foregroundColor(.primary)
                    }
                    if let vol = volume {
                        Text("Volume")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(String(format: "%.1f", vol))
                            .font(.caption.bold())
                            .foregroundColor(getSignalColor(vol))
                    }
                }
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.thinMaterial)
                        .shadow(radius: 2)
                )
                .offset(y: -50)
            }
        }
    }
}

struct ContentView: View {
    // Properties
    @State private var showTimePicker = false
    @State private var showDatePicker = false
    @State private var selectedTime = Date()
    @State private var selectedDate = Date()
    @State private var timeText = ""
    @State private var dateText = ""
    @State private var selectedAmPm = "PM"
    @State private var isLoading = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var alertTitle = ""
    @State private var signalVolumes: [Int: Double] = [:]  // Store signal ID to volume mapping
    @State private var trafficSignals: [TrafficSignal] = []
    @State private var selectedSignalId: Int? = nil
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 33.7490, longitude: -84.3880),
        span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
    )
    
    let markers = [
        Place(name: "Georgia Tech", coordinate: CLLocationCoordinate2D(latitude: 33.7756, longitude: -84.3963)),
        Place(name: "Mercedes-Benz Stadium", coordinate: CLLocationCoordinate2D(latitude: 33.7553, longitude: -84.4006))
    ]
    
    @State private var selectedYear = 2025
    private let yearRange = 2020...2030
    
    // Initialize traffic signals
    init() {
        do {
            _trafficSignals = State(initialValue: try SignalDataModel.loadSignals())
            print("Loaded traffic signals with IDs: \(try SignalDataModel.loadSignals().map { $0.id })")
        } catch {
            print("Error loading signals: \(error)")
            _trafficSignals = State(initialValue: [])
        }
    }
    
    private var annotationItems: [MapAnnotationItem] {
        print("\n--- Building Annotation Items ---")
        print("Current signal volumes: \(signalVolumes.count) entries")
        print("Available volume keys: \(signalVolumes.keys.sorted())")
        
        let placeItems = markers.map { MapAnnotationItem(place: $0) }
        
        let signalItems = trafficSignals
            .filter { signal in
                let hasVolume = signalVolumes[signal.id] != nil
                print("Signal \(signal.id): \(hasVolume ? "has volume" : "no volume")")
                return hasVolume
            }
            .map { signal in
                print("Creating annotation for signal \(signal.id) with volume \(signalVolumes[signal.id] ?? 0)")
                return MapAnnotationItem(signal: signal)
            }
        
        print("Created \(signalItems.count) signal annotations")
        print("---------------------------\n")
        
        return placeItems + signalItems
    }
    
    // Time and Date Intervals
    private let timeIntervals: [Date] = {
        let calendar = Calendar.current
        let currentDate = Date()
        var times: [Date] = []
        
        for hour in 12...23 {
            for minute in stride(from: 0, to: 60, by: 30) {
                var components = calendar.dateComponents([.year, .month, .day], from: currentDate)
                components.hour = hour
                components.minute = minute
                if let date = calendar.date(from: components) {
                    times.append(date)
                }
            }
        }
        return times
    }()
    
    private let dateIntervals: [Date] = {
        let calendar = Calendar.current
        let currentDate = Date()
        var dates: [Date] = []
        
        for day in 0...14 {
            if let date = calendar.date(byAdding: .day, value: day, to: currentDate) {
                dates.append(date)
            }
        }
        return dates
    }()
    
    // Validation Methods
    private func validateTime(_ time: String) -> Bool {
        let timeRegex = #"^(1[0-2]|0?[1-9]):([0-5][0-9])$"#
        let timePredicate = NSPredicate(format: "SELF MATCHES %@", timeRegex)
        return timePredicate.evaluate(with: time)
    }
    
    private func validateDate(_ date: String) -> Bool {
        let dateRegex = #"^(0[1-9]|1[0-2])/(0[1-9]|[12][0-9]|3[01])$"#
        let datePredicate = NSPredicate(format: "SELF MATCHES %@", dateRegex)
        return datePredicate.evaluate(with: date)
    }
    
    private func fetchPrediction() {
        guard validateTime(timeText) && validateDate(dateText) else {
            alertTitle = "Error"
            alertMessage = "Please enter valid time (HH:MM) and date (MM/DD)"
            showAlert = true
            return
        }
        
        Task {
            isLoading = true
            do {
                // Convert selected date and time to Date object
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "MM/dd hh:mm a yyyy"
                let currentYear = Calendar.current.component(.year, from: Date())
                guard let selectedDateTime = dateFormatter.date(from: "\(dateText) \(timeText) \(selectedAmPm) \(currentYear)") else {
                    throw NetworkError.invalidResponse
                }
                
                // Fetch predictions for the specific timestamp
                let predictions = try await PredictionNetworkService.shared.fetchPrediction(for: selectedDateTime, year: selectedYear)
                
                // *** IMPORTANT PART: Store the predictions in `signalVolumes` ***
                // so that the map can update with these volumes.
                self.signalVolumes = predictions.reduce(into: [:]) { result, prediction in
                    result[Int(prediction.signalId)] = prediction.predictedTotalVolume
                }
                
                // Now that signalVolumes has data, SwiftUI will rebuild annotationItems,
                // and you'll see the signals on the map.
                
                if !predictions.isEmpty {
                    alertTitle = "Success"
                    let formattedPredictions = predictions
                        .prefix(5)
                        .map { prediction in
                            "Signal ID: \(Int(prediction.signalId)), Predicted Volume: \(String(format: "%.2f", prediction.predictedTotalVolume))"
                        }
                        .joined(separator: "\n")
                    
                    alertMessage = """
                    Predictions received successfully
                    
                    Start Time: \(timeText) \(selectedAmPm)
                    Date: \(dateText)
                    
                    Sample Results:
                    \(formattedPredictions)
                    """
                } else {
                    alertTitle = "Warning"
                    alertMessage = "No predictions found for the specified time."
                }
                showAlert = true
                
            } catch let error as NetworkError {
                alertTitle = "Error"
                alertMessage = error.errorDescription ?? "An unknown error occurred"
                showAlert = true
            } catch {
                alertTitle = "Error"
                alertMessage = error.localizedDescription
                showAlert = true
            }
            isLoading = false
        }
    }

    
    // View Body
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Map View with both markers and traffic signals
                Map(coordinateRegion: $region, annotationItems: annotationItems) { item in
                    MapAnnotation(coordinate: item.coordinate) {
                        switch item.type {
                        case .place:
                            VStack {
                                Circle()
                                    .fill(.red)
                                    .frame(width: 12, height: 12)
                                if let name = item.name {
                                    Text(name)
                                        .font(.caption)
                                        .padding(4)
                                        .background(.thinMaterial)
                                        .cornerRadius(4)
                                }
                            }
                        case .signal:
                            let signalId = Int(item.id) ?? 0
                            SignalAnnotationView(
                                signalId: signalId,
                                isSelected: selectedSignalId == signalId,
                                onTap: {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        selectedSignalId = signalId
                                    }
                                },
                                volume: signalVolumes[signalId]
                            )
                        }
                    }
                }
                .frame(height: geometry.size.height - 278)
                .overlay(
                    VStack {
                        Spacer()
                        HStack {
                            HStack {
                                Circle()
                                    .fill(.red)
                                    .frame(width: 10, height: 10)
                                Text("Route Points")
                                    .font(.caption)
                                Circle()
                                    .fill(.green)
                                    .frame(width: 10, height: 10)
                                Text("Traffic Signals")
                                    .font(.caption)
                            }
                            .padding(8)
                            .background(.thinMaterial)
                            .cornerRadius(8)
                            Spacer()
                        }
                        .padding()
                    }
                )
                
                // Form Section
                VStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("Depart at")
                                .font(.headline)
                            Spacer()
                            Text("Options")
                                .foregroundColor(.blue)
                        }
                        
                        // Time Selection
                        HStack {
                            Button(action: {
                                showTimePicker.toggle()
                                showDatePicker = false
                            }) {
                                HStack {
                                    Image(systemName: "clock")
                                        .foregroundColor(.gray)
                                    TextField("Enter time (HH:MM)", text: $timeText)
                                        .keyboardType(.numberPad)
                                        .textFieldStyle(RoundedBorderTextFieldStyle())
                                }
                            }
                            
                            // AM/PM Selector
                            Menu {
                                ForEach(amPmOptions, id: \.self) { option in
                                    Button(action: { selectedAmPm = option }) {
                                        Text(option)
                                    }
                                }
                            } label: {
                                Text(selectedAmPm)
                                    .frame(width: 50)
                                    .padding(.vertical, 8)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(8)
                            }
                            
                            // Year Selector
                            Menu {
                                ForEach(Array(yearRange), id: \.self) { year in
                                    Button(action: { selectedYear = year }) {
                                        Text(String(year))
                                    }
                                }
                            } label: {
                                Text(String(selectedYear))
                                    .frame(width: 70)
                                    .padding(.vertical, 8)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(8)
                            }
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        
                        // Date Selection
                        HStack {
                            Button(action: {
                                showDatePicker.toggle()
                                showTimePicker = false
                            }) {
                                HStack {
                                    Image(systemName: "calendar")
                                        .foregroundColor(.gray)
                                    TextField("Enter date (MM/DD)", text: $dateText)
                                        .keyboardType(.numberPad)
                                        .textFieldStyle(RoundedBorderTextFieldStyle())
                                    Spacer()
                                }
                                .padding()
                                .background(Color(.systemBackground))
                            }
                        }
                        
                        // Submit Button
                        Button(action: fetchPrediction) {
                            HStack {
                                if isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                }
                                Text(isLoading ? "Loading..." : "Get Prediction")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(isLoading ? Color.gray : Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                        .disabled(isLoading)
                    }
                    .padding()
                }
                .background(Color(.systemGroupedBackground))
                .frame(height: 250)
            }
        }
        .ignoresSafeArea(.all, edges: .top)
        .alert(alertTitle, isPresented: $showAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
        .sheet(isPresented: $showTimePicker) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(timeIntervals, id: \.self) { time in
                        Button(action: {
                            selectedTime = time
                            timeText = timeFormatter.string(from: time)
                            selectedAmPm = Calendar.current.component(.hour, from: time) >= 12 ? "PM" : "AM"
                            showTimePicker = false
                        }) {
                            Text(timeFormatter.string(from: time))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                                .background(selectedTime == time ? Color(.systemGray5) : Color(.systemBackground))
                        }
                        .foregroundColor(.primary)
                        Divider()
                    }
                }
            }
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $showDatePicker) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(dateIntervals, id: \.self) { date in
                        Button(action: {
                            selectedDate = date
                            dateText = dateFormatter.string(from: date)
                            showDatePicker = false
                        }) {
                            Text(dateFormatter.string(from: date))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                                .background(selectedDate == date ? Color(.systemGray5) : Color(.systemBackground))
                        }
                        .foregroundColor(.primary)
                        Divider()
                    }
                }
            }
            .presentationDetents([.medium])
        }
    }
    
    // Formatters
    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd"
        return formatter
    }
}

// DateFormatter Extension
extension DateFormatter {
    static let iso8601Full: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter
    }()
}

// Preview Provider
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
