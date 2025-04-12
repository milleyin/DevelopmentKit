//
//  Double.swift
//  DevelopmentKit
//
//  Created by mille on 2025/4/12.
//

import Foundation

extension Double {
    func rounded(toPlaces places: Int) -> Double {
        let divisor = pow(10.0, Double(places))
        return (self * divisor).rounded() / divisor
    }
}
