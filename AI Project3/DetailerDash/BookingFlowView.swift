//
//  BookingFlowView.swift
//  DetailerDash
//
//  Complete booking flow: Service → Date → Time → Details → Confirm
//

import SwiftUI

struct BookingFlowView: View {
    @StateObject private var viewModel: BookingViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var currentStep = 0
    
    let businessProfile: BusinessProfile
    let preselectedService: Service?
    
    init(businessProfile: BusinessProfile, preselectedService: Service?, bookingRepository: BookingRepository) {
        self.businessProfile = businessProfile
        self.preselectedService = preselectedService
        _viewModel = StateObject(wrappedValue: BookingViewModel(bookingRepository: bookingRepository, businessProfile: businessProfile))
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if viewModel.bookingSuccess {
                    BookingSuccessView {
                        dismiss()
                    }
                } else {
                    // Progress indicator
                    ProgressBar(currentStep: currentStep, totalSteps: 5)
                        .padding(.horizontal, Theme.paddingL)
                        .padding(.vertical, Theme.paddingM)
                    
                    // Content
                    TabView(selection: $currentStep) {
                        ServiceSelectionStep(viewModel: viewModel)
                            .tag(0)
                        
                        DateSelectionStep(viewModel: viewModel)
                            .tag(1)
                        
                        TimeSelectionStep(viewModel: viewModel)
                            .tag(2)
                        
                        DetailsStep(viewModel: viewModel)
                            .tag(3)
                        
                        ConfirmationStep(viewModel: viewModel)
                            .tag(4)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    
                    // Navigation buttons
                    HStack(spacing: Theme.paddingM) {
                        if currentStep > 0 {
                            SecondaryButton(title: "Back") {
                                withAnimation {
                                    currentStep -= 1
                                }
                            }
                        }
                        
                        if currentStep < 4 {
                            PrimaryButton(
                                title: "Next",
                                action: {
                                    withAnimation {
                                        currentStep += 1
                                    }
                                },
                                isDisabled: !canProceed
                            )
                        } else {
                            PrimaryButton(
                                title: "Book",
                                action: viewModel.book,
                                isLoading: viewModel.isBooking,
                                isDisabled: !viewModel.isValid
                            )
                        }
                    }
                    .padding(.horizontal, Theme.paddingL)
                    .padding(.bottom, Theme.paddingL)
                }
            }
            .navigationTitle("Book Appointment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            if let service = preselectedService {
                viewModel.selectedService = service
            }
        }
    }
    
    private var canProceed: Bool {
        switch currentStep {
        case 0: return viewModel.selectedService != nil
        case 1: return viewModel.selectedDate != nil
        case 2: return viewModel.selectedTime != nil
        case 3: return true
        default: return false
        }
    }
}

struct ProgressBar: View {
    let currentStep: Int
    let totalSteps: Int
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Theme.tertiaryBackground)
                    .frame(height: 4)
                
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [Theme.primary, Theme.primaryLight],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geometry.size.width * CGFloat(currentStep + 1) / CGFloat(totalSteps), height: 4)
            }
        }
        .frame(height: 4)
    }
}

// MARK: - Step 1: Service Selection

struct ServiceSelectionStep: View {
    @ObservedObject var viewModel: BookingViewModel
    @StateObject private var catalogViewModel: ServiceCatalogViewModel
    
    init(viewModel: BookingViewModel) {
        self.viewModel = viewModel
        let repository = LocalServiceRepository(businessCode: viewModel.businessProfile.code)
        _catalogViewModel = StateObject(wrappedValue: ServiceCatalogViewModel(repository: repository))
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.paddingM) {
                Text("Select a Service")
                    .font(Theme.headline(24))
                    .padding(.horizontal, Theme.paddingL)
                    .padding(.top, Theme.paddingM)
                
                if catalogViewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding()
                } else if catalogViewModel.error != nil {
                    VStack(spacing: Theme.paddingM) {
                        Text("Failed to load services")
                            .font(Theme.body())
                            .foregroundColor(Theme.error)
                        
                        SecondaryButton(title: "Retry") {
                            catalogViewModel.loadServices()
                        }
                    }
                    .padding(.horizontal, Theme.paddingL)
                } else if catalogViewModel.services.isEmpty {
                    Text("No services available")
                        .font(Theme.body())
                        .foregroundColor(Theme.secondaryText)
                        .padding(.horizontal, Theme.paddingL)
                } else {
                    ForEach(catalogViewModel.services) { service in
                        ServiceCard(service: service, isSelected: viewModel.selectedService?.id == service.id) {
                            viewModel.selectedService = service
                        }
                        .padding(.horizontal, Theme.paddingL)
                    }
                }
            }
            .padding(.bottom, Theme.paddingL)
        }
        .onAppear {
            catalogViewModel.loadServices()
        }
    }
}

