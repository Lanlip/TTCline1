import SwiftUI
import MapKit

struct ContentView: View {
    @StateObject private var manager = SubwayAlarmManager()
    @State private var mapRegion = MapCameraPosition.region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 43.6532, longitude: -79.3832),
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        )
    )
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Current Location")) {
                    Picker("Current Station", selection: $manager.currentStation) {
                        Text("Unknown").tag(nil as TTCStation?)
                        ForEach(manager.stations) { station in
                            Text(station.name).tag(station as TTCStation?)
                        }
                    }
                    .disabled(manager.isAlarmActive)
                    
                    Button(action: {
                        manager.startTrackingLocation()
                    }) {
                        Text("Refresh Location")
                            .foregroundColor(.blue)
                    }
                    .disabled(manager.isAlarmActive)
                }
                
                Section(header: Text("Destination")) {
                    Picker("Target Station", selection: $manager.targetStation) {
                        Text("Select Destination").tag(nil as TTCStation?)
                        ForEach(manager.stations) { station in
                            Text(station.name).tag(station as TTCStation?)
                        }
                    }
                    .disabled(manager.isAlarmActive)
                }
                
                Section(header: Text("Alarm Settings")) {
                    Toggle("Sound", isOn: $manager.useSound)
                    Toggle("Vibration", isOn: $manager.useVibration)
                }
                .disabled(manager.isAlarmActive)
                
                Section {
                    
                    if manager.isRinging {
                        Button(action: {
                            manager.stopRinging()
                        }) {
                            Text("Turn Off Alarm 🛑")
                                .font(.title2)
                                .bold()
                                .frame(maxWidth: .infinity, alignment: .center)
                                .foregroundColor(.white)
                                .padding(.vertical, 10)
                                .background(Color.red)
                                .cornerRadius(10)
                        }
                        .listRowBackground(Color.clear)
                    } else {
                        
                        Button(action: {
                            if manager.isAlarmActive {
                                manager.stopAlarm()
                            } else {
                                manager.startAlarm()
                            }
                        }) {
                            Text(manager.isAlarmActive ? "Cancel Alarm" : "Start Alarm")
                                .frame(maxWidth: .infinity, alignment: .center)
                                .foregroundColor(manager.isAlarmActive ? .red : .blue)
                                .font(.headline)
                        }
                        .disabled(manager.targetStation == nil && !manager.isAlarmActive)
                    }
                }
                
                Section(header: Text("Your Route")) {
                    Map(position: $mapRegion) {
                        UserAnnotation()
                        
                        if let target = manager.targetStation {
                            Marker(target.name, coordinate: target.coordinate)
                                .tint(.green)
                        }
                    }
                    .frame(height: 250)
                    .cornerRadius(10)
                }
                
                if manager.isUnderground {
                    Section {
                        Text("Currently underground, signal may be weak.")
                            .foregroundColor(.red)
                            .font(.caption)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .multilineTextAlignment(.center)
                            .padding(.top, 5)
                    }
                    .listRowBackground(Color.clear)
                }
            }
            .navigationTitle("Subway shit with no wifi")
            .onAppear {
                manager.startTrackingLocation()
            }
            .onChange(of: manager.userLocation) { oldLocation, newLocation in
                guard let newLocation else { return }
                withAnimation {
                    mapRegion = .region(MKCoordinateRegion(
                        center: newLocation.coordinate,
                        span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
                    ))
                }
            }
        }
    }
}
