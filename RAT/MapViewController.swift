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
import Contacts

class MapViewController: UIViewController, CLLocationManagerDelegate, MKMapViewDelegate {

    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var radiusSlider: UISlider!
    @IBOutlet weak var radiusLabel: UILabel!
    @IBOutlet weak var recenterButton: UIButton!

    let locationManager = CLLocationManager()
    var currentLocation: CLLocationCoordinate2D?
    var selectedRestaurantPin: [String: String] = [:]
    
    struct TempRestaurantDetails {
        let name: String
        let address: String?
        let placeID: String?
        var camis: String?
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        mapView.delegate = self
        locationManager.delegate = self

        mapView.showsUserLocation = true
        radiusSlider.minimumValue = 250
        radiusSlider.maximumValue = 5000
        radiusSlider.value = 1000
        radiusLabel.text = "Radius: \(String(format: "%.0f", radiusSlider.value)) m"

        recenterButton.layer.cornerRadius = 8
        recenterButton.clipsToBounds = true

        view.bringSubviewToFront(radiusSlider)
        view.bringSubviewToFront(radiusLabel)
        view.bringSubviewToFront(recenterButton)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        locationManager.stopUpdatingLocation()
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
    
    func region(for location: CLLocationCoordinate2D, meters: Double) -> MKCoordinateRegion {
        let factor: Double = 1
        return MKCoordinateRegion(center: location, latitudinalMeters: meters * factor, longitudinalMeters: meters * factor)
    }

    func centerMap(on coordinate: CLLocationCoordinate2D) {
        let region = region(for: coordinate, meters: Double(radiusSlider.value))
        mapView.setRegion(region, animated: true)
    }
    
    @IBAction func sliderDidEnd(_ sender: UISlider) {
        let meters = Double(sender.value)
        radiusLabel.text = "Radius: \(String(format: "%.0f", meters)) m"

        fetchNearbyRestaurants()
    }

    @IBAction func radiusChanged(_ sender: UISlider) {
        radiusLabel.text = "Radius: \(String(format: "%.0f", sender.value)) m"
        
        if let location = currentLocation {
            let region = region(for: location, meters: Double(sender.value))
            mapView.setRegion(region, animated: true)
        }
    }

    @IBAction func recenterTapped(_ sender: UIButton) {
        if let location = currentLocation {
            radiusSlider.value = 1000
            radiusLabel.text = "Radius: 1000 m"
            
            let region = region(for: location, meters: 1000)
            mapView.setRegion(region, animated: true)

            fetchNearbyRestaurants()
        }
    }
    
    func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
        for annotation in mapView.annotations {
            if let view = mapView.view(for: annotation) as? MKMarkerAnnotationView {
                view.glyphTintColor = nil
            }
        }
    }
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        if annotation is MKUserLocation {
            return nil
        }

        let identifier = "restaurant"
        var view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView

        if view == nil {
            view = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
            view?.canShowCallout = true
        } else {
            view?.annotation = annotation
        }
        
        view?.markerTintColor = .systemRed
        view?.displayPriority = .required
        view?.glyphTintColor = nil