struct ServiceCard: View {
    let service: Service
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: Theme.paddingS) {
                HStack {
                    VStack(alignment: .leading, spacing: Theme.paddingXS) {
                        Text(service.name)
                            .font(Theme.headline(18))
                            .foregroundColor(Theme.text)
                        
                        Text(service.category.rawValue)
                            .font(Theme.caption())
                            .foregroundColor(Theme.secondaryText)
                    }
                    
                    Spacer()
                    
                    Text(service.displayPrice)
                        .font(Theme.headline(18))
                        .foregroundColor(Theme.primary)
                }
                
                Text(service.description)
                    .font(Theme.body(14))
                    .foregroundColor(Theme.secondaryText)
                
                Text("\(service.durationMinutes) minutes")
                    .font(Theme.caption())
                    .foregroundColor(Theme.secondaryText)
            }
            .padding(Theme.paddingM)
            .background(isSelected ? Theme.primary.opacity(0.1) : Theme.cardBackground)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cornerRadiusM)
                    .stroke(isSelected ? Theme.primary : Color.clear, lineWidth: 2)
            )
            .cornerRadius(Theme.cornerRadiusM)
            .shadow(color: Color.black.opacity(0.1), radius: Theme.shadowMedium, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Step 2: Date Selection

struct DateSelectionStep: View {
    @ObservedObject var viewModel: BookingViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.paddingM) {
            Text("Select a Date")
                .font(Theme.headline(24))
                .padding(.horizontal, Theme.paddingL)
                .padding(.top, Theme.paddingM)
            
            WeekPicker(selectedDate: $viewModel.selectedDate)
                .onChange(of: viewModel.selectedDate) { _ in
                    viewModel.loadAvailableSlots()
                }
            
            Spacer()
        }
    }
}

struct WeekPicker: View {
    @Binding var selectedDate: Date?
    
    private var dates: [Date] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return (0..<14).compactMap { calendar.date(byAdding: .day, value: $0, to: today) }
    }
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.paddingS) {
                ForEach(dates, id: \.self) { date in
                    DateCell(date: date, isSelected: calendar.isDate(date, inSameDayAs: selectedDate ?? Date.distantPast)) {
                        selectedDate = date
                    }
                }
            }
            .padding(.horizontal, Theme.paddingL)
        }
    }
    
    private var calendar: Calendar { Calendar.current }
}

struct DateCell: View {
    let date: Date
    let isSelected: Bool
    let onTap: () -> Void
    
    private var dayFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter
    }
    
    private var numberFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: Theme.paddingXS) {
                Text(dayFormatter.string(from: date))
                    .font(Theme.caption(12))
                    .foregroundColor(isSelected ? .white : Theme.secondaryText)
                
                Text(numberFormatter.string(from: date))
                    .font(Theme.headline(18))
                    .foregroundColor(isSelected ? .white : Theme.text)
            }
            .frame(width: 60, height: 70)
            .background(isSelected ? Theme.primary : Theme.cardBackground)
            .cornerRadius(Theme.cornerRadiusM)
            .shadow(color: Color.black.opacity(0.1), radius: Theme.shadowMedium, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Step 3: Time Selection

struct TimeSelectionStep: View {
    @ObservedObject var viewModel: BookingViewModel
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.paddingM) {
                Text("Select a Time")
                    .font(Theme.headline(24))
                    .padding(.horizontal, Theme.paddingL)
                    .padding(.top, Theme.paddingM)
                
                if viewModel.isLoadingSlots {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding()
                } else if viewModel.availableSlots.isEmpty {
                    Text("No available time slots for this date")
                        .font(Theme.body())
                        .foregroundColor(Theme.secondaryText)
                        .padding(.horizontal, Theme.paddingL)
                } else {
                    TimeSlotGrid(
                        slots: viewModel.availableSlots,
                        selectedTime: $viewModel.selectedTime
                    )
                    .padding(.horizontal, Theme.paddingL)
                }
            }
            .padding(.bottom, Theme.paddingL)
        }
    }
}

struct TimeSlotGrid: View {
    let slots: [Date]
    @Binding var selectedTime: Date?
    
    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }
    
    var body: some View {
        LazyVGrid(columns: columns, spacing: Theme.paddingS) {
            ForEach(slots, id: \.self) { slot in
                TimeSlotButton(
                    time: timeFormatter.string(from: slot),
                    isSelected: selectedTime?.timeIntervalSince1970 == slot.timeIntervalSince1970
                ) {
                    selectedTime = slot
                }
            }
        }
    }
}

