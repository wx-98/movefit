import CoreLocation
import Foundation

struct RouteAccumulator {
    private(set) var locations: [CLLocation] = []
    private(set) var distanceMeters = 0.0

    var summary: WorkoutLocationSummary {
        WorkoutLocationSummary(
            route: locations.map(\.coordinate),
            distance: distanceMeters > 0
                ? Measurement(value: distanceMeters, unit: UnitLength.meters)
                : nil
        )
    }

    mutating func reset() {
        locations.removeAll(keepingCapacity: true)
        distanceMeters = 0
    }

    mutating func append(_ location: CLLocation) {
        guard location.horizontalAccuracy >= 0, location.horizontalAccuracy <= 50 else { return }
        guard let previous = locations.last else {
            locations.append(location)
            return
        }
        guard location.timestamp >= previous.timestamp else { return }

        let distance = location.distance(from: previous)
        guard distance >= 2, distance <= 200 else { return }
        locations.append(location)
        distanceMeters += distance
    }
}
