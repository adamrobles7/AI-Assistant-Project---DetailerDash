//
//  DetailerDashApp.swift
//  DetailerDash
//
//  Main app entry point
//

import SwiftUI

@main
struct DetailerDashApp: App {
    @StateObject private var authStore = AuthStore()
    @StateObject private var appState = AppState()
    
    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(authStore)
                .environmentObject(appState)
                .preferredColorScheme(.dark)
        }
    }
}

