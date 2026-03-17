//
//  AstateApp.swift
//  Astate
//
//  Created by Laurent Pautet on 11/05/2025.
//

import SwiftUI

@main
struct AstateApp: App {

    init() {
        // Eagerly initialize CoreData stack before any view loads
        _ = CoreDataManager.shared
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
