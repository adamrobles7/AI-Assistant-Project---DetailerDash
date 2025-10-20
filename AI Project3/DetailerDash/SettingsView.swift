//
//  SettingsView.swift
//  DetailerDash
//
//  Settings with mode picker, business info, and sign out
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var authStore: AuthStore
    @EnvironmentObject var appState: AppState
    
    @State private var showSignOutConfirmation = false
    @State private var showCopiedAlert = false
    
    var body: some View {
        NavigationView {
            List {
                // User Info
                if let user = authStore.currentUser {
                    Section(header: Text("Account")) {
                        HStack {
                            Text("Name")
                            Spacer()
                            Text(user.fullName)
                                .foregroundColor(Theme.secondaryText)
                        }
                        
                        HStack {
                            Text("Email")
                            Spacer()
                            Text(user.email)
                                .foregroundColor(Theme.secondaryText)
                        }
                        
                        HStack {
                            Text("Account Type")
                            Spacer()
                            Text(user.accountType == .business ? "Business" : "Personal")
                                .foregroundColor(Theme.secondaryText)
                        }
                    }
                    
                    // Business Info
                    if user.accountType == .business, let businessProfile = user.businessProfile {
                        Section(header: Text("Business"), footer: Text("Share your handle with customers so they can find and book with your business")) {
                            VStack(alignment: .leading, spacing: Theme.paddingS) {
                                Text("Business Handle")
                                    .font(Theme.caption())
                                    .foregroundColor(Theme.secondaryText)
                                
                                HStack {
                                    Text(businessProfile.handle)
                                        .foregroundColor(Theme.primary)
                                        .font(Theme.headline(16))
                                    
                                    Spacer()
                                    
                                    Button(action: {
                                        copyToClipboard(businessProfile.handle)
                                    }) {
                                        HStack(spacing: 4) {
                                            Image(systemName: "doc.on.doc.fill")
                                            Text("Copy")
                                        }
                                        .font(Theme.caption(12))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Theme.primary)
                                        .cornerRadius(8)
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                            
                            NavigationLink(destination: ServicesManagerView(businessCode: businessProfile.code)) {
                                Text("Manage Services")
                            }
                        }
                    }
                }
                
                // App Mode (for demo purposes)
                Section(header: Text("Demo Settings"), footer: Text("This allows switching between consumer and business modes for demonstration purposes")) {
                    Picker("App Mode", selection: $appState.mode) {
                        Text("Consumer").tag(AppMode.consumer)
                        Text("Business").tag(AppMode.business)
                    }
                }
                
                // Sign Out
                Section {
                    Button(role: .destructive) {
                        showSignOutConfirmation = true
                    } label: {
                        HStack {
                            Spacer()
                            Text("Sign Out")
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .alert("Sign Out", isPresented: $showSignOutConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Sign Out", role: .destructive) {
                    authStore.signOut()
                }
            } message: {
                Text("Are you sure you want to sign out?")
            }
            .alert("Copied!", isPresented: $showCopiedAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Business handle copied to clipboard")
            }
        }
    }
    
    private func copyToClipboard(_ text: String) {
        UIPasteboard.general.string = text
        showCopiedAlert = true
    }
}

