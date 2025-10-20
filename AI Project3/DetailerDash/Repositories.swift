//
//  Repositories.swift
//  DetailerDash
//
//  Repository protocols and implementations
//

import Foundation
import Combine

// MARK: - Service Repository

protocol ServiceRepository {
    func getServices() -> AnyPublisher<[Service], Error>
}

protocol MutableServiceRepository: ServiceRepository {
    func saveServices(_ services: [Service]) -> AnyPublisher<Void, Error>
}

class LocalServiceRepository: MutableServiceRepository {
    private let businessCode: String
    private let defaults = UserDefaults.standard
    
    private var storageKey: String {
        "services.profile.\(businessCode)"
    }
    
    init(businessCode: String) {
        self.businessCode = businessCode
    }
    
    func getServices() -> AnyPublisher<[Service], Error> {
        Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(NSError(domain: "LocalServiceRepository", code: -1)))
                return
            }
            
            guard let data = self.defaults.data(forKey: self.storageKey) else {
                promise(.success([]))
                return
            }
            
            do {
                let services = try JSONDecoder().decode([Service].self, from: data)
                promise(.success(services))
            } catch {
                promise(.failure(error))
            }
        }
        .eraseToAnyPublisher()
    }
    
    func saveServices(_ services: [Service]) -> AnyPublisher<Void, Error> {
        Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(NSError(domain: "LocalServiceRepository", code: -1)))
                return
            }
            
            do {
                let data = try JSONEncoder().encode(services)
                self.defaults.set(data, forKey: self.storageKey)
                promise(.success(()))
            } catch {
                promise(.failure(error))
            }
        }
        .eraseToAnyPublisher()
    }
}

// MARK: - Booking Repository

protocol BookingRepository {
    func availableSlots(for date: Date, duration: Int) -> AnyPublisher<[Date], Error>
    func createAppointment(_ request: BookingRequest, requestId: String) -> AnyPublisher<Appointment, Error>
}

class MockBookingRepository: BookingRepository {
    private let appointmentStore: AppointmentStore
    private var processedRequests = Set<String>()
    
    init(appointmentStore: AppointmentStore) {
        self.appointmentStore = appointmentStore
    }
    
    func availableSlots(for date: Date, duration: Int) -> AnyPublisher<[Date], Error> {
        Future { promise in
            let calendar = Calendar.current
            var slots: [Date] = []
            
            // Generate slots from 9 AM to 5 PM
            let startHour = 9
            let endHour = 17
            
            for hour in startHour..<endHour {
                for minute in [0, 30] {
                    if let slot = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: date) {
                        // Randomly mark some slots as unavailable
                        let isAvailable = Int.random(in: 0...100) > 20
                        if isAvailable {
                            slots.append(slot)
                        }
                    }
                }
            }
            
            promise(.success(slots))
        }
        .eraseToAnyPublisher()
    }
    
    func createAppointment(_ request: BookingRequest, requestId: String) -> AnyPublisher<Appointment, Error> {
        Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(NSError(domain: "MockBookingRepository", code: -1)))
                return
            }
            
            // Idempotency: check if this exact booking already exists
            let existingAppointments = self.appointmentStore.getConsumerAppointments()
            let dedupeKey = "\(request.startDate.timeIntervalSince1970)_\(request.customer.email)"
            
            if let existing = existingAppointments.first(where: {
                let key = "\($0.startDate.timeIntervalSince1970)_\($0.customer.email)"
                return key == dedupeKey
            }) {
                promise(.success(existing))
                return
            }
            
            // Check if requestId was already processed
            if self.processedRequests.contains(requestId) {
                if let existing = existingAppointments.first(where: { $0.id == requestId }) {
                    promise(.success(existing))
                    return
                }
            }
            
            self.processedRequests.insert(requestId)
            
            let endDate = Calendar.current.date(byAdding: .minute, value: request.service.durationMinutes, to: request.startDate) ?? request.startDate
            
            let items = [AppointmentItem(name: request.service.name, priceCents: request.service.basePriceCents)]
            
            let appointment = Appointment(
                id: requestId,
                service: request.service,
                startDate: request.startDate,
                endDate: endDate,
                customer: request.customer,
                vehicle: request.vehicle,
                items: items,
                notes: request.notes,
                businessCode: request.businessCode,
                businessName: request.businessName
            )
            
            self.appointmentStore.add(appointment: appointment)
            promise(.success(appointment))
        }
        .eraseToAnyPublisher()
    }
}

// MARK: - Schedule Repository

protocol ScheduleRepository {
    func getAppointments() -> AnyPublisher<[Appointment], Error>
    func cancelAppointment(id: String) -> AnyPublisher<Void, Error>
}

class ConsumerScheduleRepository: ScheduleRepository {
    private let appointmentStore: AppointmentStore
    
    init(appointmentStore: AppointmentStore) {
        self.appointmentStore = appointmentStore
    }
    
    func getAppointments() -> AnyPublisher<[Appointment], Error> {
        Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(NSError(domain: "ConsumerScheduleRepository", code: -1)))
                return
            }
            let appointments = self.appointmentStore.getConsumerAppointments()
            promise(.success(appointments))
        }
        .eraseToAnyPublisher()
    }
    
    func cancelAppointment(id: String) -> AnyPublisher<Void, Error> {
        Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(NSError(domain: "ConsumerScheduleRepository", code: -1)))
                return
            }
            self.appointmentStore.cancel(appointmentId: id)
            promise(.success(()))
        }
        .eraseToAnyPublisher()
    }
}

class BusinessScheduleRepository: ScheduleRepository {
    private let appointmentStore: AppointmentStore
    private let businessCode: String
    
    init(appointmentStore: AppointmentStore, businessCode: String) {
        self.appointmentStore = appointmentStore
        self.businessCode = businessCode
    }
    
    func getAppointments() -> AnyPublisher<[Appointment], Error> {
        Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(NSError(domain: "BusinessScheduleRepository", code: -1)))
                return
            }
            let appointments = self.appointmentStore.getBusinessAppointments(for: self.businessCode)
            promise(.success(appointments))
        }
        .eraseToAnyPublisher()
    }
    
    func cancelAppointment(id: String) -> AnyPublisher<Void, Error> {
        Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(NSError(domain: "BusinessScheduleRepository", code: -1)))
                return
            }
            self.appointmentStore.cancel(appointmentId: id)
            promise(.success(()))
        }
        .eraseToAnyPublisher()
    }
}

