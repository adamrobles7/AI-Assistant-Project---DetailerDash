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
        
        return "Are you sure you want to book an appoitment on \(formatter.string(from: time)), \(timeFormatter.string(from: time)) for \(service.name)"
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
    
    private let businessProfile: BusinessProfile
    private let availableServices: [Service]
    
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
        
        // Process message
        isProcessing = true
        
        // Simulate AI processing delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            guard let self = self else { return }
            self.processUserMessage(trimmedText)
            self.isProcessing = false
        }
    }
    
    private func processUserMessage(_ text: String) {
        let lowercased = text.lowercased()
        
        // Extract information from the message
        extractInformation(from: lowercased)
        
        // Detect multiple intents (not mutually exclusive)
        let isGreetingMsg = isGreeting(lowercased)
        let isAskingServices = isAskingAboutServices(lowercased)
        let isAskingPrice = isAskingAboutPricing(lowercased)
        let isAskingTime = isAskingAboutDuration(lowercased)
        let hasBookingIntent = isBookingIntent(lowercased)
        let hasVehicleInfo = containsVehicleInfo(lowercased)
        let hasServiceMention = !suggestedServices.isEmpty
        
        // Respond based on combined intents with priority
        
        // 1. Specific service + pricing question (e.g., "how much is a detail?")
        if hasServiceMention && isAskingPrice {
            respondWithSpecificServicePrice()
        }
        // 2. Specific service + duration question (e.g., "how long does ceramic coating take?")
        else if hasServiceMention && isAskingTime {
            respondWithDurationInfo()
        }
        // 3. Booking intent with context (e.g., "I want to book a detail for my Honda")
        else if hasBookingIntent {
            handleBookingIntent()
        }
        // 4. General pricing question
        else if isAskingPrice {
            respondWithPricingInfo()
        }
        // 5. Duration question
        else if isAskingTime {
            respondWithDurationInfo()
        }
        // 6. Services inquiry
        else if isAskingServices {
            respondWithServiceInfo(lowercased)
        }
        // 7. Service mentioned with vehicle info (e.g., "detail for my 2020 Honda")
        else if hasServiceMention && hasVehicleInfo {
            respondWithServiceAndVehicle()
        }
        // 8. Just service mentioned (e.g., "tell me about your wash")
        else if hasServiceMention {
            respondWithServiceDetails()
        }
        // 9. Vehicle info mentioned (e.g., "I have a 2020 Honda Civic")
        else if hasVehicleInfo {
            handleVehicleInfo()
        }
        // 10. Greeting
        else if isGreetingMsg {
            respondToGreeting()
        }
        // 11. Questions about specific problems
        else if containsProblemKeywords(lowercased) {
            respondToCarProblem(lowercased)
        }
        // 12. Default helpful response
        else {
            respondWithGeneralHelp()
        }
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
    
    private func isGreeting(_ text: String) -> Bool {
        let greetings = ["hi", "hello", "hey", "good morning", "good afternoon", "good evening", "yo", "sup", "greetings"]
        // Check if it's a short message that's just a greeting
        let words = text.split(separator: " ")
        if words.count <= 3 {
            return greetings.contains(where: { text.contains($0) })
        }
        return false
    }
    
    private func isAskingAboutServices(_ text: String) -> Bool {
        let keywords = ["what services", "what do you offer", "what can you do", "services available", 
                       "show me services", "list services", "what services do you have", "tell me about your services",
                       "what are your services", "services do you provide", "what do you do"]
        return keywords.contains(where: { text.contains($0) })
    }
    
    private func isAskingAboutPricing(_ text: String) -> Bool {
        let keywords = ["how much", "price", "cost", "pricing", "rates", "charge", "expensive",
                       "what does it cost", "how much does", "what's the price", "what is the price"]
        return keywords.contains(where: { text.contains($0) })
    }
    
    private func isAskingAboutDuration(_ text: String) -> Bool {
        let keywords = ["how long", "duration", "take time", "hours", "minutes", "time does it take",
                       "long does it take", "how much time"]
        return keywords.contains(where: { text.contains($0) })
    }
    
    private func isBookingIntent(_ text: String) -> Bool {
        let keywords = ["book", "schedule", "appointment", "reserve", "i need", "i want", "looking for",
                       "can i book", "want to book", "would like to book", "make an appointment", 
                       "set up an appointment", "get an appointment"]
        return keywords.contains(where: { text.contains($0) })
    }
    
    private func containsVehicleInfo(_ text: String) -> Bool {
        return extractedInfo.vehicleMake != nil || extractedInfo.vehicleYear != nil
    }
    
    private func containsProblemKeywords(_ text: String) -> Bool {
        let problems = ["scratch", "swirl", "dent", "stain", "dirty", "mess", "smell", "odor",
                       "faded", "oxidized", "water spots", "bird droppings", "tar", "sap"]
        return problems.contains(where: { text.contains($0) })
    }
    
    private func respondToGreeting() {
        let response = "Hello! How can I help you today? Are you looking to book a detailing service?"
        addAssistantMessage(response)
    }
    
    private func respondWithServiceInfo(_ text: String) {
        if availableServices.isEmpty {
            addAssistantMessage("We're currently updating our service menu. Please check back soon!")
            return
        }
        
        var response = "Here are our available services:\n\n"
        for service in availableServices.prefix(5) {
            response += "• **\(service.name)** - \(service.displayPrice)\n  \(service.description)\n\n"
        }
        
        if availableServices.count > 5 {
            response += "...and \(availableServices.count - 5) more! Would you like help choosing the right service?"
        } else {
            response += "Which service interests you?"
        }
        
        addAssistantMessage(response)
    }
    
    private func respondWithPricingInfo() {
        if availableServices.isEmpty {
            addAssistantMessage("We're currently updating our pricing. Please check back soon!")
            return
        }
        
        let minPrice = availableServices.map { $0.basePriceCents }.min() ?? 0
        let maxPrice = availableServices.map { $0.basePriceCents }.max() ?? 0
        
        var response = "Our pricing varies by service:\n\n"
        response += "• Starting from \(formatPrice(minPrice))\n"
        response += "• Up to \(formatPrice(maxPrice))\n\n"
        response += "Would you like to see specific service prices?"
        
        addAssistantMessage(response)
    }
    
    private func respondWithDurationInfo() {
        if let service = suggestedServices.first {
            let hours = service.durationMinutes / 60
            let mins = service.durationMinutes % 60
            var timeStr = ""
            if hours > 0 {
                timeStr += "\(hours) hour\(hours > 1 ? "s" : "")"
            }
            if mins > 0 {
                if hours > 0 { timeStr += " and " }
                timeStr += "\(mins) minutes"
            }
            addAssistantMessage("\(service.name) typically takes \(timeStr). Would you like to book this service?")
        } else {
            addAssistantMessage("Service duration varies by type. Most details take 2-4 hours, while quick washes take 30-60 minutes. Which service are you interested in?")
        }
    }
    
    private func handleBookingIntent() {
        var response = ""
        
        // Check what info we have
        if extractedInfo.vehicleMake != nil || extractedInfo.vehicleYear != nil {
            response += "Great! I can help you book an appointment"
            if let make = extractedInfo.vehicleMake, let year = extractedInfo.vehicleYear {
                response += " for your \(year) \(make)"
            } else if let make = extractedInfo.vehicleMake {
                response += " for your \(make)"
            }
            response += ". "
        } else {
            response += "I'd be happy to help you book an appointment! "
        }
        
        // Suggest services if we found any
        if !suggestedServices.isEmpty {
            response += "\n\nBased on what you mentioned, here are some services that might work:\n\n"
            for service in suggestedServices.prefix(3) {
                response += "• **\(service.name)** - \(service.displayPrice) (~\(service.durationMinutes/60)hr)\n  \(service.description)\n\n"
            }
            response += "Tap the 'Start Booking' button below to choose a service and pick your preferred time!"
        } else if !availableServices.isEmpty {
            response += "\n\nWhat type of service are you looking for? We offer:\n"
            let categories = Set(availableServices.map { $0.category.rawValue })
            for category in categories.sorted() {
                response += "• \(category)\n"
            }
            response += "\nOr tap 'Start Booking' below to browse all services!"
        } else {
            response += "We're currently updating our services. Please check back soon!"
        }
        
        addAssistantMessage(response)
    }
    
    private func handleVehicleInfo() {
        var response = "Got it! "
        
        if let year = extractedInfo.vehicleYear, let make = extractedInfo.vehicleMake {
            response += "I see you have a \(year) \(make). "
        } else if let make = extractedInfo.vehicleMake {
            response += "I see you have a \(make). "
        } else if let year = extractedInfo.vehicleYear {
            response += "I see you have a \(year) vehicle. "
        }
        
        response += "What type of service are you looking for? "
        
        if !availableServices.isEmpty {
            response += "We offer detailing, washing, ceramic coating, and more."
        }
        
        addAssistantMessage(response)
    }
    
    private func respondWithGeneralHelp() {
        let responses = [
            "I can help you find the right service or schedule an appointment. What would you like to know?",
            "Tell me about your vehicle and what kind of service you're looking for, and I'll help you out!",
            "I'm here to help! You can ask me about our services, pricing, or book an appointment. What interests you?"
        ]
        addAssistantMessage(responses.randomElement() ?? responses[0])
    }
    
    // New response methods for better handling
    
    private func respondWithSpecificServicePrice() {
        guard let service = suggestedServices.first else {
            respondWithPricingInfo()
            return
        }
        
        if suggestedServices.count == 1 {
            let hours = service.durationMinutes / 60
            let mins = service.durationMinutes % 60
            var timeStr = ""
            if hours > 0 {
                timeStr += "\(hours) hour\(hours > 1 ? "s" : "")"
            }
            if mins > 0 {
                if hours > 0 { timeStr += " and " }
                timeStr += "\(mins) minutes"
            }
            
            var response = "**\(service.name)** costs \(service.displayPrice) and takes approximately \(timeStr).\n\n"
            response += "\(service.description)\n\n"
            response += "Would you like to book this service?"
            addAssistantMessage(response)
        } else {
            var response = "Here are the prices for the services you asked about:\n\n"
            for service in suggestedServices {
                response += "• **\(service.name)** - \(service.displayPrice)\n"
            }
            response += "\nWould you like more details about any of these?"
            addAssistantMessage(response)
        }
    }
    
    private func respondWithServiceDetails() {
        guard let service = suggestedServices.first else {
            respondWithServiceInfo("")
            return
        }
        
        let hours = service.durationMinutes / 60
        let mins = service.durationMinutes % 60
        var timeStr = ""
        if hours > 0 {
            timeStr += "\(hours) hour\(hours > 1 ? "s" : "")"
        }
        if mins > 0 {
            if hours > 0 { timeStr += " and " }
            timeStr += "\(mins) minutes"
        }
        
        var response = "**\(service.name)**\n\n"
        response += "\(service.description)\n\n"
        response += "• **Price**: \(service.displayPrice)\n"
        response += "• **Duration**: \(timeStr)\n"
        response += "• **Category**: \(service.category.rawValue)\n\n"
        response += "Would you like to book this service?"
        addAssistantMessage(response)
    }
    
    private func respondWithServiceAndVehicle() {
        var response = "Perfect! "
        
        if let year = extractedInfo.vehicleYear, let make = extractedInfo.vehicleMake {
            response += "For your \(year) \(make), "
        } else if let make = extractedInfo.vehicleMake {
            response += "For your \(make), "
        }
        
        if let service = suggestedServices.first {
            response += "I'd recommend our **\(service.name)** service.\n\n"
            response += "\(service.description)\n\n"
            response += "• **Price**: \(service.displayPrice)\n"
            
            let hours = service.durationMinutes / 60
            let mins = service.durationMinutes % 60
            var timeStr = ""
            if hours > 0 {
                timeStr += "\(hours) hour\(hours > 1 ? "s" : "")"
            }
            if mins > 0 {
                if hours > 0 { timeStr += " and " }
                timeStr += "\(mins) minutes"
            }
            response += "• **Duration**: \(timeStr)\n\n"
            response += "Ready to book? Tap 'Start Booking' below!"
        }
        
        addAssistantMessage(response)
    }
    
    private func respondToCarProblem(_ text: String) {
        var response = ""
        
        // Determine the problem and suggest appropriate service
        if text.contains("scratch") || text.contains("swirl") {
            let paintServices = availableServices.filter { $0.category == .paint }
            if !paintServices.isEmpty {
                suggestedServices = paintServices
                response = "For scratches and swirl marks, I'd recommend our **Paint Correction** service. It removes imperfections and restores your paint's clarity.\n\n"
            } else {
                response = "For scratches and swirl marks, a paint correction or detailing service would be ideal. "
            }
        } else if text.contains("water spots") || text.contains("faded") || text.contains("oxidized") {
            let ceramicServices = availableServices.filter { $0.category == .ceramic }
            if !ceramicServices.isEmpty {
                suggestedServices = ceramicServices
                response = "For water spots and faded paint, I'd recommend **Ceramic Coating**. It protects your paint and restores that deep shine.\n\n"
            } else {
                response = "For paint protection and restoration, a ceramic coating or detail would help. "
            }
        } else if text.contains("stain") || text.contains("smell") || text.contains("odor") {
            let interiorServices = availableServices.filter { $0.category == .interior }
            if !interiorServices.isEmpty {
                suggestedServices = interiorServices
                response = "For interior stains and odors, our **Interior Detailing** service is perfect. We'll deep clean and refresh your interior.\n\n"
            } else {
                response = "For interior issues, an interior detailing service would help. "
            }
        } else {
            let detailServices = availableServices.filter { $0.category == .detailing }
            if !detailServices.isEmpty {
                suggestedServices = detailServices
                response = "For general cleaning and restoration, a **Full Detail** service would take care of that for you.\n\n"
            } else {
                response = "We can help with that! "
            }
        }
        
        if !suggestedServices.isEmpty {
            let service = suggestedServices[0]
            response += "**\(service.name)** - \(service.displayPrice)\n"
            response += "\(service.description)\n\n"
            response += "Would you like to book this service?"
        } else {
            response += "Let me show you our services that can help:\n\n"
            for service in availableServices.prefix(3) {
                response += "• **\(service.name)** - \(service.displayPrice)\n"
            }
        }
        
        addAssistantMessage(response)
    }
    
    private func addAssistantMessage(_ content: String) {
        let message = ChatMessage(sender: .assistant, content: content)
        messages.append(message)
    }
    
    private func formatPrice(_ cents: Int) -> String {
        let dollars = Double(cents) / 100.0
        return String(format: "$%.2f", dollars)
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

