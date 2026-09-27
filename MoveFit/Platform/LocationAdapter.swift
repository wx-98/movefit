import CoreLocation

final class LocationAdapter: NSObject, LocationProviding, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var accumulator = RouteAccumulator()

    var authorizationStatus: CLAuthorizationStatus { manager.authorizationStatus }

    override init() {
        super.init()
        manager.delegate = self
        manager.activityType = .fitness
        manager.desiredAccuracy = kCLLocationAccuracyBest
    }

    func requestWhenInUseAuthorization() {
        guard manager.authorizationStatus == .notDetermined else { return }
        manager.requestWhenInUseAuthorization()
    }

    func start() {
        accumulator.reset()
        manager.startUpdatingLocation()
    }

    func pause() {
        manager.stopUpdatingLocation()
    }

    func resume() {
        manager.startUpdatingLocation()
    }

    func snapshot() -> WorkoutLocationSummary {
        accumulator.summary
    }

    func stop() -> WorkoutLocationSummary {
        manager.stopUpdatingLocation()
        return accumulator.summary
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        locations.forEach { accumulator.append($0) }
    }
}
