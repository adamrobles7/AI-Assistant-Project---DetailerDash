//
//  RootView.swift
//  DetailerDash
//
//  Root view with tab navigation and routing logic
//

import SwiftUI

struct RootView: View {
    @EnvironmentObject var authStore: AuthStore
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        Group {
            if authStore.hasAuthenticated {
                MainTabView()
            } else {
                AuthView(authStore: authStore, appState: appState)
            }
        }
    }
}

struct MainTabView: View {
    @EnvironmentObject var authStore: AuthStore
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        TabView {
            // Schedule Tab (both modes)
            ScheduleView(repository: scheduleRepository)
                .tabItem {
                    Label("Schedule", systemImage: "calendar")
                }
            
            // Mode-specific second tab
            if appState.mode == .consumer {
                FindBusinessView()
                    .tabItem {
                        Label("Find", systemImage: "magnifyingglass")
                    }
            } else {
                servicesTab
                    .tabItem {
                        Label("Services", systemImage: "wrench.and.screwdriver")
                    }
            }
            
            // Settings Tab (both modes)
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
    }
    
    private var scheduleRepository: ScheduleRepository {
        let store = AppointmentStore()
        
        if appState.mode == .business,
           let user = authStore.currentUser,
           let businessProfile = user.businessProfile {
            return BusinessScheduleRepository(appointmentStore: store, businessCode: businessProfile.code)
        } else {
            return ConsumerScheduleRepository(appointmentStore: store)
        }
    }
    
    @ViewBuilder
    private var servicesTab: some View {
        if let user = authStore.currentUser,
           let businessProfile = user.businessProfile {
            NavigationView {
                ServicesManagerView(businessCode: businessProfile.code)
            }
        } else {
            Text("Business profile not found")
        }
    }
}

