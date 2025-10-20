//
//  ViewModels.swift
//  DetailerDash
//
//  ViewModels for MVVM architecture
//

import Foundation
import Combine
import SwiftUI

// MARK: - Auth ViewModel

class AuthViewModel: ObservableObject {
    @Published var selectedTab = 0 // 0 = Sign In, 1 = Create Account
    
    // Sign In
    @Published var signInEmail = ""
    @Published var signInPassword = ""
    
    // Create Account
    @Published var firstName = ""
    @Published var lastName = ""
    @Published var email = ""
    @Published var password = ""
    @Published var accountType: AccountType = .personal
    @Published var businessName = ""
    
    @Published var errorMessage: String?
    @Published var isLoading = false
    
    private let authStore: AuthStore
    private let appState: AppState
    
    init(authStore: AuthStore, appState: AppState) {
        self.authStore = authStore
        self.appState = appState
    }
    
    func signIn() {
        guard !signInEmail.isEmpty && !signInPassword.isEmpty else {
            errorMessage = "Please fill in all fields"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        // Simulate network delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else { return }
            
            if let user = self.authStore.signIn(email: self.signInEmail, password: self.signInPassword) {
                self.appState.setMode(from: user)
                self.isLoading = false
            } else {
                self.errorMessage = "Invalid email or password."
                self.isLoading = false
            }
        }
    }
    
    func createAccount() {
        guard !firstName.isEmpty && !lastName.isEmpty && !email.isEmpty && !password.isEmpty else {
            errorMessage = "Please fill in all fields"
            return
        }
        
        if accountType == .business && businessName.isEmpty {
            errorMessage = "Please enter a business name"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else { return }
            
            let user = self.authStore.createAccount(
                firstName: self.firstName,
                lastName: self.lastName,
                email: self.email,
                password: self.password,
                accountType: self.accountType,
                businessName: self.businessName
            )
            
            self.appState.setMode(from: user)
            self.isLoading = false
        }
    }
}

// MARK: - Booking ViewModel

class BookingViewModel: ObservableObject {
    // Service selection
    @Published var selectedService: Service?
    
    // Date & Time
    @Published var selectedDate: Date?
    @Published var selectedTime: Date?
    @Published var availableSlots: [Date] = []
    @Published var isLoadingSlots = false
    
    // Customer details
    @Published var customerFirstName = ""
    @Published var customerLastName = ""
    @Published var customerEmail = ""
    @Published var customerPhone = ""
    
    // Vehicle details
    @Published var vehicleYear = ""
    @Published var vehicleMake = ""
    @Published var vehicleModel = ""
    @Published var vehicleColor = ""
    
    // Notes
    @Published var notes = ""
    
    // Booking state
    @Published var isBooking = false
    @Published var bookingSuccess = false
    @Published var bookingError: String?
    
    private let bookingRepository: BookingRepository
    let businessProfile: BusinessProfile
    private var cancellables = Set<AnyCancellable>()
    private var currentRequestId: String?
    
    init(bookingRepository: BookingRepository, businessProfile: BusinessProfile) {
        self.bookingRepository = bookingRepository
        self.businessProfile = businessProfile
    }
    
    var validationErrors: [String] {
        var errors: [String] = []
        
        if selectedService == nil { errors.append("service") }
        if customerFirstName.isEmpty { errors.append("first name") }
        if customerLastName.isEmpty { errors.append("last name") }
        if customerEmail.isEmpty { errors.append("email") }
        if customerPhone.isEmpty { errors.append("phone") }
        if vehicleMake.isEmpty { errors.append("vehicle make") }
        if vehicleModel.isEmpty { errors.append("vehicle model") }
        
        let sanitizedYear = sanitizeYear(vehicleYear)
        if sanitizedYear.count < 4 { errors.append("vehicle year") }
        if selectedTime == nil { errors.append("time") }
        
        return errors
    }
    
