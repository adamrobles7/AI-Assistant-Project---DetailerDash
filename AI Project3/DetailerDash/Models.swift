//
//  Models.swift
//  DetailerDash
//
//  Core data models for the app
//

import Foundation

// MARK: - Account & Auth

enum AccountType: String, Codable {
    case personal
    case business
}

struct User: Codable {
    let id: String
    let firstName: String
    let lastName: String
    let email: String
    let password: String  // NOTE: Stored in plain text for demo purposes only. Production apps should use proper password hashing (bcrypt, scrypt, etc.)
    let accountType: AccountType
    let businessProfile: BusinessProfile?
    
    var fullName: String {
        "\(firstName) \(lastName)"
    }
}

struct BusinessProfile: Codable {
    let businessName: String
    let code: String
    
    var handle: String {
        "\(businessName)#\(code)"
    }
}

// MARK: - Services

enum ServiceCategory: String, Codable, CaseIterable {
    case detailing = "Detailing"
    case wash = "Wash"
    case ceramic = "Ceramic Coating"
    case paint = "Paint Correction"
    case interior = "Interior"
    case other = "Other"
}

struct Service: Identifiable, Codable {
    let id: String
    let name: String
    let description: String
    let durationMinutes: Int
    let basePriceCents: Int
    let category: ServiceCategory
    
    var displayPrice: String {
        let dollars = Double(basePriceCents) / 100.0
        return String(format: "$%.2f", dollars)
    }
    
    init(id: String = UUID().uuidString,
         name: String,
         description: String,
         durationMinutes: Int,
         basePriceCents: Int,
         category: ServiceCategory) {
        self.id = id
        self.name = name
        self.description = description
        self.durationMinutes = durationMinutes
        self.basePriceCents = basePriceCents
        self.category = category
    }
}

// MARK: - Booking & Appointments

struct Customer: Codable {
    let firstName: String
    let lastName: String
    let email: String
    let phone: String
    
    var fullName: String {
        "\(firstName) \(lastName)"
    }
}

struct Vehicle: Codable {
    let year: String
    let make: String
    let model: String
    let color: String?
    
    var displayName: String {
        var parts = [year, make, model]
        if let color = color, !color.isEmpty {
            parts.insert(color, at: 0)
        }
        return parts.joined(separator: " ")
    }
    
    var listSubtitle: String {
        // Year (no commas), Color (if present), Model
        var parts = [year]
        if let color = color, !color.isEmpty {
            parts.append(color)
        }
        parts.append(model)
        return parts.joined(separator: " ")
    }
    
    var detailDisplayName: String {
        // Year Make Model (no Color)
        "\(year) \(make) \(model)"
    }
}

struct AppointmentItem: Codable {
    let name: String
    let priceCents: Int
    
    var displayPrice: String {
        let dollars = Double(priceCents) / 100.0
        return String(format: "$%.2f", dollars)
    }
}

struct Appointment: Identifiable, Codable {
    let id: String
    let service: Service
    let startDate: Date
    let endDate: Date
    let customer: Customer
    let vehicle: Vehicle
    let items: [AppointmentItem]
    let notes: String?
    let businessCode: String
    let businessName: String
    
    var totalCents: Int {
        items.reduce(0) { $0 + $1.priceCents }
    }
    
    var displayTotal: String {
        let dollars = Double(totalCents) / 100.0
        return String(format: "$%.2f", dollars)
    }
    
    var isPast: Bool {
        endDate < Date()
    }
    
    var listHeaderText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d • h:mm a"
        return "\(formatter.string(from: startDate)) • \(service.name)"
    }
    
    var listSubtitleText: String {
        // [CustomerName] • [Year] [Color?] [Model]
        "\(customer.fullName) • \(vehicle.listSubtitle)"
    }
}

// MARK: - Booking Request

struct BookingRequest {
    let service: Service
    let startDate: Date
    let customer: Customer
    let vehicle: Vehicle
    let notes: String?
    let businessCode: String
    let businessName: String
}

// MARK: - AI Assistant

enum MessageSender: Codable {
    case user
    case assistant
}

struct ChatMessage: Identifiable, Codable {
    let id: String
    let sender: MessageSender
    let content: String
    let timestamp: Date
    
    init(id: String = UUID().uuidString, sender: MessageSender, content: String, timestamp: Date = Date()) {
        self.id = id
        self.sender = sender
        self.content = content
        self.timestamp = timestamp
    }
}

struct ExtractedBookingInfo {
    var vehicleYear: String?
    var vehicleMake: String?
    var vehicleModel: String?
    var vehicleColor: String?
    var servicePreference: String?
    var preferredDate: String?
    var preferredTime: String?
    var customerNotes: String?
    
    var hasVehicleInfo: Bool {
        vehicleMake != nil || vehicleModel != nil || vehicleYear != nil
    }
    
    var hasServiceInfo: Bool {
        servicePreference != nil
    }
}

