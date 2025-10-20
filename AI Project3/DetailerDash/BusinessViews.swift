//
//  BusinessViews.swift
//  DetailerDash
//
//  Business discovery, profile, and services management
//

import SwiftUI

// MARK: - Find Business View

struct FindBusinessView: View {
    @State private var searchHandle = ""
    @State private var foundBusiness: BusinessProfile?
    @State private var showNotFound = false
    @State private var navigateToProfile = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: Theme.paddingL) {
                VStack(alignment: .leading, spacing: Theme.paddingS) {
                    Text("Find a Business")
                        .font(Theme.headline(24))
                        .padding(.horizontal, Theme.paddingL)
                }
                .padding(.top, Theme.paddingL)
                
                // Format hint card
                Card {
                    VStack(alignment: .leading, spacing: Theme.paddingXS) {
                        HStack {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(Theme.accent)
                            Text("Handle Format")
                                .font(Theme.headline(14))
                                .foregroundColor(Theme.text)
                        }
                        
                        Text("Enter the business handle exactly as shown:")
                            .font(Theme.caption(12))
                            .foregroundColor(Theme.secondaryText)
                        
                        Text("BusinessName#12345")
                            .font(Theme.body(14))
                            .foregroundColor(Theme.primary)
                            .padding(.vertical, Theme.paddingXS)
                        
                        Text("• Not case-sensitive\n• Include the # and 5-digit code")
                            .font(Theme.caption(11))
                            .foregroundColor(Theme.secondaryText)
                    }
                    .padding(Theme.paddingM)
                }
                .padding(.horizontal, Theme.paddingL)
                
                HStack {
                    TextField("BusinessName#12345", text: $searchHandle)
                        .textFieldStyle(CustomTextFieldStyle())
                        .autocapitalization(.none)
                        .submitLabel(.search)
                        .onSubmit {
                            searchBusiness()
                        }
                    
                    Button(action: searchBusiness) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                            .frame(width: 50, height: 50)
                            .background(Theme.primary)
                            .cornerRadius(Theme.cornerRadiusM)
                    }
                }
                .padding(.horizontal, Theme.paddingL)
                
                if showNotFound {
                    Card {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(Theme.warning)
                            
                            Text("Business not found. Please check the handle and try again.")
                                .font(Theme.body(14))
                                .foregroundColor(Theme.text)
                        }
                        .padding(Theme.paddingM)
                    }
                    .padding(.horizontal, Theme.paddingL)
                }
                
                Spacer()
            }
            .navigationTitle("Find")
            .navigationDestination(isPresented: $navigateToProfile) {
                if let business = foundBusiness {
                    BusinessProfileView(businessProfile: business)
                }
            }
        }
    }
    
    private func searchBusiness() {
        showNotFound = false
        foundBusiness = nil
        navigateToProfile = false
        
        if let business = BusinessDirectory.shared.find(handle: searchHandle) {
            foundBusiness = business
            navigateToProfile = true
        } else {
            showNotFound = true
        }
    }
}

// MARK: - Business Profile View

struct BusinessProfileView: View {
    let businessProfile: BusinessProfile
    @State private var showBooking = false
    
    var body: some View {
        VStack(spacing: Theme.paddingL) {
            VStack(spacing: Theme.paddingS) {
                Image(systemName: "building.2")
                    .font(.system(size: 60))
                    .foregroundColor(Theme.primary)
                
                Text(businessProfile.businessName)
                    .font(Theme.title())
                    .foregroundColor(Theme.text)
                
                Text(businessProfile.handle)
                    .font(Theme.body())
                    .foregroundColor(Theme.secondaryText)
            }
            .padding(.top, Theme.paddingXL)
            
            Spacer()
            
            VStack(spacing: Theme.paddingM) {
                PrimaryButton(title: "Book with \(businessProfile.businessName)") {
                    showBooking = true
                }
                .padding(.horizontal, Theme.paddingL)
            }
            .padding(.bottom, Theme.paddingL)
        }
        .navigationTitle("Business")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showBooking) {
            BusinessServicesView(businessProfile: businessProfile)
        }
    }
}

