//
//  AppConfig.swift
//  RAT
//
//  Created by Rio Simpson on 4/21/25.
//

import Foundation

struct AppConfig {
    private static let secrets: [String: Any] = {
        guard let url = Bundle.main.url(forResource: "Secrets", withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let result = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        else {
            return [:]
        }
        return result
    }()

    static var googleAPIKey: String {
        return secrets["GOOGLE_API_KEY"] as? String ?? ""
    }

    static var nycAppToken: String {
        return secrets["NYC_APP_TOKEN"] as? String ?? ""    
    }
}
