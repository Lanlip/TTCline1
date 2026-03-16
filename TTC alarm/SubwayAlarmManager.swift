import Foundation
import CoreLocation
import UserNotifications
import AudioToolbox
import MapKit

struct TTCStation: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let coordinate: CLLocationCoordinate2D
    
    static func == (lhs: TTCStation, rhs: TTCStation) -> Bool {
        lhs.name == rhs.name
    }
    func hash(into hasher: inout Hasher) {
        hasher.combine(name)
    }
}

class SubwayAlarmManager: NSObject, ObservableObject, CLLocationManagerDelegate, UNUserNotificationCenterDelegate {
    var locationManager = CLLocationManager()
    
    @Published var currentStation: TTCStation?
    @Published var targetStation: TTCStation?
    @Published var isAlarmActive = false
    

    @Published var isRinging = false
    
    @Published var userLocation: CLLocation?
    @Published var isUnderground = false
    
    @Published var useSound = true
    @Published var useVibration = true
    
    private var alarmTimer: Timer?
    
    let stations = [
        TTCStation(name: "Vaughan Metropolitan Centre", coordinate: CLLocationCoordinate2D(latitude: 43.7941, longitude: -79.5268)),
        TTCStation(name: "Highway 407", coordinate: CLLocationCoordinate2D(latitude: 43.7833, longitude: -79.5233)),
        TTCStation(name: "Pioneer Village", coordinate: CLLocationCoordinate2D(latitude: 43.7766, longitude: -79.5094)),
        TTCStation(name: "York University", coordinate: CLLocationCoordinate2D(latitude: 43.7741, longitude: -79.4997)),
        TTCStation(name: "Finch West", coordinate: CLLocationCoordinate2D(latitude: 43.7652, longitude: -79.4910)),
        TTCStation(name: "Downsview Park", coordinate: CLLocationCoordinate2D(latitude: 43.7538, longitude: -79.4786)),
        TTCStation(name: "Sheppard West", coordinate: CLLocationCoordinate2D(latitude: 43.7494, longitude: -79.4622)),
        TTCStation(name: "Wilson", coordinate: CLLocationCoordinate2D(latitude: 43.7341, longitude: -79.4501)),
        TTCStation(name: "Yorkdale", coordinate: CLLocationCoordinate2D(latitude: 43.7247, longitude: -79.4475)),
        TTCStation(name: "Lawrence West", coordinate: CLLocationCoordinate2D(latitude: 43.7155, longitude: -79.4439)),
        TTCStation(name: "Glencairn", coordinate: CLLocationCoordinate2D(latitude: 43.7088, longitude: -79.4407)),
        TTCStation(name: "Eglinton West", coordinate: CLLocationCoordinate2D(latitude: 43.6992, longitude: -79.4361)),
        TTCStation(name: "St. Clair West", coordinate: CLLocationCoordinate2D(latitude: 43.6838, longitude: -79.4151)),
        TTCStation(name: "Dupont", coordinate: CLLocationCoordinate2D(latitude: 43.6745, longitude: -79.4068)),
        TTCStation(name: "Spadina", coordinate: CLLocationCoordinate2D(latitude: 43.6672, longitude: -79.4036)),
        TTCStation(name: "St. George", coordinate: CLLocationCoordinate2D(latitude: 43.6681, longitude: -79.3999)),
        TTCStation(name: "Museum", coordinate: CLLocationCoordinate2D(latitude: 43.6669, longitude: -79.3934)),
        TTCStation(name: "Queen's Park", coordinate: CLLocationCoordinate2D(latitude: 43.6598, longitude: -79.3904)),
        TTCStation(name: "St. Patrick", coordinate: CLLocationCoordinate2D(latitude: 43.6548, longitude: -79.3882)),
        TTCStation(name: "Osgoode", coordinate: CLLocationCoordinate2D(latitude: 43.6508, longitude: -79.3868)),
        TTCStation(name: "St. Andrew", coordinate: CLLocationCoordinate2D(latitude: 43.6476, longitude: -79.3848)),
        TTCStation(name: "Union", coordinate: CLLocationCoordinate2D(latitude: 43.6456, longitude: -79.3803)),
        TTCStation(name: "King", coordinate: CLLocationCoordinate2D(latitude: 43.6490, longitude: -79.3777)),
        TTCStation(name: "Queen", coordinate: CLLocationCoordinate2D(latitude: 43.6524, longitude: -79.3791)),
        TTCStation(name: "Dundas", coordinate: CLLocationCoordinate2D(latitude: 43.6565, longitude: -79.3810)),
        TTCStation(name: "College", coordinate: CLLocationCoordinate2D(latitude: 43.6613, longitude: -79.3831)),
        TTCStation(name: "Wellesley", coordinate: CLLocationCoordinate2D(latitude: 43.6654, longitude: -79.3838)),
        TTCStation(name: "Bloor-Yonge", coordinate: CLLocationCoordinate2D(latitude: 43.6710, longitude: -79.3858)),
        TTCStation(name: "Rosedale", coordinate: CLLocationCoordinate2D(latitude: 43.6768, longitude: -79.3885)),
        TTCStation(name: "Summerhill", coordinate: CLLocationCoordinate2D(latitude: 43.6822, longitude: -79.3905)),
        TTCStation(name: "St. Clair", coordinate: CLLocationCoordinate2D(latitude: 43.6882, longitude: -79.3932)),
        TTCStation(name: "Davisville", coordinate: CLLocationCoordinate2D(latitude: 43.6975, longitude: -79.3972)),
        TTCStation(name: "Eglinton", coordinate: CLLocationCoordinate2D(latitude: 43.7061, longitude: -79.3983)),
        TTCStation(name: "Lawrence", coordinate: CLLocationCoordinate2D(latitude: 43.7252, longitude: -79.4020)),
        TTCStation(name: "York Mills", coordinate: CLLocationCoordinate2D(latitude: 43.7440, longitude: -79.4065)),
        TTCStation(name: "Sheppard-Yonge", coordinate: CLLocationCoordinate2D(latitude: 43.7615, longitude: -79.4109)),
        TTCStation(name: "North York Centre", coordinate: CLLocationCoordinate2D(latitude: 43.7688, longitude: -79.4128)),
        TTCStation(name: "Finch", coordinate: CLLocationCoordinate2D(latitude: 43.7801, longitude: -79.4163))
    ]
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        locationManager.requestWhenInUseAuthorization()
        
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            manager.startUpdatingLocation()
        }
    }
    
    func startTrackingLocation() {
        if locationManager.authorizationStatus == .authorizedWhenInUse || locationManager.authorizationStatus == .authorizedAlways {
            locationManager.startUpdatingLocation()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        self.userLocation = location
        
        if let floor = location.floor {
            self.isUnderground = floor.level < 0
        } else {
            self.isUnderground = false
        }
        
        var closestStation: TTCStation?
        var minDistance: CLLocationDistance = .infinity
        
        for station in stations {
            let stationLoc = CLLocation(latitude: station.coordinate.latitude, longitude: station.coordinate.longitude)
            let distance = location.distance(from: stationLoc)
            if distance < minDistance {
                minDistance = distance
                closestStation = station
            }
        }
        
        DispatchQueue.main.async {
            self.currentStation = closestStation
        }
    }
    
    func startAlarm() {
        guard let target = targetStation else { return }
        
        for region in locationManager.monitoredRegions {
            locationManager.stopMonitoring(for: region)
        }
        
        let region = CLCircularRegion(center: target.coordinate, radius: 600, identifier: target.name)
        region.notifyOnEntry = true
        region.notifyOnExit = false
        
        locationManager.startMonitoring(for: region)
        isAlarmActive = true
    }
    
    func stopAlarm() {
        for region in locationManager.monitoredRegions {
            locationManager.stopMonitoring(for: region)
        }
        isAlarmActive = false
    }
    
    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        if isAlarmActive && region.identifier == targetStation?.name {
            triggerAlarm()
        }
    }
    
    private func triggerAlarm() {
        let content = UNMutableNotificationContent()
        content.title = "Wake the fuck up!"
        content.body = "Arriving soon at \(targetStation?.name ?? "destination")."
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
        
        DispatchQueue.main.async {
            self.isRinging = true
            
            self.playAlarmEffects()
            
            self.alarmTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { _ in
                self.playAlarmEffects()
            }
        }
    }
    
    private func playAlarmEffects() {
        if self.useSound {
            AudioServicesPlaySystemSound(1005)
        }
        if self.useVibration {
            AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
        }
    }
    
    func stopRinging() {
        alarmTimer?.invalidate()
        alarmTimer = nil
        
        isRinging = false
        
        stopAlarm()
        
        targetStation = nil
    }
}
