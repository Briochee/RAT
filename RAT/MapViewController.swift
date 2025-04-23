//
//  MapViewController.swift
//  RAT
//
//  Created by Rio Simpson on 4/22/25.
//
import UIKit
import MapKit
import CoreLocation
import CoreLocationUI

class MapViewController: UIViewController, CLLocationManagerDelegate, MKMapViewDelegate {

    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var radiusSlider: UISlider!
    @IBOutlet weak var radiusLabel: UILabel!
    @IBOutlet weak var recenterButton: UIButton!

    let locationManager = CLLocationManager()
    var currentLocation: CLLocationCoordinate2D?
    var matchedCamis: String?
    var nearbyRestaurantInfo: [String: (rating: Double?, formattedAddress: String?, placeID: String)] = [:]

    override func viewDidLoad() {
        mapView.delegate = self
        super.viewDidLoad()

        locationManager.delegate = self
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()

        mapView.showsUserLocation = true
        radiusSlider.minimumValue = 0.25
        radiusSlider.maximumValue = 5.0
        radiusSlider.value = 0.25
        radiusLabel.text = "Radius: \(String(format: "%.2f", radiusSlider.value)) mi"

        recenterButton.layer.cornerRadius = 8
        recenterButton.clipsToBounds = true
        
        view.bringSubviewToFront(radiusSlider)
        view.bringSubviewToFront(radiusLabel)
        view.bringSubviewToFront(recenterButton)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        radiusLabel.layer.cornerRadius = radiusLabel.frame.height / 2
        radiusLabel.clipsToBounds = true
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        currentLocation = location.coordinate
        centerMap(on: location.coordinate)
        fetchNearbyRestaurants()
        locationManager.stopUpdatingLocation()
    }

    func centerMap(on coordinate: CLLocationCoordinate2D) {
        let region = MKCoordinateRegion(center: coordinate, latitudinalMeters: 500, longitudinalMeters: 500)
        mapView.setRegion(region, animated: true)
    }
    
    @IBAction func sliderDidEnd(_ sender: UISlider) {
        let miles = Double(sender.value)
        radiusLabel.text = "Radius: \(String(format: "%.2f", miles)) mi"

        fetchNearbyRestaurants()
    }

    @IBAction func radiusChanged(_ sender: UISlider) {
        let miles = Double(sender.value)
        radiusLabel.text = "Radius: \(String(format: "%.2f", miles)) mi"
        
        if let location = currentLocation {
            let meters = miles * 1609.34
            let region = MKCoordinateRegion(center: location, latitudinalMeters: meters * 2, longitudinalMeters: meters * 2)
            mapView.setRegion(region, animated: true)
        }
    }

    @IBAction func recenterTapped(_ sender: UIButton) {
        if let location = currentLocation {
            radiusSlider.value = 0.25
            radiusLabel.text = "Radius: 0.25 mi"

            let meters = 1.0 * 1609.34
            let region = MKCoordinateRegion(center: location, latitudinalMeters: meters * 2, longitudinalMeters: meters * 2)
            mapView.setRegion(region, animated: true)

            fetchNearbyRestaurants()
        }
    }

    func fetchNearbyRestaurants() {
        guard let location = currentLocation else { return }
        let radiusMiles = radiusSlider.value
        let radiusMeters = Int(radiusMiles * 1609.34)

        guard let url = Queries.googleNearbySearchURL(location: location, radius: radiusMeters) else { return }

        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let results = json["results"] as? [[String: Any]] else { return }

            DispatchQueue.main.async {
                self.mapView.removeAnnotations(self.mapView.annotations)
                self.nearbyRestaurantInfo.removeAll()

                for result in results {
                    guard let name = result["name"] as? String,
                          let geometry = result["geometry"] as? [String: Any],
                          let location = geometry["location"] as? [String: Any],
                          let lat = location["lat"] as? CLLocationDegrees,
                          let lng = location["lng"] as? CLLocationDegrees,
                          let placeID = result["place_id"] as? String else { continue }

                    self.fetchPlaceDetails(for: placeID, name: name, lat: lat, lng: lng)
                }
            }
        }.resume()
    }

    func fetchPlaceDetails(for placeID: String, name: String, lat: Double, lng: Double) {
        guard let url = Queries.googlePlaceDetailsURL(for: placeID, apiKey: AppConfig.googleAPIKey) else {
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let result = json["result"] as? [String: Any] else {
                return
            }

            let rating = result["rating"] as? Double
            let formattedAddress = result["formatted_address"] as? String

            DispatchQueue.main.async {
                self.nearbyRestaurantInfo[name] = (rating: rating, formattedAddress: formattedAddress, placeID: placeID)

                let annotation = MKPointAnnotation()
                annotation.title = name
                annotation.subtitle = formattedAddress
                annotation.coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lng)
                self.mapView.addAnnotation(annotation)
            }
        }.resume()
    }

    func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
        guard let annotation = view.annotation,
              let name = annotation.title ?? nil,
              let info = nearbyRestaurantInfo[name] else { return }

        let alert = UIAlertController(title: name, message: nil, preferredStyle: .alert)

        let stars = info.rating != nil ? "⭐️ \(String(format: "%.1f", info.rating!))" : "⭐️ N/A"
        let address = info.formattedAddress ?? "Address unavailable"
        alert.message = "\(address)\n\(stars)"

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "View Details", style: .default, handler: { _ in
            self.fetchDOHData(for: name, address: address)
        }))

        present(alert, animated: true)
    }
    
    func fetchDOHData(for name: String, address: String) {
        let tokens = tokenize(name)

        // Only use the name in the query — no building number logic
        guard let dohURL = Queries.fetchNYCDataFromMap(dba: name) else {
            return
        }

        URLSession.shared.dataTask(with: dohURL) { data, _, _ in
            guard let data = data,
                  let results = try? JSONDecoder().decode([Restaurant].self, from: data) else {
                return
            }

            let bestMatch = results.first(where: { restaurant in
                guard let dba = restaurant.dba else { return false }
                let dbaTokens = tokenize(dba)
                return !tokens.isDisjoint(with: dbaTokens)
            })

            DispatchQueue.main.async {
                if let match = bestMatch {
                    self.matchedCamis = match.camis

                    let payload = TempRestaurantDetails(
                        name: match.dba ?? name,
                        address: address,
                        placeID: self.nearbyRestaurantInfo[name]?.placeID,
                        camis: match.camis
                    )

                    self.performSegue(withIdentifier: "toDetailsFromMap", sender: payload)
                } else {
                    let failAlert = UIAlertController(title: "No Match", message: "Couldn't find inspection data.", preferredStyle: .alert)
                    failAlert.addAction(UIAlertAction(title: "OK", style: .default))
                    self.present(failAlert, animated: true)
                }
            }
        }.resume()
    }
    
    struct TempRestaurantDetails {
        let name: String
        let address: String?
        let placeID: String?
        let camis: String?
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "toDetailsFromMap",
           let destination = segue.destination as? DetailsViewController,
           let payload = sender as? TempRestaurantDetails {

            destination.name = payload.name
            destination.address = payload.address
            destination.placeID = payload.placeID
            destination.camis = payload.camis
        }
    }
}
