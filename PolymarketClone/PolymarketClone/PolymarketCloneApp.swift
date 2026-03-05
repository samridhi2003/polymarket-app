//
//  PolymarketCloneApp.swift
//  PolymarketClone
//
//  Created by Samridhi Singh on 04/03/26.
//

import SwiftUI

@main
struct PolymarketCloneApp: App {
    @StateObject private var auth = AuthManager()

    var body: some Scene {
        WindowGroup {
            Group {
                if !auth.isReady {
                    ProgressView("Loading...")
                } else if auth.isAuthenticated {
                    ContentView()
                } else {
                    LoginView()
                }
            }
            .environmentObject(auth)
        }
    }
}
