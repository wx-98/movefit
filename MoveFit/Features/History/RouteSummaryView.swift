import MapKit
import SwiftUI

struct RouteSummaryView: View {
    @EnvironmentObject private var model: AppModel
    let workout: WorkoutRecord

    var body: some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppSpacing.medium) {
                HStack {
                    Label(model.localizer.text("最近路线"), systemImage: "map.fill")
                        .font(.headline)
                    Spacer()
                    Text(model.localizer.text(workout.type.rawValue))
                        .foregroundColor(.secondary)
                }
                RouteMapView(coordinates: workout.route)
                    .frame(height: 180)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .allowsHitTesting(false)
                HStack {
                    Text(AppFormat.distance(workout.distance))
                    Spacer()
                    Text(AppFormat.duration(workout.duration))
                }
                .font(.subheadline)
            }
        }
    }
}

private struct RouteMapView: UIViewRepresentable {
    let coordinates: [CLLocationCoordinate2D]

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.isPitchEnabled = false
        mapView.isRotateEnabled = false
        mapView.pointOfInterestFilter = .excludingAll
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        mapView.removeOverlays(mapView.overlays)
        guard coordinates.count > 1 else { return }
        let line = MKPolyline(coordinates: coordinates, count: coordinates.count)
        mapView.addOverlay(line)
        mapView.setVisibleMapRect(
            line.boundingMapRect,
            edgePadding: UIEdgeInsets(top: 24, left: 24, bottom: 24, right: 24),
            animated: false
        )
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            guard let line = overlay as? MKPolyline else { return MKOverlayRenderer(overlay: overlay) }
            let renderer = MKPolylineRenderer(polyline: line)
            renderer.strokeColor = UIColor(AppColor.primary)
            renderer.lineWidth = 5
            renderer.lineCap = .round
            return renderer
        }
    }
}
