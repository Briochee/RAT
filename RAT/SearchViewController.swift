//
//  SearchViewController.swift
//  RAT
//
//  Created by Rio Simpson on 4/21/25.
//

import UIKit
import GooglePlaces

class SearchViewController: UIViewController, UISearchBarDelegate, GMSAutocompleteViewControllerDelegate {

    @IBOutlet weak var searchBar: UISearchBar!
    @IBOutlet weak var photoImageView: UIImageView!
    @IBOutlet weak var gradeLabel: UILabel!
    @IBOutlet weak var ratingLabel: UILabel!
    @IBOutlet weak var openStatusLabel: UILabel!
    @IBOutlet weak var infoButton: UIButton!
    @IBOutlet weak var favoriteButton: UIButton!

    var selectedName: String?
    var selectedGrade: String?
    var selectedRating: Double?
    var selectedCamis: String?
    var selectedAddress: String?
    var selectedViolations: [Violation] = []
    var selectedPlaceID: String?
    
    struct GooglePlaceDetails {
        let rating: Double?
        let isOpen: Bool?
        let hours: [String]?
        let photoURL: URL?
    }
    
    func wasCancelled(_ viewController: GMSAutocompleteViewController) {
        dismiss(animated: true)
    }

    func viewController(_ viewController: GMSAutocompleteViewController, didFailAutocompleteWithError error: Error) {
        print("Autocomplete failed: \(error.localizedDescription)")
        dismiss(animated: true)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        favoriteButton.isHidden = true
        infoButton.isHidden = true
        searchBar.backgroundImage = UIImage()
        searchBar.delegate = self

        infoButton.layer.cornerRadius = 8
        infoButton.clipsToBounds = true
        favoriteButton.tintColor = .systemYellow

        // Configure layout
        favoriteButton.setTitle(" Favorite", for: .normal)
        favoriteButton.setImage(UIImage(systemName: "star"), for: .normal)
        favoriteButton.tintColor = .systemYellow
        favoriteButton.setTitleColor(.systemYellow, for: .normal)
        favoriteButton.titleLabel?.numberOfLines = 1
        favoriteButton.titleLabel?.adjustsFontSizeToFitWidth = true
        favoriteButton.titleLabel?.lineBreakMode = .byTruncatingTail
        favoriteButton.semanticContentAttribute = .forceLeftToRight
        favoriteButton.contentHorizontalAlignment = .center
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        if selectedCamis != nil {
            updateFavoriteButtonUI()
        }
    }
    
    func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
        let autocompleteVC = GMSAutocompleteViewController()
        autocompleteVC.delegate = self

        let filter = GMSAutocompleteFilter()
        filter.types = ["establishment"]
        filter.countries = ["US"]
        autocompleteVC.autocompleteFilter = filter

