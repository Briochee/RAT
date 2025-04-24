//
//  InspectionsViewController.swift
//  RAT
//
//  Created by Rio Simpson on 4/21/25.
//

import UIKit

class InspectionsViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    var restaurantName: String?
    var nycGrade: String?
    var googleRating: Double?
    var violations: [Violation] = []

    @IBOutlet weak var gradeLabel: UILabel!
    @IBOutlet weak var starStackView: UIStackView!
    @IBOutlet weak var tableView: UITableView!

    override func viewDidLoad() {
        super.viewDidLoad()
        title = restaurantName
        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 150
        setupGradeCircle()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        gradeLabel.layer.cornerRadius = gradeLabel.frame.width / 2
        gradeLabel.clipsToBounds = true
        setupStars()
    }

    func setupGradeCircle() {
        let rawGrade = nycGrade?.uppercased() ?? ""
        let validGrades = ["A", "B", "C"]
        let grade = validGrades.contains(rawGrade) ? rawGrade : "N/A"
        gradeLabel.text = grade
        gradeLabel.textAlignment = .center
        gradeLabel.backgroundColor = color(for: grade)
        gradeLabel.textColor = .white
    }

    func setupStars() {
        let rating = Int((googleRating ?? 0).rounded())
        for (index, view) in starStackView.arrangedSubviews.enumerated() {
            if let imageView = view as? UIImageView {
                imageView.image = UIImage(systemName: index < rating ? "star.fill" : "star")
                imageView.tintColor = .systemYellow
            }
        }
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return violations.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let violation = violations[indexPath.row]

        let cell = tableView.dequeueReusableCell(withIdentifier: "InspectionDetails", for: indexPath)

        // Set the date label
        if let dateLabel = cell.viewWithTag(1) as? UILabel {
            dateLabel.text = formatDate(from: violation.date)
        }

        // Set the score label
        if let scoreLabel = cell.viewWithTag(2) as? UILabel {
            let rawScore = Int(violation.score ?? "") ?? -1
            let displayScore = rawScore >= 0 ? 100 - rawScore : -1
            scoreLabel.text = displayScore >= 0 ? "\(displayScore)" : "N/A"
            scoreLabel.backgroundColor = color(forScore: displayScore)
            scoreLabel.layer.cornerRadius = scoreLabel.frame.width / 2
            scoreLabel.clipsToBounds = true
        }

        // Set the violations description text
        if let textView = cell.viewWithTag(300) as? UITextView {
            let details = violation.description
                .components(separatedBy: " ||| ")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .joined(separator: "\n• ")
            textView.text = "• \(details)"
        }

        return cell
    }

    func color(forScore score: Int) -> UIColor {
        let clamped = max(0, min(score, 100))
        let hue: CGFloat
        switch clamped {
        case 0...27:
            hue = 0.0
        case 28...86:
            hue = 0.0 + (0.15 * CGFloat(clamped - 28) / 58)
        case 87...100:
            hue = 0.15 + (0.18 * CGFloat(clamped - 87) / 13)
        default:
            hue = 0.0
        }
        return UIColor(hue: hue, saturation: 0.9, brightness: 0.9, alpha: 1.0)
    }

    func formatDate(from rawDate: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS"
        if let date = formatter.date(from: rawDate) {
            let outputFormatter = DateFormatter()
            outputFormatter.dateFormat = "MMM d, yyyy"
            return outputFormatter.string(from: date)
        }
        return rawDate
    }
    
    func color(for grade: String) -> UIColor {
        switch grade.uppercased() {
        case "A": return .systemGreen
        case "B": return .systemYellow
        case "C": return .systemRed
        default: return .gray
        }
    }
}
