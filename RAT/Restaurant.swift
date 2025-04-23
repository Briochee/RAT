//
//  Resturant.swift
//  RAT
//
//  Created by Rio Simpson on 4/21/25.
//

import Foundation
import UIKit

struct Restaurant: Decodable {
    var camis: String?
    var dba: String?
    var building: String?
    var street: String?
    var boro: String?
    var zipcode: String?
    var grade: String?
    var inspection_date: String?
    var violation_description: String?
    var critical_flag: String?
    var score: String?
    var grade_date: String?
}

struct Violation {
    let date: String
    let description: String
    let criticalFlag: String?
    let score: String?
}

struct FavoriteRestaurant: Codable {
    let name: String
    let grade: String?
    let rating: Double?
    let camis: String
    let address: String
    let placeID: String
}