    var isValid: Bool {
        validationErrors.isEmpty
    }
    
    var confirmationMessage: String {
        if !isValid {
            let missing = validationErrors.joined(separator: ", ")
            return "Please enter \(missing) to continue."
        }
        
        guard let service = selectedService,
              let time = selectedTime else {
            return ""
        }
        
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        
        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short
        
        return "Are you sure you want to book an appointment on \(formatter.string(from: time)), \(timeFormatter.string(from: time)) for \(service.name)"
    }
    
    func loadAvailableSlots() {
        guard let date = selectedDate,
              let service = selectedService else { return }
        
        isLoadingSlots = true
        
        bookingRepository.availableSlots(for: date, duration: service.durationMinutes)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoadingSlots = false
                    if case .failure = completion {
                        self?.availableSlots = []
                    }
                },
                receiveValue: { [weak self] slots in
                    self?.availableSlots = slots
                    self?.isLoadingSlots = false
                }
            )
            .store(in: &cancellables)
    }
    
    func sanitizeYear(_ year: String) -> String {
        year.filter { $0.isNumber }
    }
    
    func book() {
        guard isValid,
              let service = selectedService,
              let time = selectedTime else { return }
        
        // Idempotency: reuse requestId if already set
        let requestId = currentRequestId ?? UUID().uuidString
        if currentRequestId == nil {
            currentRequestId = requestId
        }
        
        isBooking = true
        bookingSuccess = false
        bookingError = nil
        
        let sanitizedYear = sanitizeYear(vehicleYear)
        
        let customer = Customer(
            firstName: customerFirstName,
            lastName: customerLastName,
            email: customerEmail,
            phone: customerPhone
        )
        
        let vehicle = Vehicle(
            year: sanitizedYear,
            make: vehicleMake,
            model: vehicleModel,
            color: vehicleColor.isEmpty ? nil : vehicleColor
        )
        
        let request = BookingRequest(
            service: service,
            startDate: time,
            customer: customer,
            vehicle: vehicle,
            notes: notes.isEmpty ? nil : notes,
            businessCode: businessProfile.code,
            businessName: businessProfile.businessName
        )
        
        bookingRepository.createAppointment(request, requestId: requestId)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.bookingError = error.localizedDescription
                        self?.isBooking = false
                    }
                },
                receiveValue: { [weak self] _ in
                    self?.bookingSuccess = true
                    self?.isBooking = false
                }
            )
            .store(in: &cancellables)
    }
    
    func reset() {
        selectedService = nil
        selectedDate = nil
        selectedTime = nil
        availableSlots = []
        customerFirstName = ""
        customerLastName = ""
        customerEmail = ""
        customerPhone = ""
        vehicleYear = ""
        vehicleMake = ""
        vehicleModel = ""
        vehicleColor = ""
        notes = ""
        bookingSuccess = false
        bookingError = nil
        currentRequestId = nil
    }
}

// MARK: - Service Catalog ViewModel

class ServiceCatalogViewModel: ObservableObject {
    @Published var services: [Service] = []
    @Published var isLoading = false
    @Published var error: Error?
    
    private let repository: ServiceRepository
    private var cancellables = Set<AnyCancellable>()
    
    init(repository: ServiceRepository) {
        self.repository = repository
    }
    
    func loadServices() {
        isLoading = true
        error = nil
        
        repository.getServices()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        self?.error = error
                    }
                },
                receiveValue: { [weak self] services in
                    self?.services = services
                }
            )
            .store(in: &cancellables)
    }
}

// MARK: - Services Manager ViewModel

class ServicesManagerViewModel: ObservableObject {
    @Published var services: [Service] = []
    @Published var isLoading = false
    @Published var error: Error?
    
    private let repository: MutableServiceRepository
    private var cancellables = Set<AnyCancellable>()
    
    init(repository: MutableServiceRepository) {
        self.repository = repository
        loadServices()
    }
    