struct TimeSlotButton: View {
    let time: String
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            Text(time)
                .font(Theme.body(14))
                .foregroundColor(isSelected ? .white : Theme.text)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.paddingM)
                .background(isSelected ? Theme.primary : Theme.cardBackground)
                .cornerRadius(Theme.cornerRadiusM)
                .shadow(color: Color.black.opacity(0.1), radius: Theme.shadowMedium, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Step 4: Details

struct DetailsStep: View {
    @ObservedObject var viewModel: BookingViewModel
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.paddingL) {
                Text("Your Details")
                    .font(Theme.headline(24))
                    .padding(.horizontal, Theme.paddingL)
                    .padding(.top, Theme.paddingM)
                
                VStack(spacing: Theme.paddingM) {
                    // Customer details
                    SectionHeader(title: "Customer Information")
                    
                    TextField("First Name", text: $viewModel.customerFirstName)
                        .textFieldStyle(CustomTextFieldStyle())
                    
                    TextField("Last Name", text: $viewModel.customerLastName)
                        .textFieldStyle(CustomTextFieldStyle())
                    
                    TextField("Email", text: $viewModel.customerEmail)
                        .textFieldStyle(CustomTextFieldStyle())
                        .textContentType(.emailAddress)
                        .autocapitalization(.none)
                        .keyboardType(.emailAddress)
                    
                    TextField("Phone", text: $viewModel.customerPhone)
                        .textFieldStyle(CustomTextFieldStyle())
                        .textContentType(.telephoneNumber)
                        .keyboardType(.phonePad)
                    
                    // Vehicle details
                    SectionHeader(title: "Vehicle Information")
                    
                    TextField("Year", text: $viewModel.vehicleYear)
                        .textFieldStyle(CustomTextFieldStyle())
                        .keyboardType(.numberPad)
                        .onChange(of: viewModel.vehicleYear) { newValue in
                            viewModel.vehicleYear = viewModel.sanitizeYear(newValue)
                        }
                    
                    TextField("Make", text: $viewModel.vehicleMake)
                        .textFieldStyle(CustomTextFieldStyle())
                    
                    TextField("Model", text: $viewModel.vehicleModel)
                        .textFieldStyle(CustomTextFieldStyle())
                    
                    TextField("Color (Optional)", text: $viewModel.vehicleColor)
                        .textFieldStyle(CustomTextFieldStyle())
                    
                    // Notes
                    SectionHeader(title: "Additional Notes (Optional)")
                    
                    TextEditor(text: $viewModel.notes)
                        .font(Theme.body())
                        .frame(height: 100)
                        .padding(Theme.paddingS)
                        .background(Theme.tertiaryBackground)
                        .cornerRadius(Theme.cornerRadiusM)
                }
                .padding(.horizontal, Theme.paddingL)
            }
            .padding(.bottom, Theme.paddingL)
        }
    }
}

struct SectionHeader: View {
    let title: String
    
    var body: some View {
        Text(title)
            .font(Theme.headline(16))
            .foregroundColor(Theme.secondaryText)
    }
}

// MARK: - Step 5: Confirmation

struct ConfirmationStep: View {
    @ObservedObject var viewModel: BookingViewModel
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.paddingL) {
                Text("Confirm Booking")
                    .font(Theme.headline(24))
                    .padding(.horizontal, Theme.paddingL)
                    .padding(.top, Theme.paddingM)
                
                if !viewModel.isValid {
                    Card {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(Theme.warning)
                            
                            Text(viewModel.confirmationMessage)
                                .font(Theme.body(14))
                                .foregroundColor(Theme.text)
                        }
                        .padding(Theme.paddingM)
                    }
                    .padding(.horizontal, Theme.paddingL)
                } else {
                    VStack(spacing: Theme.paddingM) {
                        Text(viewModel.confirmationMessage)
                            .font(Theme.body())
                            .foregroundColor(Theme.text)
                            .multilineTextAlignment(.leading)
                        
                        if let service = viewModel.selectedService {
                            Card {
                                VStack(alignment: .leading, spacing: Theme.paddingS) {
                                    HStack {
                                        Text("Service")
                                            .font(Theme.caption())
                                            .foregroundColor(Theme.secondaryText)
                                        Spacer()
                                        Text(service.name)
                                            .font(Theme.body())
                                    }
                                    
                                    HStack {
                                        Text("Price")
                                            .font(Theme.caption())
                                            .foregroundColor(Theme.secondaryText)
                                        Spacer()
                                        Text(service.displayPrice)
                                            .font(Theme.body())
                                    }
                                    
                                    HStack {
                                        Text("Duration")
                                            .font(Theme.caption())
                                            .foregroundColor(Theme.secondaryText)
                                        Spacer()
                                        Text("\(service.durationMinutes) minutes")
                                            .font(Theme.body())
                                    }
                                }
                                .padding(Theme.paddingM)
                            }
                        }
                    }
                    .padding(.horizontal, Theme.paddingL)
                }
                
                if let error = viewModel.bookingError {
                    Text(error)
                        .font(Theme.caption())
                        .foregroundColor(Theme.error)
                        .padding(.horizontal, Theme.paddingL)
                }
            }
            .padding(.bottom, Theme.paddingL)
        }
    }
}

// MARK: - Booking Success

struct BookingSuccessView: View {
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(spacing: Theme.paddingL) {
            Spacer()
            
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(Theme.success)
            
            Text("Booking Confirmed!")
                .font(Theme.title())
                .foregroundColor(Theme.text)
            
            Text("Your appointment has been scheduled successfully.")
                .font(Theme.body())
                .foregroundColor(Theme.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.paddingXL)
            
            Spacer()
            
            PrimaryButton(title: "Done", action: onDismiss)
                .padding(.horizontal, Theme.paddingL)
        }
        .padding(.bottom, Theme.paddingL)
    }
}