// MARK: - Business Services View (for booking)

struct BusinessServicesView: View {
    let businessProfile: BusinessProfile
    @Environment(\.dismiss) private var dismiss
    
    @StateObject private var catalogViewModel: ServiceCatalogViewModel
    @State private var selectedService: Service?
    @State private var showBookingFlow = false
    
    init(businessProfile: BusinessProfile) {
        self.businessProfile = businessProfile
        let repository = LocalServiceRepository(businessCode: businessProfile.code)
        _catalogViewModel = StateObject(wrappedValue: ServiceCatalogViewModel(repository: repository))
    }
    
    var body: some View {
        NavigationView {
            Group {
                if catalogViewModel.isLoading {
                    ProgressView()
                } else if catalogViewModel.error != nil {
                    VStack(spacing: Theme.paddingM) {
                        Text("Failed to load services")
                            .font(Theme.body())
                            .foregroundColor(Theme.error)
                        
                        SecondaryButton(title: "Retry") {
                            catalogViewModel.loadServices()
                        }
                        .padding(.horizontal, Theme.paddingL)
                        
                        SecondaryButton(title: "Go Back") {
                            dismiss()
                        }
                        .padding(.horizontal, Theme.paddingL)
                    }
                } else if catalogViewModel.services.isEmpty {
                    VStack(spacing: Theme.paddingM) {
                        Image(systemName: "tray")
                            .font(.system(size: 60))
                            .foregroundColor(Theme.secondaryText)
                        
                        Text("No services available")
                            .font(Theme.headline())
                            .foregroundColor(Theme.text)
                        
                        Text("This business hasn't added any services yet")
                            .font(Theme.body(14))
                            .foregroundColor(Theme.secondaryText)
                            .multilineTextAlignment(.center)
                        
                        SecondaryButton(title: "Go Back") {
                            dismiss()
                        }
                        .padding(.horizontal, Theme.paddingL)
                    }
                    .padding(Theme.paddingL)
                } else {
                    ScrollView {
                        LazyVStack(spacing: Theme.paddingM) {
                            ForEach(catalogViewModel.services) { service in
                                ServiceCard(service: service, isSelected: false) {
                                    selectedService = service
                                    showBookingFlow = true
                                }
                            }
                        }
                        .padding(Theme.paddingL)
                    }
                }
            }
            .navigationTitle("\(businessProfile.businessName) Services")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                catalogViewModel.loadServices()
            }
            .fullScreenCover(isPresented: $showBookingFlow) {
                BookingFlowView(
                    businessProfile: businessProfile,
                    preselectedService: selectedService,
                    bookingRepository: MockBookingRepository(appointmentStore: AppointmentStore())
                )
            }
        }
    }
}

// MARK: - Services Manager View (Business Owner)

struct ServicesManagerView: View {
    @StateObject private var viewModel: ServicesManagerViewModel
    @State private var showAddService = false
    @State private var editingService: Service?
    
    init(businessCode: String) {
        let repository = LocalServiceRepository(businessCode: businessCode)
        _viewModel = StateObject(wrappedValue: ServicesManagerViewModel(repository: repository))
    }
    
    var body: some View {
        List {
            if viewModel.services.isEmpty {
                VStack(spacing: Theme.paddingM) {
                    Image(systemName: "tray")
                        .font(.system(size: 60))
                        .foregroundColor(Theme.secondaryText)
                    
                    Text("No services yet")
                        .font(Theme.headline())
                        .foregroundColor(Theme.text)
                    
                    Text("Add your first service to get started")
                        .font(Theme.body(14))
                        .foregroundColor(Theme.secondaryText)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(Theme.paddingL)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            } else {
                ForEach(viewModel.services) { service in
                    ServiceManagerRow(service: service) {
                        editingService = service
                    }
                }
                .onDelete { indexSet in
                    indexSet.forEach { index in
                        viewModel.deleteService(viewModel.services[index])
                    }
                }
                .onMove { from, to in
                    viewModel.moveService(from: from, to: to)
                }
            }
        }
        .navigationTitle("Services")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showAddService = true }) {
                    Image(systemName: "plus")
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                EditButton()
            }
        }
        .sheet(isPresented: $showAddService) {
            ServiceEditorView(onSave: { service in
                viewModel.addService(service)
                showAddService = false
            }, onCancel: {
                showAddService = false
            })
        }
        .sheet(item: $editingService) { service in
            ServiceEditorView(service: service, onSave: { updatedService in
                viewModel.updateService(updatedService)
                editingService = nil
            }, onCancel: {
                editingService = nil
            })
        }
    }
}