    func loadServices() {
        isLoading = true
        error = nil
        
        repository.getServices()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        self?.error = error
                    }
                },
                receiveValue: { [weak self] services in
                    self?.services = services
                }
            )
            .store(in: &cancellables)
    }
    
    func addService(_ service: Service) {
        services.append(service)
        saveServices()
    }
    
    func updateService(_ service: Service) {
        if let index = services.firstIndex(where: { $0.id == service.id }) {
            services[index] = service
            saveServices()
        }
    }
    
    func deleteService(_ service: Service) {
        services.removeAll { $0.id == service.id }
        saveServices()
    }
    
    func moveService(from: IndexSet, to: Int) {
        services.move(fromOffsets: from, toOffset: to)
        saveServices()
    }
    
    private func saveServices() {
        repository.saveServices(services)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.error = error
                    }
                },
                receiveValue: { _ in }
            )
            .store(in: &cancellables)
    }
}

// MARK: - Schedule ViewModel

class ScheduleViewModel: ObservableObject {
    @Published var appointments: [Appointment] = []
    @Published var isLoading = false
    @Published var error: Error?
    
    private let repository: ScheduleRepository
    private var cancellables = Set<AnyCancellable>()
    
    init(repository: ScheduleRepository) {
        self.repository = repository
        
        // Listen for appointment changes
        NotificationCenter.default.publisher(for: .appointmentCreated)
            .sink { [weak self] _ in
                self?.loadAppointments()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .appointmentCancelled)
            .sink { [weak self] _ in
                self?.loadAppointments()
            }
            .store(in: &cancellables)
    }
    
    var upcomingAppointments: [Appointment] {
        appointments
            .filter { !$0.isPast }
            .sorted { $0.startDate < $1.startDate }
    }
    
    func loadAppointments() {
        isLoading = true
        error = nil
        
        repository.getAppointments()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        self?.error = error
                    }
                },
                receiveValue: { [weak self] appointments in
                    self?.appointments = appointments
                }
            )
            .store(in: &cancellables)
    }
    
    func cancelAppointment(id: String) {
        repository.cancelAppointment(id: id)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.error = error
                    }
                },
                receiveValue: { [weak self] _ in
                    self?.loadAppointments()
                }
            )
            .store(in: &cancellables)
    }
}

// MARK: - AI Assistant ViewModel

class AIAssistantViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var inputText = ""
    @Published var isProcessing = false
    @Published var extractedInfo = ExtractedBookingInfo()
    @Published var suggestedServices: [Service] = []
    @Published var errorMessage: String?
    
    private let businessProfile: BusinessProfile
    private let availableServices: [Service]
    private var cancellables = Set<AnyCancellable>()
    
    init(businessProfile: BusinessProfile, availableServices: [Service]) {
        self.businessProfile = businessProfile
        self.availableServices = availableServices
        
        // Welcome message
        let welcomeMessage = ChatMessage(
            sender: .assistant,
            content: "Hi! I'm your booking assistant for \(businessProfile.businessName). I can help you:\n\n• Find the right service for your vehicle\n• Answer questions about our services\n• Schedule an appointment\n\nWhat can I help you with today?"
        )
        messages = [welcomeMessage]
    }
    
    func sendMessage() {
        let trimmedText = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }
        
        // Add user message
        let userMessage = ChatMessage(sender: .user, content: trimmedText)
        messages.append(userMessage)
        inputText = ""
        
        // Process message with OpenAI
        isProcessing = true
        errorMessage = nil
        
        processUserMessageWithOpenAI(trimmedText)
    }
    
    private func processUserMessageWithOpenAI(_ text: String) {
        // Extract information for context (vehicle info, service keywords)
        let lowercased = text.lowercased()
        extractInformation(from: lowercased)
        
        // Build OpenAI conversation history
        let openAIMessages = buildOpenAIMessages()
        
        // Call OpenAI API
        OpenAIService.shared.sendChatCompletion(messages: openAIMessages)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    guard let self = self else { return }
                    self.isProcessing = false
                    
                    if case .failure(let error) = completion {
                        self.errorMessage = error.localizedDescription
                        
                        // Add error message to chat
                        let errorMsg = ChatMessage(
                            sender: .assistant,
                            content: "I apologize, but I'm having trouble connecting right now. \(error.localizedDescription)\n\nPlease check your internet connection and try again."
                        )
                        self.messages.append(errorMsg)
                    }
                },
                receiveValue: { [weak self] response in
                    guard let self = self else { return }
                    
                    // Add AI response to messages
                    let assistantMessage = ChatMessage(
                        sender: .assistant,
                        content: response
                    )
                    self.messages.append(assistantMessage)
                    
                    // Re-extract info from the conversation to update suggested services
                    self.extractInformation(from: lowercased)
                }
            )
            .store(in: &cancellables)
    }
    
    private func extractInformation(from text: String) {
        // Extract vehicle year (4 digits)
        if let yearMatch = text.range(of: "\\b(19|20)\\d{2}\\b", options: .regularExpression) {
            extractedInfo.vehicleYear = String(text[yearMatch])
        }
        
        // Common car makes
        let carMakes = ["honda", "toyota", "ford", "chevrolet", "chevy", "bmw", "mercedes", "audi", "tesla", 
                       "nissan", "mazda", "subaru", "volkswagen", "vw", "hyundai", "kia", "lexus", "acura",
                       "jeep", "dodge", "ram", "gmc", "cadillac", "buick", "porsche", "jaguar", "land rover"]
        
        for make in carMakes {
            if text.contains(make) {
                extractedInfo.vehicleMake = make.capitalized
                if make == "chevy" {
                    extractedInfo.vehicleMake = "Chevrolet"
                } else if make == "vw" {
                    extractedInfo.vehicleMake = "Volkswagen"
                }
                break
            }
        }
        
        // Extract color
        let colors = ["black", "white", "silver", "gray", "grey", "red", "blue", "green", "yellow", "orange", "brown", "gold", "beige", "tan"]
        for color in colors {
            if text.contains(color) {
                extractedInfo.vehicleColor = color.capitalized
                break
            }
        }
        
        // Extract service preferences from available services (exact name match first)
        var foundSpecificService = false
        for service in availableServices {
            let serviceName = service.name.lowercased()
            // Check if the service name is mentioned in the text
            if text.contains(serviceName) {
                extractedInfo.servicePreference = service.name
                if !suggestedServices.contains(where: { $0.id == service.id }) {
                    suggestedServices.append(service)
                }
                foundSpecificService = true
            }
        }
        
        // Only check for category keywords if no specific service was found
        if !foundSpecificService {
            if text.contains("detail") || text.contains("full clean") {
                let detailServices = availableServices.filter { $0.category == .detailing }
                if !detailServices.isEmpty {
                    suggestedServices = detailServices
                    if let first = suggestedServices.first {
                        extractedInfo.servicePreference = first.name
                    }
                }
            } else if text.contains("wash") || text.contains("quick clean") {
                let washServices = availableServices.filter { $0.category == .wash }
                if !washServices.isEmpty {
                    suggestedServices = washServices
                }
            } else if text.contains("ceramic") || text.contains("coating") || text.contains("protect") {
                let ceramicServices = availableServices.filter { $0.category == .ceramic }
                if !ceramicServices.isEmpty {
                    suggestedServices = ceramicServices
                }
            } else if text.contains("paint correction") || text.contains("scratch") || text.contains("swirl") {
                let paintServices = availableServices.filter { $0.category == .paint }
                if !paintServices.isEmpty {
                    suggestedServices = paintServices
                }
            } else if text.contains("interior") || text.contains("inside") || text.contains("upholstery") {
                let interiorServices = availableServices.filter { $0.category == .interior }
                if !interiorServices.isEmpty {
                    suggestedServices = interiorServices
                }
            }
        }
        
        // Extract time preferences
        if text.contains("morning") {
            extractedInfo.preferredTime = "morning"
        } else if text.contains("afternoon") {
            extractedInfo.preferredTime = "afternoon"
        } else if text.contains("evening") {
            extractedInfo.preferredTime = "evening"
        }
        
        // Extract day preferences
        let weekdays = ["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"]
        for day in weekdays {
            if text.contains(day) {
                extractedInfo.preferredDate = day.capitalized
                break
            }
        }
        
        if text.contains("tomorrow") {
            extractedInfo.preferredDate = "tomorrow"
        } else if text.contains("next week") {
            extractedInfo.preferredDate = "next week"
        } else if text.contains("this weekend") || text.contains("weekend") {
            extractedInfo.preferredDate = "this weekend"
        }
    }
    
    // MARK: - OpenAI Integration
    
    private func buildOpenAIMessages() -> [OpenAIMessage] {
        var openAIMessages: [OpenAIMessage] = []
        
        // System message with business context
        let systemPrompt = buildSystemPrompt()
        openAIMessages.append(OpenAIService.createMessage(role: "system", content: systemPrompt))
        
        // Add conversation history (excluding welcome message)
        for message in messages.dropFirst() {
            let role = message.sender == .user ? "user" : "assistant"
            openAIMessages.append(OpenAIService.createMessage(role: role, content: message.content))
        }
        
        return openAIMessages
    }
    
    private func buildSystemPrompt() -> String {
        var prompt = """
        You are a helpful booking assistant for \(businessProfile.businessName), an auto detailing business. \
        Your goal is to help customers discover services and schedule appointments in a friendly, conversational way.
        
        """
        
        // Add services information
        if !availableServices.isEmpty {
            prompt += "AVAILABLE SERVICES:\n"
            for service in availableServices {
            let hours = service.durationMinutes / 60
                let minutes = service.durationMinutes % 60
                let duration = hours > 0 ? "\(hours)h \(minutes)m" : "\(minutes)m"
                prompt += "- \(service.name): \(service.displayPrice), Duration: \(duration)\n  Description: \(service.description)\n"
            }
            prompt += "\n"
        }
        
        // Add extracted context
        if extractedInfo.hasVehicleInfo || extractedInfo.hasServiceInfo {
            prompt += "CUSTOMER CONTEXT:\n"
            if let year = extractedInfo.vehicleYear {
                prompt += "- Vehicle Year: \(year)\n"
            }
            if let make = extractedInfo.vehicleMake {
                prompt += "- Vehicle Make: \(make)\n"
            }
            if let model = extractedInfo.vehicleModel {
                prompt += "- Vehicle Model: \(model)\n"
            }
            if let color = extractedInfo.vehicleColor {
                prompt += "- Vehicle Color: \(color)\n"
            }
            if let service = extractedInfo.servicePreference {
                prompt += "- Interested in: \(service)\n"
            }
            prompt += "\n"
        }
        
        prompt += """
        GUIDELINES:
        - Be friendly, professional, and concise
        - When discussing services, mention pricing and duration
        - If a customer mentions their vehicle, acknowledge it
        - When appropriate, suggest they're ready to book
        - Use **bold** for emphasis on service names and prices
        - Keep responses under 150 words
        - Don't mention that you're an AI or make up information not provided
        
        Remember: You're helping them discover the right service and move toward booking!
        """
        
        return prompt
    }
    
    func clearChat() {
        messages = []
        extractedInfo = ExtractedBookingInfo()
        suggestedServices = []
        
        // Re-add welcome message
        let welcomeMessage = ChatMessage(
            sender: .assistant,
            content: "Hi! I'm your booking assistant for \(businessProfile.businessName). How can I help you today?"
        )
        messages = [welcomeMessage]
    }
}
