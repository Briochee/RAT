//
//  AppConfig.swift
//  RAT
//
//  Created by Rio Simpson on 4/21/25.
//

import Foundation

struct AppConfig {
    static var googleAPIKey: String {
        return Bundle.main.infoDictionary?["GOOGLE_API_KEY"] as? String ?? ""
    }
    
    static var nycAppToken: String {
        return Bundle.main.infoDictionary?["NYC_APP_TOKEN"] as? String ?? ""
    }
}