struct ServiceManagerRow: View {
    let service: Service
    let onEdit: () -> Void
    
    var body: some View {
        Button(action: onEdit) {
            HStack {
                VStack(alignment: .leading, spacing: Theme.paddingXS) {
                    Text(service.name)
                        .font(Theme.headline(16))
                        .foregroundColor(Theme.text)
                    
                    Text(service.category.rawValue)
                        .font(Theme.caption())
                        .foregroundColor(Theme.secondaryText)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: Theme.paddingXS) {
                    Text(service.displayPrice)
                        .font(Theme.headline(16))
                        .foregroundColor(Theme.primary)
                    
                    Text("\(service.durationMinutes) min")
                        .font(Theme.caption())
                        .foregroundColor(Theme.secondaryText)
                }
            }
        }
    }
}

// MARK: - Service Editor

struct ServiceEditorView: View {
    @State private var name: String
    @State private var description: String
    @State private var category: ServiceCategory
    @State private var durationMinutes: String
    @State private var priceText: String
    
    let serviceId: String?
    let onSave: (Service) -> Void
    let onCancel: () -> Void
    
    init(service: Service? = nil, onSave: @escaping (Service) -> Void, onCancel: @escaping () -> Void) {
        self.serviceId = service?.id
        _name = State(initialValue: service?.name ?? "")
        _description = State(initialValue: service?.description ?? "")
        _category = State(initialValue: service?.category ?? .detailing)
        _durationMinutes = State(initialValue: service != nil ? "\(service!.durationMinutes)" : "")
        
        if let service = service {
            let dollars = Double(service.basePriceCents) / 100.0
            _priceText = State(initialValue: String(format: "%.2f", dollars))
        } else {
            _priceText = State(initialValue: "")
        }
        
        self.onSave = onSave
        self.onCancel = onCancel
    }
    
    private var isValid: Bool {
        !name.isEmpty &&
        !description.isEmpty &&
        Int(durationMinutes) != nil &&
        Double(priceText) != nil
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Basic Information")) {
                    TextField("Service Name", text: $name)
                    
                    TextField("Description", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                    
                    Picker("Category", selection: $category) {
                        ForEach(ServiceCategory.allCases, id: \.self) { cat in
                            Text(cat.rawValue).tag(cat)
                        }
                    }
                }
                
                Section(header: Text("Pricing & Duration")) {
                    HStack {
                        Text("$")
                        TextField("0.00", text: $priceText)
                            .keyboardType(.decimalPad)
                    }
                    
                    HStack {
                        TextField("Duration", text: $durationMinutes)
                            .keyboardType(.numberPad)
                        Text("minutes")
                            .foregroundColor(Theme.secondaryText)
                    }
                }
            }
            .navigationTitle(serviceId == nil ? "Add Service" : "Edit Service")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel", action: onCancel)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveService()
                    }
                    .disabled(!isValid)
                }
            }
        }
    }
    
    private func saveService() {
        guard isValid,
              let duration = Int(durationMinutes),
              let price = Double(priceText) else { return }
        
        let priceCents = Int(price * 100)
        
        let service = Service(
            id: serviceId ?? UUID().uuidString,
            name: name,
            description: description,
            durationMinutes: duration,
            basePriceCents: priceCents,
            category: category
        )
        
        onSave(service)
    }
}

