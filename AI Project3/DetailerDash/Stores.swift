//
//  Stores.swift
//  DetailerDash
//
//  Storage and state management
//

import Foundation

// MARK: - Notification Names

extension Notification.Name {
    static let appointmentCreated = Notification.Name("appointmentCreated")
    static let appointmentCancelled = Notification.Name("appointmentCancelled")
}

// MARK: - Appointment Store

class AppointmentStore {
    private let defaults = UserDefaults.standard
    private let consumerKey = "appointments.consumer"
    private let businessKey = "appointments.business"
    
    func getConsumerAppointments() -> [Appointment] {
        guard let data = defaults.data(forKey: consumerKey) else { return [] }
        return (try? JSONDecoder().decode([Appointment].self, from: data)) ?? []
    }
    
    func getBusinessAppointments(for businessCode: String) -> [Appointment] {
        guard let data = defaults.data(forKey: businessKey) else { return [] }
        let all = (try? JSONDecoder().decode([Appointment].self, from: data)) ?? []
        return all.filter { $0.businessCode == businessCode }
    }
    
    func add(appointment: Appointment) {
        // Add to consumer appointments
        var consumerAppointments = getConsumerAppointments()
        if !consumerAppointments.contains(where: { $0.id == appointment.id }) {
            consumerAppointments.append(appointment)
            if let data = try? JSONEncoder().encode(consumerAppointments) {
                defaults.set(data, forKey: consumerKey)
            }
        }
        
        // Add to business appointments
        guard let data = defaults.data(forKey: businessKey) else {
            if let newData = try? JSONEncoder().encode([appointment]) {
                defaults.set(newData, forKey: businessKey)
            }
            NotificationCenter.default.post(name: .appointmentCreated, object: nil)
            return
        }
        
        var businessAppointments = (try? JSONDecoder().decode([Appointment].self, from: data)) ?? []
        if !businessAppointments.contains(where: { $0.id == appointment.id }) {
            businessAppointments.append(appointment)
            if let newData = try? JSONEncoder().encode(businessAppointments) {
                defaults.set(newData, forKey: businessKey)
            }
        }
        
        NotificationCenter.default.post(name: .appointmentCreated, object: nil)
    }
    
    func cancel(appointmentId: String) {
        // Remove from consumer
        var consumerAppointments = getConsumerAppointments()
        consumerAppointments.removeAll { $0.id == appointmentId }
        if let data = try? JSONEncoder().encode(consumerAppointments) {
            defaults.set(data, forKey: consumerKey)
        }
        
        // Remove from business
        if let data = defaults.data(forKey: businessKey) {
            var businessAppointments = (try? JSONDecoder().decode([Appointment].self, from: data)) ?? []
            businessAppointments.removeAll { $0.id == appointmentId }
            if let newData = try? JSONEncoder().encode(businessAppointments) {
                defaults.set(newData, forKey: businessKey)
            }
        }
        
        NotificationCenter.default.post(name: .appointmentCancelled, object: nil)
    }
}

// MARK: - Auth Store

class AuthStore: ObservableObject {
    private let defaults = UserDefaults.standard
    private let userKey = "auth.user"
    private let hasAuthenticatedKey = "auth.hasAuthenticated"
    private let userRegistryKey = "auth.userRegistry"
    
    @Published var currentUser: User?
    @Published var hasAuthenticated: Bool
    
    init() {
        self.hasAuthenticated = defaults.bool(forKey: hasAuthenticatedKey)
        
        if let data = defaults.data(forKey: userKey),
           let user = try? JSONDecoder().decode(User.self, from: data) {
            self.currentUser = user
        }
    }
    
    func signIn(email: String, password: String) -> User? {
        // Look up existing user by email
        guard let existingUser = findUser(by: email) else {
            return nil // User not found
        }
        
        // Validate password
        // NOTE: Using plain text comparison for demo. Production apps should compare hashed passwords.
        guard existingUser.password == password else {
            return nil // Invalid password
        }
        
        saveUser(existingUser)
        return existingUser
    }
    
    private func findUser(by email: String) -> User? {
        guard let data = defaults.data(forKey: userRegistryKey),
              let users = try? JSONDecoder().decode([User].self, from: data) else {
            return nil
        }
        
        return users.first { $0.email.lowercased() == email.lowercased() }
    }
    
