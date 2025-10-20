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

