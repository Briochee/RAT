//
//  RestaurantAnnotation.swift
//  RAT
//
//  Created by Rio Simpson on 4/23/25.
//

import MapKit

class RestaurantAnnotation: NSObject, MKAnnotation {
    var coordinate: CLLocationCoordinate2D
    var title: String?
    var subtitle: String?

    init(title: String, subtitle: String, coordinate: CLLocationCoordinate2D) {
        self.title = title
        self.subtitle = subtitle
        self.coordinate = coordinate
    }
}