    private func registerUser(_ user: User) {
        var users = getAllUsers()
        
        // Remove existing user with same email if any
        users.removeAll { $0.email.lowercased() == user.email.lowercased() }
        
        // Add new user
        users.append(user)
        
        // Save registry
        if let data = try? JSONEncoder().encode(users) {
            defaults.set(data, forKey: userRegistryKey)
        }
    }
    
    private func getAllUsers() -> [User] {
        guard let data = defaults.data(forKey: userRegistryKey),
              let users = try? JSONDecoder().decode([User].self, from: data) else {
            return []
        }
        return users
    }
    
    func createAccount(firstName: String, lastName: String, email: String, password: String, accountType: AccountType, businessName: String?) -> User {
        var businessProfile: BusinessProfile?
        
        if accountType == .business, let businessName = businessName, !businessName.isEmpty {
            let code = BusinessDirectory.shared.generateUniqueCode()
            businessProfile = BusinessProfile(businessName: businessName, code: code)
            
            if let profile = businessProfile {
                BusinessDirectory.shared.register(profile: profile)
            }
        }
        
        let user = User(
            id: UUID().uuidString,
            firstName: firstName,
            lastName: lastName,
            email: email,
            password: password,
            accountType: accountType,
            businessProfile: businessProfile
        )
        
        // Register user in the user registry
        registerUser(user)
        
        // Save as current user
        saveUser(user)
        return user
    }
    
    private func saveUser(_ user: User) {
        if let data = try? JSONEncoder().encode(user) {
            defaults.set(data, forKey: userKey)
        }
        defaults.set(true, forKey: hasAuthenticatedKey)
        
        currentUser = user
        hasAuthenticated = true
    }
    
    func signOut() {
        defaults.removeObject(forKey: userKey)
        defaults.set(false, forKey: hasAuthenticatedKey)
        
        currentUser = nil
        hasAuthenticated = false
    }
}

// MARK: - Business Directory

class BusinessDirectory {
    static let shared = BusinessDirectory()
    
    private let defaults = UserDefaults.standard
    private let directoryKey = "business.directory"
    private let usedCodesKey = "business.usedCodes"
    
    private init() {}
    
    func register(profile: BusinessProfile) {
        var directory = getDirectory()
        directory[profile.handle] = profile
        saveDirectory(directory)
        
        var usedCodes = getUsedCodes()
        usedCodes.insert(profile.code)
        saveUsedCodes(usedCodes)
    }
    
    func find(handle: String) -> BusinessProfile? {
        let directory = getDirectory()
        
        // Case-insensitive search with whitespace trimming
        let normalizedHandle = handle.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        return directory.first { key, _ in
            key.lowercased() == normalizedHandle
        }?.value
    }
    
    func generateUniqueCode() -> String {
        var usedCodes = getUsedCodes()
        var code: String
        
        repeat {
            let randomNumber = Int.random(in: 0...99999)
            code = String(format: "%05d", randomNumber)
        } while usedCodes.contains(code)
        
        usedCodes.insert(code)
        saveUsedCodes(usedCodes)
        
        return code
    }
    
    private func getDirectory() -> [String: BusinessProfile] {
        guard let data = defaults.data(forKey: directoryKey) else { return [:] }
        return (try? JSONDecoder().decode([String: BusinessProfile].self, from: data)) ?? [:]
    }
    
    private func saveDirectory(_ directory: [String: BusinessProfile]) {
        if let data = try? JSONEncoder().encode(directory) {
            defaults.set(data, forKey: directoryKey)
        }
    }
    
    private func getUsedCodes() -> Set<String> {
        guard let data = defaults.data(forKey: usedCodesKey) else { return [] }
        return (try? JSONDecoder().decode(Set<String>.self, from: data)) ?? []
    }
    
    private func saveUsedCodes(_ codes: Set<String>) {
        if let data = try? JSONEncoder().encode(codes) {
            defaults.set(data, forKey: usedCodesKey)
        }
    }
}

// MARK: - App State

enum AppMode: String {
    case consumer
    case business
}

class AppState: ObservableObject {
    private let defaults = UserDefaults.standard
    private let modeKey = "app.mode"
    
    @Published var mode: AppMode {
        didSet {
            defaults.set(mode.rawValue, forKey: modeKey)
        }
    }
    
    init() {
        if let rawValue = defaults.string(forKey: modeKey),
           let mode = AppMode(rawValue: rawValue) {
            self.mode = mode
        } else {
            self.mode = .consumer
        }
    }
    
    func setMode(from user: User) {
        mode = user.accountType == .business ? .business : .consumer
    }
}

