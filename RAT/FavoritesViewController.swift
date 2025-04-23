//
//  FavoritesViewController.swift
//  RAT
//
//  Created by Rio Simpson on 4/22/25.
//

import UIKit

class FavoritesViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    @IBOutlet weak var tableView: UITableView!
    
    let refreshControl = UIRefreshControl()
    var favorites: [FavoriteRestaurant] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.delegate = self
        tableView.dataSource = self

        refreshControl.addTarget(self, action: #selector(refreshFavorites), for: .valueChanged)
        tableView.refreshControl = refreshControl

        loadFavorites()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadFavorites()
    }
    
    @objc func refreshFavorites() {
        loadFavorites()
        tableView.reloadData()
        refreshControl.endRefreshing()
    }

    func loadFavorites() {
        if let data = UserDefaults.standard.data(forKey: "RAT_APP_Favorites"),
           let stored = try? JSONDecoder().decode([FavoriteRestaurant].self, from: data) {
            favorites = stored
        } else {
            favorites = []
        }
    }
    
    func tableView(_ tableView: UITableView,
                   commit editingStyle: UITableViewCell.EditingStyle,
                   forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            favorites.remove(at: indexPath.row)

            if let encoded = try? JSONEncoder().encode(favorites) {
                UserDefaults.standard.set(encoded, forKey: "RAT_APP_Favorites")
            }

            tableView.deleteRows(at: [indexPath], with: .automatic)
        }
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return favorites.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let restaurant = favorites[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: "FavoritesCell", for: indexPath)

        if let nameLabel = cell.viewWithTag(10) as? UILabel {
            nameLabel.text = restaurant.name
        }

        if let gradeLabel = cell.viewWithTag(11) as? UILabel {
            if let gradeLabel = cell.viewWithTag(11) as? UILabel {
                let rawGrade = restaurant.grade?.uppercased() ?? "N/A"
                let validGrades = ["A", "B", "C"]
                let displayGrade = validGrades.contains(rawGrade) ? rawGrade : "N/A"
                
                gradeLabel.text = displayGrade
                gradeLabel.textAlignment = .center
                gradeLabel.textColor = .white
                gradeLabel.layer.cornerRadius = gradeLabel.frame.width / 2
                gradeLabel.clipsToBounds = true
                gradeLabel.backgroundColor = color(forGrade: displayGrade)
            }
        }

        if let addressLabel = cell.viewWithTag(12) as? UILabel {
            addressLabel.text = restaurant.address
        }

        if let ratingLabel = cell.viewWithTag(13) as? UILabel {
            if let rating = restaurant.rating {
                ratingLabel.text = String(format: "⭐️ %.1f", rating)
            } else {
                ratingLabel.text = "⭐️ N/A"
            }
        }

        return cell
    }
    
    func roundCorners(for cell: UITableViewCell, at indexPath: IndexPath) {
        let total = favorites.count
        let cornerRadius: CGFloat = 12

        var corners: CACornerMask = []

        if total == 1 {
            corners = [.layerMinXMinYCorner, .layerMaxXMinYCorner, .layerMinXMaxYCorner, .layerMaxXMaxYCorner]
        } else if indexPath.row == 0 {
            corners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        } else if indexPath.row == total - 1 {
            corners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]
        }

        cell.contentView.layer.cornerRadius = cornerRadius
        cell.contentView.layer.maskedCorners = corners
        cell.contentView.layer.masksToBounds = true
    }

    func color(forGrade grade: String) -> UIColor {
        switch grade {
        case "A":
            return .systemGreen
        case "B":
            return .systemYellow
        case "C":
            return .systemRed
        default:
            return .gray
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let selectedFavorite = favorites[indexPath.row]
            self.performSegue(withIdentifier: "toDetailsFromFavorites", sender: selectedFavorite)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "toDetailsFromFavorites",
           let destination = segue.destination as? DetailsViewController,
           let favorite = sender as? FavoriteRestaurant {
            destination.name = favorite.name
            destination.address = favorite.address
            destination.camis = favorite.camis
            destination.placeID = favorite.placeID
        }
    }
}
