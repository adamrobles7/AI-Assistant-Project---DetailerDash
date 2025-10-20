//
//  Theme.swift
//  DetailerDash
//
//  App-wide theming and styling
//

import SwiftUI

enum Theme {
    // MARK: - Colors
    
    static let primary = Color(red: 0.4, green: 0.3, blue: 0.9)
    static let primaryLight = Color(red: 0.5, green: 0.4, blue: 0.95)
    static let accent = Color(red: 0.3, green: 0.7, blue: 0.9)
    
    static let background = Color(uiColor: .systemBackground)
    static let secondaryBackground = Color(uiColor: .secondarySystemBackground)
    static let tertiaryBackground = Color(uiColor: .tertiarySystemBackground)
    
    static let cardBackground = Color(uiColor: .secondarySystemBackground)
    static let text = Color.primary
    static let secondaryText = Color.secondary
    
    static let success = Color.green
    static let error = Color.red
    static let warning = Color.orange
    
    // MARK: - Fonts
    
    static func title(_ size: CGFloat = 28) -> Font {
        .system(size: size, weight: .bold, design: .rounded)
    }
    
    static func headline(_ size: CGFloat = 20) -> Font {
        .system(size: size, weight: .semibold, design: .rounded)
    }
    
    static func body(_ size: CGFloat = 16) -> Font {
        .system(size: size, weight: .regular, design: .rounded)
    }
    
    static func caption(_ size: CGFloat = 14) -> Font {
        .system(size: size, weight: .regular, design: .rounded)
    }
    
    // MARK: - Spacing
    
    static let paddingXS: CGFloat = 4
    static let paddingS: CGFloat = 8
    static let paddingM: CGFloat = 16
    static let paddingL: CGFloat = 24
    static let paddingXL: CGFloat = 32
    
    // MARK: - Corner Radius
    
    static let cornerRadiusS: CGFloat = 8
    static let cornerRadiusM: CGFloat = 12
    static let cornerRadiusL: CGFloat = 16
    static let cornerRadiusXL: CGFloat = 20
    
    // MARK: - Shadows
    
    static let shadowLight: CGFloat = 2
    static let shadowMedium: CGFloat = 4
    static let shadowHeavy: CGFloat = 8
}

// MARK: - Reusable Components

struct Card<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .background(Theme.cardBackground)
            .cornerRadius(Theme.cornerRadiusM)
            .shadow(color: Color.black.opacity(0.1), radius: Theme.shadowMedium, x: 0, y: 2)
    }
}

struct PrimaryButton: View {
    let title: String
    let action: () -> Void
    var isLoading: Bool = false
    var isDisabled: Bool = false
    
    var body: some View {
        Button(action: action) {
            HStack {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Text(title)
                        .font(Theme.headline(17))
                        .foregroundColor(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(
                LinearGradient(
                    colors: isDisabled ? [Color.gray, Color.gray] : [Theme.primary, Theme.primaryLight],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(Theme.cornerRadiusM)
        }
        .disabled(isDisabled || isLoading)
    }
}

struct SecondaryButton: View {
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Theme.headline(17))
                .foregroundColor(Theme.primary)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Theme.tertiaryBackground)
                .cornerRadius(Theme.cornerRadiusM)
        }
    }
}

struct Tag: View {
    let text: String
    let color: Color
    
    var body: some View {
        Text(text)
            .font(Theme.caption(12))
            .foregroundColor(.white)
            .padding(.horizontal, Theme.paddingS)
            .padding(.vertical, Theme.paddingXS)
            .background(color)
            .cornerRadius(Theme.cornerRadiusS)
    }
}

