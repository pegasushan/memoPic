//
//  memoPicApp.swift
//  memoPic
//
//  Created by 한상욱 on 5/28/25.
//

import SwiftUI

@main
struct memoPicApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
