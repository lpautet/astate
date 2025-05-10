//
//  Item.swift
//  Astate
//
//  Created by Laurent Pautet on 11/05/2025.
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
