//
//  Item.swift
//  Aurea
//
//  Created by Matteo Ragazzoli on 14/08/2026.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
