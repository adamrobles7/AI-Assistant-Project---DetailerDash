//
//  ScheduleView.swift
//  DetailerDash
//
//  Schedule list and appointment detail views
//

import SwiftUI

struct ScheduleView: View {
    @StateObject private var viewModel: ScheduleViewModel
    
    init(repository: ScheduleRepository) {
        _viewModel = StateObject(wrappedValue: ScheduleViewModel(repository: repository))
    }
    
    var body: some View {
        NavigationView {
            Group {
                if viewModel.isLoading {
                    ProgressView()
                } else if viewModel.upcomingAppointments.isEmpty {
                    VStack(spacing: Theme.paddingM) {
                        Image(systemName: "calendar.badge.exclamationmark")
                            .font(.system(size: 60))
                            .foregroundColor(Theme.secondaryText)
                        
                        Text("No upcoming appointments")
                            .font(Theme.headline())
                            .foregroundColor(Theme.text)
                        
                        Text("Your scheduled appointments will appear here")
                            .font(Theme.body(14))
                            .foregroundColor(Theme.secondaryText)
                            .multilineTextAlignment(.center)
                    }
                    .padding(Theme.paddingL)
                } else {
                    ScrollView {
                        LazyVStack(spacing: Theme.paddingM) {
                            ForEach(viewModel.upcomingAppointments) { appointment in
                                NavigationLink(destination: AppointmentDetailView(appointment: appointment, viewModel: viewModel)) {
                                    AppointmentRow(appointment: appointment)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(Theme.paddingL)
                    }
                }
            }
            .navigationTitle("Schedule")
            .onAppear {
                viewModel.loadAppointments()
            }
        }
    }
}

struct AppointmentRow: View {
    let appointment: Appointment
    
    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: Theme.paddingS) {
                // Header with date, time, and service
                Text(appointment.listHeaderText)
                    .font(Theme.headline(16))
                    .foregroundColor(Theme.text)
                
                // Subtitle with customer and vehicle
                Text(appointment.listSubtitleText)
                    .font(Theme.body(14))
                    .foregroundColor(Theme.secondaryText)
                
                HStack {
                    Tag(text: "Upcoming", color: Theme.accent)
                    
                    Spacer()
                    
                    Text(appointment.displayTotal)
                        .font(Theme.headline(16))
                        .foregroundColor(Theme.primary)
                }
            }
            .padding(Theme.paddingM)
        }
    }
}

struct AppointmentDetailView: View {
    let appointment: Appointment
    @ObservedObject var viewModel: ScheduleViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var showCancelConfirmation = false
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }
    
    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.paddingL) {
                // Time Range
                DetailSection(title: "Time") {
                    HStack {
                        Image(systemName: "clock")
                            .foregroundColor(Theme.primary)
                        
                        VStack(alignment: .leading, spacing: Theme.paddingXS) {
                            Text(dateFormatter.string(from: appointment.startDate))
                                .font(Theme.body())
                            
                            Text("\(timeFormatter.string(from: appointment.startDate)) - \(timeFormatter.string(from: appointment.endDate))")
                                .font(Theme.caption())
                                .foregroundColor(Theme.secondaryText)
                        }
                    }
                }
                
                // Customer
                DetailSection(title: "Customer") {
                    HStack {
                        Image(systemName: "person")
                            .foregroundColor(Theme.primary)
                        
                        VStack(alignment: .leading, spacing: Theme.paddingXS) {
                            Text(appointment.customer.fullName)
                                .font(Theme.body())
                            
                            Text(appointment.customer.email)
                                .font(Theme.caption())
                                .foregroundColor(Theme.secondaryText)
                            
                            Text(appointment.customer.phone)
                                .font(Theme.caption())
                                .foregroundColor(Theme.secondaryText)
                        }
                    }
                }
                
                // Vehicle (Year Make Model - no Color)
                DetailSection(title: "Vehicle") {
                    HStack {
                        Image(systemName: "car")
                            .foregroundColor(Theme.primary)
                        
                        Text(appointment.vehicle.detailDisplayName)
                            .font(Theme.body())
                    }
                }
                
                // Items
                DetailSection(title: "Services") {
                    VStack(alignment: .leading, spacing: Theme.paddingS) {
                        ForEach(appointment.items, id: \.name) { item in
                            HStack {
                                Text(item.name)
                                    .font(Theme.body())
                                
                                Spacer()
                                
                                Text(item.displayPrice)
                                    .font(Theme.body())
                                    .foregroundColor(Theme.primary)
                            }
                        }
                        
                        Divider()
                        
                        HStack {
                            Text("Total")
                                .font(Theme.headline())
                            
                            Spacer()
                            
                            Text(appointment.displayTotal)
                                .font(Theme.headline())
                                .foregroundColor(Theme.primary)
                        }
                    }
                }
                
                // Notes
                if let notes = appointment.notes, !notes.isEmpty {
                    DetailSection(title: "Notes") {
                        Text(notes)
                            .font(Theme.body(14))
                            .foregroundColor(Theme.secondaryText)
                    }
                }
            }
            .padding(Theme.paddingL)
        }
        .navigationTitle("Appointment")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(role: .destructive) {
                    showCancelConfirmation = true
                } label: {
                    Text("Cancel")
                        .foregroundColor(Theme.error)
                }
            }
        }
        .alert("Cancel Appointment", isPresented: $showCancelConfirmation) {
            Button("No", role: .cancel) {}
            Button("Yes", role: .destructive) {
                viewModel.cancelAppointment(id: appointment.id)
                dismiss()
            }
        } message: {
            Text("Are you sure you want to cancel this appointment?")
        }
    }
}

struct DetailSection<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.paddingS) {
            Text(title)
                .font(Theme.caption(12))
                .foregroundColor(Theme.secondaryText)
                .textCase(.uppercase)
            
            Card {
                content
                    .padding(Theme.paddingM)
            }
        }
    }
}

