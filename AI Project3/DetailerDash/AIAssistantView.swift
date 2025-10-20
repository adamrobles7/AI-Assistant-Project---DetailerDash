//
//  AIAssistantView.swift
//  DetailerDash
//
//  AI Assistant chat interface for helping users book appointments
//

import SwiftUI

struct AIAssistantView: View {
    @StateObject private var viewModel: AIAssistantViewModel
    @Environment(\.dismiss) private var dismiss
    let onStartBooking: () -> Void
    
    init(businessProfile: BusinessProfile, availableServices: [Service], onStartBooking: @escaping () -> Void) {
        _viewModel = StateObject(wrappedValue: AIAssistantViewModel(businessProfile: businessProfile, availableServices: availableServices))
        self.onStartBooking = onStartBooking
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
            
            // Chat messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: Theme.paddingM) {
                        ForEach(viewModel.messages) { message in
                            MessageBubbleView(message: message)
                                .id(message.id)
                        }
                        
                        if viewModel.isProcessing {
                            TypingIndicatorView()
                        }
                    }
                    .padding(Theme.paddingM)
                }
                .onChange(of: viewModel.messages.count) { _ in
                    if let lastMessage = viewModel.messages.last {
                        withAnimation {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }
            
            // Action buttons (if we have suggestions)
            if !viewModel.suggestedServices.isEmpty {
                actionButtonsView
            }
            
            // Input area
            inputView
        }
        .background(Theme.background)
    }
    
    private var headerView: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.secondary)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.caption)
                        .foregroundColor(Theme.accent)
                    Text("AI Booking Assistant")
                        .font(Theme.headline())
                }
                
                Text("Powered by DetailerDash")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Menu {
                Button(action: { viewModel.clearChat() }) {
                    Label("Clear Chat", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle.fill")
                    .font(.title2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(Theme.paddingM)
        .background(Theme.cardBackground)
        .shadow(color: .black.opacity(0.05), radius: 2, y: 2)
    }
    
    private var actionButtonsView: some View {
        VStack(spacing: Theme.paddingS) {
            PrimaryButton(
                title: "Start Booking",
                action: {
                    dismiss()
                    onStartBooking()
                }
            )
            .padding(.horizontal, Theme.paddingM)
        }
        .padding(.vertical, Theme.paddingS)
        .background(Theme.cardBackground)
    }
    
    private var inputView: some View {
        HStack(spacing: Theme.paddingM) {
            TextField("Ask me anything...", text: $viewModel.inputText, axis: .vertical)
                .textFieldStyle(ChatTextFieldStyle())
                .lineLimit(1...4)
                .onSubmit {
                    viewModel.sendMessage()
                }
            
            Button(action: { viewModel.sendMessage() }) {
                Image(systemName: viewModel.inputText.isEmpty ? "sparkles" : "arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundColor(viewModel.inputText.isEmpty ? .secondary : Theme.primary)
            }
            .disabled(viewModel.inputText.isEmpty)
        }
        .padding(Theme.paddingM)
        .background(Theme.cardBackground)
        .shadow(color: .black.opacity(0.05), radius: 2, y: -2)
    }
}

struct MessageBubbleView: View {
    let message: ChatMessage
    
    var body: some View {
        HStack {
            if message.sender == .user {
                Spacer(minLength: 60)
            }
            
            VStack(alignment: message.sender == .user ? .trailing : .leading, spacing: 4) {
                Text(formatMessageContent(message.content))
                    .font(Theme.body())
                    .foregroundColor(message.sender == .user ? .white : Theme.text)
                    .padding(.horizontal, Theme.paddingM)
                    .padding(.vertical, Theme.paddingS + 2)
                    .background(
                        message.sender == .user ?
                        AnyView(LinearGradient(
                            colors: [Theme.primary, Theme.accent],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )) :
                        AnyView(Theme.cardBackground)
                    )
                    .cornerRadius(18)
                    .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
                
                Text(formatTime(message.timestamp))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
            }
            
            if message.sender == .assistant {
                Spacer(minLength: 60)
            }
        }
    }
    
    private func formatMessageContent(_ content: String) -> AttributedString {
        var attributedString = AttributedString(content)
        
        // Find all text between ** markers for bold
        let pattern = "\\*\\*(.+?)\\*\\*"
        if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
            let nsString = content as NSString
            let matches = regex.matches(in: content, options: [], range: NSRange(location: 0, length: nsString.length))
            
            // Process matches in reverse to maintain string indices
            for match in matches.reversed() {
                if match.numberOfRanges == 2 {
                    let fullRange = match.range(at: 0)
                    let innerRange = match.range(at: 1)
                    
                    if let swiftInnerRange = Range(innerRange, in: content) {
                        let boldText = String(content[swiftInnerRange])
                        var boldAttr = AttributedString(boldText)
                        boldAttr.font = Theme.body().weight(.semibold)
                        
                        if let attrRange = Range(fullRange, in: attributedString) {
                            attributedString.replaceSubrange(attrRange, with: boldAttr)
                        }
                    }
                }
            }
        }
        
        return attributedString
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct TypingIndicatorView: View {
    @State private var numberOfDots = 0
    
    var body: some View {
        HStack {
            HStack(spacing: 6) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(Color.secondary.opacity(0.5))
                        .frame(width: 8, height: 8)
                        .scaleEffect(numberOfDots == index ? 1.2 : 0.8)
                        .animation(
                            Animation.easeInOut(duration: 0.4)
                                .repeatForever()
                                .delay(Double(index) * 0.2),
                            value: numberOfDots
                        )
                }
            }
            .padding(.horizontal, Theme.paddingM)
            .padding(.vertical, Theme.paddingS + 2)
            .background(Theme.cardBackground)
            .cornerRadius(18)
            .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
            
            Spacer(minLength: 60)
        }
        .onAppear {
            withAnimation {
                numberOfDots = 2
            }
        }
    }
}

struct ChatTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(.horizontal, Theme.paddingM)
            .padding(.vertical, Theme.paddingS)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Theme.background)
            )
    }
}

// Floating AI Assistant Button
struct AIAssistantButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.body.weight(.semibold))
                Text("AI Assistant")
                    .font(Theme.body().weight(.semibold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, Theme.paddingM + 4)
            .padding(.vertical, Theme.paddingS + 4)
            .background(
                LinearGradient(
                    colors: [Theme.primary, Theme.accent],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .cornerRadius(25)
            .shadow(color: Theme.primary.opacity(0.3), radius: 8, y: 4)
        }
    }
}

#Preview {
    AIAssistantView(
        businessProfile: BusinessProfile(businessName: "Premium Auto Spa", code: "12345"),
        availableServices: [
            Service(
                name: "Full Detail",
                description: "Complete interior and exterior detailing",
                durationMinutes: 180,
                basePriceCents: 15000,
                category: .detailing
            ),
            Service(
                name: "Express Wash",
                description: "Quick exterior wash and dry",
                durationMinutes: 30,
                basePriceCents: 2500,
                category: .wash
            )
        ],
        onStartBooking: {}
    )
}

