//
//  Queries.swift
//  RAT
//
//  Created by Rio Simpson on 4/21/25.
//

import Foundation
import CoreLocation

struct Queries {
    
    static func nycRestaurantSearchURL(name: String?, building: String, zip: String?) -> URL? {
        let base = "https://data.cityofnewyork.us/resource/43nn-pn8j.json"
        
        let cleanedName = (name ?? "")
            .replacingOccurrences(of: "’", with: "'")
            .uppercased()
        
        let encodedName = cleanedName.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed)
        let encodedBuilding = building.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed) ?? ""
        let encodedZip = zip?.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed)
        
        let appToken = AppConfig.nycAppToken
        
        var full = "\(base)?building=\(encodedBuilding)"
        
        if let encodedName = encodedName, !encodedName.isEmpty {
            full += "&dba=\(encodedName)"
        }
        
        if let zip = encodedZip, !zip.isEmpty {
            full += "&zipcode=\(zip)"
        }
        
        full += "&$$app_token=\(appToken)"
        // print(full)
        return URL(string: full)
    }
    
    static func fetchNYCDataFromMap(dba name: String, building: String? = nil) -> URL? {
        let base = "https://data.cityofnewyork.us/resource/43nn-pn8j.json"
        let appToken = AppConfig.nycAppToken

        // Sanitize and encode query parameters
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "&+")

        let cleanedName = name.replacingOccurrences(of: "’", with: "'").uppercased()
        guard let encodedName = cleanedName.addingPercentEncoding(withAllowedCharacters: allowed) else {
            return nil
        }

        var urlString = "\(base)?dba=\(encodedName)"

        if let building = building, !building.isEmpty {
            let encodedBuilding = building.addingPercentEncoding(withAllowedCharacters: allowed) ?? ""
            urlString += "&building=\(encodedBuilding)"
        }

        urlString += "&$$app_token=\(appToken)"
        return URL(string: urlString)
    }
    
    static func fetchNYCDataCamis(_ camis: String) -> URL? {
        let base = "https://data.cityofnewyork.us/resource/43nn-pn8j.json"
        let appToken = AppConfig.nycAppToken
        let encodedCamis = camis.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let full = "\(base)?camis=\(encodedCamis)&$$app_token=\(appToken)"
        return URL(string: full)
    }
    
    static func googleFindPlaceURL(for searchText: String, sender: String? = nil) -> URL? {
        let base = "https://maps.googleapis.com/maps/api/place/findplacefromtext/json"
        let input = searchText.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let full = "\(base)?input=\(input)&inputtype=textquery&fields=place_id&key=\(AppConfig.googleAPIKey)"
        
        if let sender = sender {
            logQuery(from: sender, callee: "googleFindPlaceURL", endpoint: full)
            }
        
        return URL(string: full)
    }
    
    static func googlePlaceDetailsURL(for placeID: String, sender: String? = nil) -> URL? {
        let base = "https://maps.googleapis.com/maps/api/place/details/json"
        let fields = "formatted_address,rating,opening_hours,photos,address_components"
        let full = "\(base)?place_id=\(placeID)&fields=\(fields)&key=\(AppConfig.googleAPIKey)"
        
        if let sender = sender {
            logQuery(from: sender, callee: "googlePlaceDetailsURL", endpoint: full)
            }
        
        return URL(string: full)
    }
    
    static func googlePhotoURL(for reference: String, sender: String? = nil) -> URL? {
        let base = "https://maps.googleapis.com/maps/api/place/photo"
        let full = "\(base)?maxwidth=400&photoreference=\(reference)&key=\(AppConfig.googleAPIKey)"
        
        if let sender = sender {
            logQuery(from: sender, callee: "googlePhotoURL", endpoint: full)
            }
        
        return URL(string: full)
    }
    
    static func googleTextSearchURL(for query: String, apiKey: String, sender: String? = nil) -> URL? {
        let base = "https://maps.googleapis.com/maps/api/place/textsearch/json"
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let full = "\(base)?query=\(encodedQuery)&key=\(AppConfig.googleAPIKey)"
        
        if let sender = sender {
            logQuery(from: sender, callee: "googleTextSearchURL", endpoint: full)
            }
        
        return URL(string: full)
    }
    
    static func nearbyRestaurantsURL(coordinate: CLLocationCoordinate2D, radius: Double, apiKey: String, sender: String? = nil) -> URL? {
        let locationString = "\(coordinate.latitude),\(coordinate.longitude)"
        let full = "https://maps.googleapis.com/maps/api/place/nearbysearch/json?location=\(locationString)&radius=\(Int(radius))&type=restaurant&key=\(AppConfig.googleAPIKey)"
        
        if let sender = sender {
            logQuery(from: sender, callee: "nearbyRestaurantsURL", endpoint: full)
            }
        
        return URL(string: full)
    }
    
    static func googleNearbySearchURL(location: CLLocationCoordinate2D, radius: Int, sender: String? = nil) -> URL? {
        let base = "https://maps.googleapis.com/maps/api/place/nearbysearch/json"
        let full = "\(base)?location=\(location.latitude),\(location.longitude)&radius=\(radius)&type=restaurant&key=\(AppConfig.googleAPIKey)"
        
        if let sender = sender {
            logQuery(from: sender, callee: "googleNearbySearchURL", endpoint: full)
            }
        
        return URL(string: full)
    }
    
    private static var debugCounter: [String: Int] = [:]
    private static var debugOn: Bool = false

    private static func logQuery(from sender: String, callee: String, endpoint: String) {
        guard debugOn else { return }
        debugCounter[sender, default: 0] += 1
        let count = debugCounter[sender]!
        print("[QUERY DEBUG] [\(sender)] [\(callee)] Call \(count)")
    }
    
}