        return view
    }
    
    func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
        guard let annotation = view.annotation else { return }

        let name = annotation.title ?? "Unknown"
        let address = annotation.subtitle ?? "Address unavailable"

        selectedRestaurantPin["name"] = name ?? ""
        selectedRestaurantPin["address"] = address ?? ""

        fetchPlaceDetails(name: name ?? "", address: address ?? "")
    }

    func fetchNearbyRestaurants() {
        guard let location = currentLocation else { return }
        let region = region(for: location, meters: Double(radiusSlider.value))
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = "restaurant"
        request.region = region

        let search = MKLocalSearch(request: request)
        search.start { (response, error) in
            guard let response = response else { return }

            self.mapView.removeAnnotations(self.mapView.annotations)
            for item in response.mapItems {
                guard let name = item.name else { continue }
                let coordinate = item.placemark.coordinate
                let address = CNPostalAddressFormatter.string(from: item.placemark.postalAddress ?? CNPostalAddress(), style: .mailingAddress)

                let annotation = RestaurantAnnotation(
                    title: name,
                    subtitle: address,
                    coordinate: coordinate
                )
                self.mapView.addAnnotation(annotation)
            }
        }
    }

    func fetchPlaceDetails(name: String, address: String) {
        let query = "\(name) \(address)"
        
        guard let findPlaceURL = Queries.googleFindPlaceURL(for: query, sender: "MapViewController") else {
            return
        }

        URLSession.shared.dataTask(with: findPlaceURL) { data, _, _ in
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let candidates = json["candidates"] as? [[String: Any]],
                  let firstCandidate = candidates.first,
                  let placeID = firstCandidate["place_id"] as? String else {
                return
            }

            // Now get full place details using place ID
            guard let detailsURL = Queries.googlePlaceDetailsURL(for: placeID, sender: "MapViewController") else {
                return
            }

            URLSession.shared.dataTask(with: detailsURL) { data, _, _ in
                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let result = json["result"] as? [String: Any] else {
                    return
                }

                let googleName = result["name"] as? String ?? name
                let formattedAddress = result["formatted_address"] as? String
                let rating = result["rating"] as? Double
                let components = result["address_components"] as? [[String: Any]]

                let buildingNumber = components?
                    .first(where: { ($0["types"] as? [String])?.contains("street_number") == true })?["short_name"] as? String
                
                let zip = components?
                    .first(where: { ($0["types"] as? [String])?.contains("postal_code") == true })?["short_name"] as? String

                let details = TempRestaurantDetails(
                    name: googleName,
                    address: formattedAddress,
                    placeID: placeID,
                    camis: nil
                )

                DispatchQueue.main.async {
                    let stars = rating != nil ? "⭐️ \(String(format: "%.1f", rating!))" : "⭐️ N/A"
                    let addressText = formattedAddress ?? "Address unavailable"

                    let alert = UIAlertController(title: googleName, message: "\(addressText)\n\(stars)", preferredStyle: .alert)

                    alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
                    alert.addAction(UIAlertAction(title: "View Details", style: .default, handler: { _ in
                        let sanitized = buildingNumber?.replacingOccurrences(of: "-", with: "") ?? ""
                        self.fetchNYCInspectionGrade(name: googleName, building: sanitized, zip: zip ?? "", payload: details)
                    }))

                    self.present(alert, animated: true)
                }

            }.resume()
        }.resume()
    }
    
    func fetchNYCInspectionGrade(name: String, building: String, zip: String, payload: TempRestaurantDetails) {
        // print("Fetch NYC Inspection Grade Called")
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
                    var updatedPayload = payload
                    updatedPayload.camis = match.camis
                    self.performSegue(withIdentifier: "toDetailsFromMap", sender: updatedPayload)
                } else {
                    let sanitizedBuilding = building.replacingOccurrences(of: "-", with: "")
                    self.fallbackSearch(name: name, building: sanitizedBuilding, zip: zip, payload: payload)
                }
            }
        }.resume()
    }
    
    func fallbackSearch(name: String, building: String, zip: String, payload: TempRestaurantDetails) {
        // print("Fallback Called")
        guard let url = Queries.nycRestaurantSearchURL(name: nil, building: building, zip: nil) else {
            return
        }
        
        // print(url)

        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data = data,
                  let results = try? JSONDecoder().decode([Restaurant].self, from: data) else {
                return
            }
            
            let googleWords = tokenize(name)
            let filtered = results.filter { $0.zipcode == zip && $0.grade != nil }
            let source = filtered.isEmpty ? results : filtered

            let sortedByDate = source
                .filter { $0.grade != nil }
                .sorted { ($0.grade_date ?? "") > ($1.grade_date ?? "") }

            let bestMatch = sortedByDate.max(by: { lhs, rhs in
                let lhsScore = tokenize(lhs.dba ?? "").intersection(googleWords).count
                let rhsScore = tokenize(rhs.dba ?? "").intersection(googleWords).count
                return lhsScore < rhsScore
            })

            DispatchQueue.main.async {
                if let match = bestMatch {
                    var updatedPayload = payload
                    updatedPayload.camis = match.camis
                    self.performSegue(withIdentifier: "toDetailsFromMap", sender: updatedPayload)
                } else {
                    let failAlert = UIAlertController(
                        title: "No Match",
                        message: "Couldn't find inspection data.",
                        preferredStyle: .alert
                    )
                    failAlert.addAction(UIAlertAction(title: "OK", style: .default))
                    self.present(failAlert, animated: true)
                }
            }
        }.resume()
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
