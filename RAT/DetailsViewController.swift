//
//  DetailsViewController.swift
//  RAT
//
//  Created by Rio Simpson on 4/22/25.
//

import UIKit

class DetailsViewController: UIViewController {
    var camis: String?
    var name: String?
    var address: String?
    var placeID: String?
    var selectedRating: Double?
    var selectedGrade: String?
    var selectedCamis: String?
    var selectedAddress: String?

    @IBOutlet weak var photoImageView: UIImageView!
    @IBOutlet weak var ratingLabel: UILabel!
    @IBOutlet weak var openStatusLabel: UILabel!
    @IBOutlet weak var addressLabel: UILabel!
    @IBOutlet weak var gradeLabel: UILabel!
    @IBOutlet weak var hoursTextView: UITextView!
    @IBOutlet weak var favoriteButton: UIButton!
    @IBOutlet weak var viewInspectionsButton: UIButton!

    var selectedViolations: [Violation] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        
        guard let camis = camis,
                let _ = name,
                  let address = address,
                  let placeID = placeID else {
                return
            }

        selectedCamis = camis
        selectedAddress = address
        selectedGrade = nil

        favoriteButton.tintColor = .systemYellow
        favoriteButton.setTitleColor(.systemYellow, for: .normal)
        favoriteButton.semanticContentAttribute = .forceLeftToRight
        favoriteButton.contentHorizontalAlignment = .center
        favoriteButton.titleLabel?.adjustsFontSizeToFitWidth = true
        favoriteButton.titleLabel?.lineBreakMode = .byTruncatingTail
        
        viewInspectionsButton.layer.cornerRadius = 8
        viewInspectionsButton.clipsToBounds = true

        fetchNYCInspectionGrade(for: camis)
        fetchPlaceDetails(for: placeID)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateFavoriteButtonUI()
    }

    func fetchNYCInspectionGrade(for camis: String) {
        guard let url = Queries.fetchNYCDataCamis(camis) else { return }

        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data = data,
                  let results = try? JSONDecoder().decode([Restaurant].self, from: data) else {
                return
            }

            let sorted = results.sorted { ($0.grade_date ?? "") > ($1.grade_date ?? "") }
            let mostRecent = sorted.first

            self.selectedViolations = Dictionary(grouping: results, by: { $0.inspection_date ?? "Unknown Date" })
                .map { (date, group) in
                    let descriptions = group.compactMap { $0.violation_description }.joined(separator: " ||| ")
                    let criticalFlag = group.contains { $0.critical_flag == "Critical" } ? "Critical" : "Not Critical"
                    let highestScore = group.compactMap { $0.score.flatMap(Int.init) }.max().map(String.init)

                    return Violation(
                        date: date,
                        description: descriptions,
                        criticalFlag: criticalFlag,
                        score: highestScore
                    )
                }
                .sorted {
                    let formatter = DateFormatter()
                    formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS"
                    let d1 = formatter.date(from: $0.date) ?? Date.distantPast
                    let d2 = formatter.date(from: $1.date) ?? Date.distantPast
                    return d1 > d2
                }
            
            // print(self.selectedViolations)

            DispatchQueue.main.async {
                if let restaurant = mostRecent {
                    let rawGrade = restaurant.grade?.uppercased() ?? "N/A"
                    let validGrades = ["A", "B", "C"]
                    let displayGrade = validGrades.contains(rawGrade) ? rawGrade : "N/A"

                    self.selectedGrade = displayGrade
                    self.addressLabel.text = self.address ?? "Address Unavailable"
                    self.gradeLabel.text = displayGrade
                    self.gradeLabel.textAlignment = .center
                    self.gradeLabel.textColor = .white
                    self.gradeLabel.backgroundColor = self.color(for: displayGrade)
                } else {
                    self.addressLabel.text = self.address
                }
            }
        }.resume()
    }

    func fetchPlaceDetails(for placeID: String) {
        guard let url = Queries.googlePlaceDetailsURL(for: placeID, sender: "DetailsViewController") else { return }

        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let result = json["result"] as? [String: Any] else {
                return
            }

            let rating = result["rating"] as? Double
            self.selectedRating = rating
            let openingHours = result["opening_hours"] as? [String: Any]
            let isOpen = openingHours?["open_now"] as? Bool
            let hours = openingHours?["weekday_text"] as? [String]
            var photoURL: URL? = nil

            if let photos = result["photos"] as? [[String: Any]],
               let ref = photos.first?["photo_reference"] as? String {
                photoURL = Queries.googlePhotoURL(for: ref, sender: "DetailsViewController")
            }

            DispatchQueue.main.async {
                self.ratingLabel.text = rating != nil ? "⭐️ Rating: \(rating!)" : "⭐️ Rating: N/A"
                self.openStatusLabel.text = isOpen != nil ? (isOpen! ? "🟢 Open Now" : "🔴 Closed") : "⏳ Status Unknown"
                self.hoursTextView.text = hours != nil ? "Hours:\n" + hours!.joined(separator: "\n") : "Hours unavailable"

                if let imageURL = photoURL {
                    URLSession.shared.dataTask(with: imageURL) { data, _, _ in
                        if let data = data {
                            DispatchQueue.main.async {
                                self.photoImageView.image = UIImage(data: data)
                            }
                        }
                    }.resume()
                }
            }
        }.resume()
    }

    func updateFavoriteButtonUI() {
        let isFavorited = getFavorites().contains { $0.camis == camis }
        let title = isFavorited ? " Unworthy" : " Worthy"
        let image = isFavorited ? UIImage(systemName: "star.fill") : UIImage(systemName: "star")
        favoriteButton.setTitle(title, for: .normal)
        favoriteButton.setImage(image, for: .normal)
    }

    @IBAction func favoriteButtonTapped(_ sender: UIButton) {
        guard let name = name,
                  let grade = selectedGrade,
                  let rating = selectedRating,
                  let camis = camis,
                  let address = address,
                  let placeID = placeID else {
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

    func color(for grade: String) -> UIColor {
        switch grade.uppercased() {
        case "A": return .systemGreen
        case "B": return .systemYellow
        case "C": return .systemRed
        default: return .gray
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        gradeLabel.layer.cornerRadius = gradeLabel.frame.width / 2
        gradeLabel.clipsToBounds = true
    }
    
    @IBAction func viewInspectionsButtonTapped(_ sender: UIButton) {
        performSegue(withIdentifier: "toInspections", sender: self)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
            if segue.identifier == "toInspections",
               let destination = segue.destination as? InspectionsViewController {
                destination.restaurantName = name
                destination.nycGrade = selectedGrade
                destination.googleRating = selectedRating
                destination.violations = selectedViolations
            }
        }
}