        present(autocompleteVC, animated: true)
    }

    func viewController(_ viewController: GMSAutocompleteViewController, didAutocompleteWith place: GMSPlace) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            self.dismiss(animated: true)

            self.searchBar.text = place.name
            self.searchBar.resignFirstResponder()

            let name = place.name ?? "Unnamed Restaurant"
            self.selectedName = name
            self.photoImageView.image = UIImage(systemName: "photo")

            if let placeID = place.placeID {
                self.selectedPlaceID = placeID
                self.fetchPlaceDetails(for: placeID) { details in
                    DispatchQueue.main.async {
                        if let details = details {
                            if let rating = details.rating {
                                self.ratingLabel.text = "⭐️ Rating: \(rating)"
                            } else {
                                self.ratingLabel.text = "⭐️ Rating: N/A"
                            }

                            if let isOpen = details.isOpen {
                                self.openStatusLabel.text = isOpen ? "🟢 Open Now" : "🔴 Closed"
                            } else {
                                self.openStatusLabel.text = "⏳ Status Unknown"
                            }

                            if let imageURL = details.photoURL {
                                URLSession.shared.dataTask(with: imageURL) { data, _, _ in
                                    if let data = data {
                                        DispatchQueue.main.async {
                                            self.photoImageView.image = UIImage(data: data)
                                        }
                                    }
                                }.resume()
                            }
                        }
                    }
                }

                let building = self.getComponent(from: place, type: "street_number") ?? ""
                let zip = self.getComponent(from: place, type: "postal_code") ?? ""

                self.favoriteButton.isHidden = false
                self.infoButton.isHidden = false
                self.fetchNYCInspectionGrade(name: name, building: building, zip: zip)
            }
        }
    }

    func fetchPlaceDetails(for placeID: String, completion: @escaping (GooglePlaceDetails?) -> Void) {
        guard let url = Queries.googlePlaceDetailsURL(for: placeID, apiKey: AppConfig.googleAPIKey) else {
            completion(nil)
            return
        }

        URLSession.shared.dataTask(with: url) { data, _, error in
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let result = json["result"] as? [String: Any] else {
                completion(nil)
                return
            }

            let rating = result["rating"] as? Double
            DispatchQueue.main.async {
                self.selectedRating = rating
            }
            let openingHours = result["opening_hours"] as? [String: Any]
            let isOpen = openingHours?["open_now"] as? Bool
            let hours = openingHours?["weekday_text"] as? [String]
            var photoURL: URL? = nil
            
            self.selectedAddress = result["formatted_address"] as? String
            

            if let photos = result["photos"] as? [[String: Any]],
               let landscapePhoto = photos.first(where: {
                   if let width = $0["width"] as? Int,
                      let height = $0["height"] as? Int {
                       return width > height
                   }
                   return false
               }),
               let ref = landscapePhoto["photo_reference"] as? String {
                photoURL = Queries.googlePhotoURL(for: ref, apiKey: AppConfig.googleAPIKey)
            }

            completion(GooglePlaceDetails(rating: rating, isOpen: isOpen, hours: hours, photoURL: photoURL))
        }.resume()
    }

    func fetchNYCInspectionGrade(name: String, building: String, zip: String) {
        guard let initialURL = Queries.nycRestaurantSearchURL(name: name, building: building, zip: nil) else {
            gradeLabel.text = "NYC Grade: N/A"
            return
        }

        URLSession.shared.dataTask(with: initialURL) { data, _, _ in
            guard let data = data,
                  let results = try? JSONDecoder().decode([Restaurant].self, from: data) else {
                DispatchQueue.main.async {
                    self.gradeLabel.text = "NYC Grade: N/A"
                }
                return
            }

            let filtered = results.filter { $0.zipcode == zip && $0.grade != nil }
            let mostRecent = (filtered.isEmpty ? results : filtered)
                .filter { $0.grade != nil }
                .sorted { ($0.grade_date ?? "") > ($1.grade_date ?? "") }
                .first

            if results.isEmpty {
                self.fallbackSearchUsingBuildingOnly(name: name, building: building, zip: zip)
                return
            }

            self.selectedViolations = results.map {
                Violation(
                    date: $0.inspection_date ?? "Unknown Date",
                    description: $0.violation_description ?? "No description provided.",
                    criticalFlag: $0.critical_flag,
                    score: $0.score
                )
            }

            DispatchQueue.main.async {
                if let match = mostRecent, let dba = match.dba, let grade = match.grade {
                    self.gradeLabel.text = "Result for: \(dba.capitalized)\nCurrent Grade: \(grade)"
                    self.selectedGrade = grade
                    self.selectedCamis = match.camis

                    self.updateFavoriteButtonUI()
                } else {
                    self.gradeLabel.text = "NYC Grade: N/A"
                }
            }
        }.resume()
    }

    func fallbackSearchUsingBuildingOnly(name: String, building: String, zip: String) {
        guard let url = Queries.nycRestaurantSearchURL(name: nil, building: building, zip: nil) else {
            DispatchQueue.main.async {
                self.gradeLabel.text = "NYC Grade: N/A"
            }
            return
        }

        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data = data,
                  let results = try? JSONDecoder().decode([Restaurant].self, from: data) else {
                DispatchQueue.main.async {
                    self.gradeLabel.text = "NYC Grade: N/A"
                }
                return
            }

            let googleWords = tokenize(name)

            let bestMatch = results
                .filter { $0.grade != nil }
                .max(by: { lhs, rhs in
                    let lhsScore = tokenize(lhs.dba ?? "").intersection(googleWords).count
                    let rhsScore = tokenize(rhs.dba ?? "").intersection(googleWords).count
                    return lhsScore < rhsScore
                })

            self.selectedViolations = results.map {
                Violation(
                    date: $0.inspection_date ?? "Unknown Date",
                    description: $0.violation_description ?? "No description provided.",
                    criticalFlag: $0.critical_flag,
                    score: $0.score
                )
            }

            DispatchQueue.main.async {
                if let match = bestMatch, let dba = match.dba, let grade = match.grade {
                    self.gradeLabel.text = "Result for: \(dba.capitalized)\nCurrent Grade: \(grade)"
                    self.selectedGrade = match.grade
                    self.selectedCamis = match.camis
                    self.selectedAddress = "\(match.building ?? "") \(match.street ?? ""), \(match.zipcode ?? "")"
                } else {
                    self.gradeLabel.text = "NYC Grade: N/A"
                }
                
                self.updateFavoriteButtonUI()
            }
        }.resume()
    }
    
    func updateFavoriteButtonUI() {
        let isFavorited = getFavorites().contains { $0.camis == selectedCamis }
        let title = isFavorited ? " Unworthy" : " Worthy"
        let image = isFavorited ? UIImage(systemName: "star.fill") : UIImage(systemName: "star")
        favoriteButton.setTitle(title, for: .normal)
        favoriteButton.setImage(image, for: .normal)
    }

    @IBAction func favoriteButtonTapped(_ sender: UIButton) {
        guard let name = selectedName,
              let grade = selectedGrade,
              let rating = selectedRating,
              let camis = selectedCamis,
              let address = selectedAddress,
              let placeID = selectedPlaceID else {  // <-- make sure this property exists
            return
        }

        var favorites = getFavorites()

        if let index = favorites.firstIndex(where: { $0.camis == camis }) {
            favorites.remove(at: index)
        } else {
            let favorite = FavoriteRestaurant(
                name: name,
                grade: grade,
                rating: rating,
                camis: camis,
                address: address,
                placeID: placeID
            )
            favorites.append(favorite)
        }

        if let encoded = try? JSONEncoder().encode(favorites) {
            UserDefaults.standard.set(encoded, forKey: "RAT_APP_Favorites")
        }

        updateFavoriteButtonUI()
    }
    
    func getFavorites() -> [FavoriteRestaurant] {
        guard let data = UserDefaults.standard.data(forKey: "RAT_APP_Favorites"),
              let favorites = try? JSONDecoder().decode([FavoriteRestaurant].self, from: data) else {
            return []
        }
        return favorites
    }

    func getComponent(from place: GMSPlace, type: String) -> String? {
        return place.addressComponents?.first(where: { $0.types.contains(type) })?.name
    }
    
    @IBAction func moreInfoButtonPressed(_ sender: UIButton) {
            self.performSegue(withIdentifier: "toDetails", sender: self)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "toDetails",
           let destination = segue.destination as? DetailsViewController {
            destination.camis = selectedCamis
            destination.name = selectedName
            destination.address = selectedAddress
            destination.placeID = selectedPlaceID
        }
    }
}

func tokenize(_ input: String) -> Set<String> {
    return Set(
        input.uppercased()
            .replacingOccurrences(of: "’", with: "'")
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
    )
}
