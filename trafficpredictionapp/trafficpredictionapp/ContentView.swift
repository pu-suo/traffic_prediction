import SwiftUI
import MapKit

struct ContentView: View {
    @State private var showTimePicker = false
    @State private var showDatePicker = false
    @State private var selectedTime = Date()
    @State private var selectedDate = Date()
    @State private var timeText = ""
    @State private var dateText = ""
    @State private var selectedAmPm = "PM"
    
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 33.7490, longitude: -84.3880),
        span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
    )
    
    let markers = [
        Place(name: "Location A", coordinate: CLLocationCoordinate2D(latitude: 33.7490, longitude: -84.3880)),
        Place(name: "Location B", coordinate: CLLocationCoordinate2D(latitude: 33.7580, longitude: -84.3920))
    ]
    
    private let amPmOptions = ["AM", "PM"]
    
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
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Map takes remaining space
                Map(coordinateRegion: $region, annotationItems: markers) { place in
                    MapMarker(coordinate: place.coordinate, tint: .red)
                }
                .frame(height: geometry.size.height - 278) // Subtract form height from total height
                
                // Form section with fixed height
                VStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("Depart at")
                                .font(.headline)
                            Spacer()
                            Text("Options")
                                .foregroundColor(.blue)
                        }
                        
                        // Time Section
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
                                        .frame(maxWidth: .infinity)
                                    
                                    Menu {
                                        ForEach(amPmOptions, id: \.self) { option in
                                            Button(action: {
                                                selectedAmPm = option
                                            }) {
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
                        
                        // Date Section
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
                                        .onChange(of: dateText) { newValue in
                                            if validateDate(newValue) {
                                                let formatter = DateFormatter()
                                                formatter.dateFormat = "MM/dd"
                                                if let date = formatter.date(from: newValue) {
                                                    selectedDate = date
                                                }
                                            }
                                        }
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
                        
                        Button(action: {
                            if validateTime(timeText) && validateDate(dateText) {
                                print("Time entered: \(timeText) \(selectedAmPm)")
                                print("Date entered: \(dateText)")
                            } else {
                                print("Invalid time or date format")
                            }
                        }) {
                            Text("Submit")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                        .padding(.top, 20)
                    }
                    .padding()
                }
                .background(Color(.systemGroupedBackground))
                .frame(height: 250) // Fixed height for form
            }
        }
        .ignoresSafeArea(.all, edges: .top)
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

struct Place: Identifiable {
    let id = UUID()
    let name: String
    let coordinate: CLLocationCoordinate2D
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
