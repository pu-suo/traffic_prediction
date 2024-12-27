import SwiftUI
import MapKit

struct ContentView: View {
    // MARK: - Properties
    @State private var showTimePicker = false
    @State private var showDatePicker = false
    @State private var selectedTime = Date()
    @State private var selectedDate = Date()
    @State private var timeText = ""
    @State private var dateText = ""
    @State private var selectedAmPm = "PM"
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var predictionResult: Double?
    
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 33.7654, longitude: -84.3985),
        span: MKCoordinateSpan(latitudeDelta: 0.03, longitudeDelta: 0.03)
    )
    
    let markers = [
        Place(name: "Georgia Tech", coordinate: CLLocationCoordinate2D(latitude: 33.7756, longitude: -84.3963)),
        Place(name: "Mercedes-Benz Stadium", coordinate: CLLocationCoordinate2D(latitude: 33.7553, longitude: -84.4006))
    ]
    
    private let amPmOptions = ["AM", "PM"]
    
    // MARK: - Time and Date Intervals
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
    
    // MARK: - Validation Methods
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
    
    private func timeStringToDate(_ timeStr: String, ampm: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.date(from: "\(timeStr) \(ampm)")
    }
    
    // MARK: - Network Request
    private func fetchPrediction() {
        guard validateTime(timeText) && validateDate(dateText) else {
            errorMessage = "Please enter valid time (HH:MM) and date (MM/DD)"
            return
        }
        
        Task {
            isLoading = true
            do {
                let prediction = try await PredictionNetworkService.shared.fetchPrediction(
                    time: timeText,
                    date: dateText,
                    amPm: selectedAmPm,
                    origin: markers[0].coordinate,
                    destination: markers[1].coordinate
                )
                predictionResult = prediction.predictedVolume
            } catch {
                if let networkError = error as? NetworkError {
                    errorMessage = networkError.errorDescription
                } else {
                    errorMessage = error.localizedDescription
                }
            }
            isLoading = false
        }
    }
    
    // MARK: - Body
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Map View
                Map(coordinateRegion: $region, annotationItems: markers) { place in
                    MapMarker(coordinate: place.coordinate, tint: .red)
                }
                .frame(height: geometry.size.height - 278)
                
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
                                    
                                    HStack(spacing: 20) {
                                        Image(systemName: "chevron.left")
                                            .foregroundColor(.gray)
                                        Image(systemName: "chevron.right")
                                            .foregroundColor(.gray)
                                    }
                                }
                                .padding()
                                .background(Color(.systemBackground))
                            }
                        }
                        
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
                                    HStack(spacing: 20) {
                                        Image(systemName: "chevron.left")
                                            .foregroundColor(.gray)
                                        Image(systemName: "chevron.right")
                                            .foregroundColor(.gray)
                                    }
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
                        
                        if let result = predictionResult {
                            Text("Predicted Volume: \(String(format: "%.2f", result))")
                                .font(.headline)
                                .padding(.top, 8)
                        }
                    }
                    .padding()
                }
                .background(Color(.systemGroupedBackground))
                .frame(height: 250)
            }
        }
        .ignoresSafeArea(.all, edges: .top)
        .alert("Error", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Text(errorMessage ?? "Unknown error occurred")
            Button("OK", role: .cancel) {}
        }
        .sheet(isPresented: $showTimePicker) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(timeIntervals, id: \.self) { time in
                        Button(action: {
                            selectedTime = time
                            let formatter = DateFormatter()
                            formatter.timeStyle = .short
                            timeText = formatter.string(from: time)
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
    
    // MARK: - Formatters
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

// MARK: - Supporting Types
struct Place: Identifiable {
    let id = UUID()
    let name: String
    let coordinate: CLLocationCoordinate2D
}

// MARK: - Preview
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
