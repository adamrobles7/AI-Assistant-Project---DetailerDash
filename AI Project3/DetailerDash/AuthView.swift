//
//  AuthView.swift
//  DetailerDash
//
//  Authentication screen with Sign In and Create Account tabs
//

import SwiftUI

struct AuthView: View {
    @StateObject private var viewModel: AuthViewModel
    
    init(authStore: AuthStore, appState: AppState) {
        _viewModel = StateObject(wrappedValue: AuthViewModel(authStore: authStore, appState: appState))
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: Theme.paddingM) {
                    Text("DetailerDash")
                        .font(Theme.title(34))
                        .foregroundColor(Theme.primary)
                    
                    Text("Professional detailing management")
                        .font(Theme.body())
                        .foregroundColor(Theme.secondaryText)
                }
                .padding(.top, Theme.paddingXL)
                .padding(.bottom, Theme.paddingL)
                
                // Tabs
                Picker("", selection: $viewModel.selectedTab) {
                    Text("Sign In").tag(0)
                    Text("Create Account").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, Theme.paddingL)
                .padding(.bottom, Theme.paddingL)
                
                // Content
                TabView(selection: $viewModel.selectedTab) {
                    SignInTab(viewModel: viewModel)
                        .tag(0)
                    
                    CreateAccountTab(viewModel: viewModel)
                        .tag(1)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            .background(Theme.background)
        }
    }
}

struct SignInTab: View {
    @ObservedObject var viewModel: AuthViewModel
    
    var body: some View {
        ScrollView {
            VStack(spacing: Theme.paddingL) {
                VStack(spacing: Theme.paddingM) {
                    TextField("Email", text: $viewModel.signInEmail)
                        .textFieldStyle(CustomTextFieldStyle())
                        .textContentType(.emailAddress)
                        .autocapitalization(.none)
                        .keyboardType(.emailAddress)
                    
                    SecureField("Password", text: $viewModel.signInPassword)
                        .textFieldStyle(CustomTextFieldStyle())
                        .textContentType(.password)
                }
                
                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(Theme.caption())
                        .foregroundColor(Theme.error)
                }
                
                PrimaryButton(
                    title: "Sign In",
                    action: viewModel.signIn,
                    isLoading: viewModel.isLoading
                )
            }
            .padding(.horizontal, Theme.paddingL)
            .padding(.top, Theme.paddingL)
        }
    }
}

struct CreateAccountTab: View {
    @ObservedObject var viewModel: AuthViewModel
    
    var body: some View {
        ScrollView {
            VStack(spacing: Theme.paddingL) {
                VStack(spacing: Theme.paddingM) {
                    TextField("First Name", text: $viewModel.firstName)
                        .textFieldStyle(CustomTextFieldStyle())
                        .textContentType(.givenName)
                    
                    TextField("Last Name", text: $viewModel.lastName)
                        .textFieldStyle(CustomTextFieldStyle())
                        .textContentType(.familyName)
                    
                    TextField("Email", text: $viewModel.email)
                        .textFieldStyle(CustomTextFieldStyle())
                        .textContentType(.emailAddress)
                        .autocapitalization(.none)
                        .keyboardType(.emailAddress)
                    
                    SecureField("Password", text: $viewModel.password)
                        .textFieldStyle(CustomTextFieldStyle())
                        .textContentType(.newPassword)
                    
                    VStack(alignment: .leading, spacing: Theme.paddingS) {
                        Text("Account Type")
                            .font(Theme.caption())
                            .foregroundColor(Theme.secondaryText)
                        
                        Picker("", selection: $viewModel.accountType) {
                            Text("Personal").tag(AccountType.personal)
                            Text("Business").tag(AccountType.business)
                        }
                        .pickerStyle(.segmented)
                    }
                    
                    if viewModel.accountType == .business {
                        TextField("Business Name", text: $viewModel.businessName)
                            .textFieldStyle(CustomTextFieldStyle())
                    }
                }
                
                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(Theme.caption())
                        .foregroundColor(Theme.error)
                }
                
                PrimaryButton(
                    title: "Create Account",
                    action: viewModel.createAccount,
                    isLoading: viewModel.isLoading
                )
            }
            .padding(.horizontal, Theme.paddingL)
            .padding(.top, Theme.paddingL)
        }
    }
}

struct CustomTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .font(Theme.body())
            .padding(Theme.paddingM)
            .background(Theme.tertiaryBackground)
            .cornerRadius(Theme.cornerRadiusM)
    }
}

