# DetailerDash

A production-quality SwiftUI iOS app for managing auto detailing services with both consumer and business modes.

## Requirements

- iOS 16.0+
- Xcode 15.0+
- Swift 5.0+

## Features

### Authentication
- First-launch authentication screen with Sign In and Create Account tabs
- Account types: Personal (Consumer) and Business
- Password validation: Users must provide correct email AND password to sign in
- Persistent authentication state (never shows auth screen after initial login unless signed out)
- Automatic routing based on account type
- **Note**: Passwords stored in plain text for demo purposes only (not production-ready)

### Business Directory
- Unique 5-digit business codes (e.g., 11445)
- Public handle format: `BusinessName#12345`
- Case-insensitive search with whitespace trimming
- Copy handle button for easy sharing
- Consumer "Find" tab to search and discover businesses
- Business profile pages with booking capabilities
- Multiple businesses can share the same name (uniquely identified by code)

### Services Management (Business Mode)
- Empty services on business account creation
- Add, edit, delete, and reorder services
- Per-business service storage using business code
- Service fields: name, description, duration, price, category
- Accessible from Settings and dedicated Services tab

### AI Booking Assistant
- Conversational interface powered by rule-based NLP (Natural Language Processing)
- Helps users discover services and start bookings through natural conversation
- Intelligent intent detection (greetings, service inquiries, pricing, duration, booking requests)
- Extracts booking information from chat (vehicle details, service preferences, dates)
- Context-aware responses based on available services
- Pattern matching for vehicle makes (30+ manufacturers), years, colors, and models
- Keyword detection for service categories (detailing, wash, coating, etc.)
- No external API calls - completely local processing for privacy and speed
- Accessible from business profile and services catalog views

### Booking Flow (Consumer Mode)
- 5-step booking process:
  1. Select Service
  2. Select Date (14-day horizontal picker)
  3. Select Time (30-minute slot grid)
  4. Enter Details (customer info, vehicle info, notes)
  5. Confirm Booking
- Real-time validation with specific missing field messages
- Idempotent booking with request IDs (prevents duplicate bookings)
- Loading states and success confirmation
- Optional AI Assistant to help with service discovery before booking

### Schedule
- Shows upcoming appointments (hides past appointments)
- Format: "EEE, MMM d • h:mm a • ServiceName"
- Subtitle: "CustomerName • Year Color Model" (Color omitted if not provided)
- Consumer mode: shows user's bookings
- Business mode: shows all client bookings for the business
- Auto-refresh via NotificationCenter on bookings/cancellations
- Detail view with appointment info and cancel functionality

### Appointment Management
- Stored in UserDefaults with separate consumer and business arrays
- Idempotency: prevents duplicate bookings for same time/customer
- Cancel functionality removes from both consumer and business schedules
- Real-time updates across the app via notifications

### Settings
- Account information display
- Business handle display (for business accounts)
- Link to Services Manager (for business accounts)
- App mode picker (Consumer/Business) for demo purposes
- Sign Out with confirmation dialog

## Architecture

### MVVM Pattern
- **Models**: Service, Appointment, Customer, Vehicle, BusinessProfile, ChatMessage, ExtractedBookingInfo
- **ViewModels**: AuthViewModel, BookingViewModel, ServiceCatalogViewModel, ServicesManagerViewModel, ScheduleViewModel, AIAssistantViewModel
- **Views**: Organized by feature (Auth, Booking, Schedule, Business, Settings, AI Assistant)

### Repository Pattern
- `ServiceRepository` / `MutableServiceRepository`: Service data access
- `BookingRepository`: Appointment creation and slot availability
- `ScheduleRepository`: Consumer and Business schedule implementations

### Storage
- UserDefaults for all persistence:
  - User authentication and profile
  - Per-business services (keyed by business code)
  - Appointments (separate consumer and business arrays)
  - Business directory
  - App state and mode

### Services Layer
- `AuthStore`: Authentication state management
- `AppointmentStore`: Centralized appointment storage with notifications
- `BusinessDirectory`: Business lookup and code generation
- `AppState`: App mode (consumer/business) management

## UI/UX

### Design System
- Dark theme by default
- Rounded font family for modern look
- Vibrant primary color (purple-blue) with gradients
- Consistent spacing and padding
- Elevated cards with subtle shadows
- Pill tags for status indicators

### Reusable Components
- `Card`: Elevated container with shadow
- `PrimaryButton`: Gradient button with loading state
- `SecondaryButton`: Flat button style
- `Tag`: Pill-shaped status indicator
- `CustomTextFieldStyle`: Consistent text input styling

### Tab Structure

**Consumer Mode:**
- Schedule
- Find
- Settings

**Business Mode:**
- Schedule
- Services
- Settings

## Data Flow

1. **Authentication**: AuthStore → saves to UserDefaults → updates app state
2. **Booking**: BookingViewModel → BookingRepository → AppointmentStore → NotificationCenter → ScheduleViewModel
3. **Services**: ServicesManagerViewModel → MutableServiceRepository → UserDefaults (per business)
4. **Schedule**: ScheduleRepository → AppointmentStore → NotificationCenter updates

## Validation & Edge Cases

### Booking Validation
- Required fields: service, first name, last name, email, phone, vehicle make, vehicle model, vehicle year (≥4 digits), time
- Year sanitization: strips commas and non-digit characters
- Missing fields banner shows specific field names

### Services
- Empty state for new businesses
- Load error handling with retry
- No services available message with back navigation

### Appointments
- Hide fully past appointments (endDate < now)
- Detail view omits Color field (spec requirement)
- Year displayed without commas (e.g., 2018 not 2,018)

## Project Structure

```
DetailerDash/
├── DetailerDashApp.swift       # App entry point
├── Models.swift                # Data models
├── Repositories.swift          # Repository protocols and implementations
├── Stores.swift                # State management and storage
├── Theme.swift                 # Design system and reusable components
├── ViewModels.swift            # All ViewModels
├── AuthView.swift              # Authentication UI
├── AIAssistantView.swift       # AI chat interface for booking assistance
├── BookingFlowView.swift       # Complete booking flow
├── ScheduleView.swift          # Schedule list and detail
├── BusinessViews.swift         # Find, profile, services manager
├── SettingsView.swift          # Settings screen
└── RootView.swift              # Root navigation and tabs
```

## Building & Running

1. Open `DetailerDash.xcodeproj` in Xcode
2. Select a simulator or device (iOS 16.0+)
3. Build and run (⌘R)

## Testing the App

### Consumer Flow
1. Create account with "Personal" type
2. Use "Find" tab to search for a business by handle
3. Try the AI Assistant on business profile
   - Ask questions like "What services do you offer?"
   - Test natural language: "I need a detail for my 2020 Honda Civic"
   - Check pricing: "How much is a full detail?"
   - Start booking from AI chat
4. Book appointment through complete flow
5. View appointment in Schedule
6. Cancel appointment from detail view

### Business Flow
1. Create account with "Business" type and business name
2. Note your business handle in Settings
3. Add services via Services tab or Settings
4. Share handle with consumers
5. View incoming bookings in Schedule

### Demo Mode
- Switch between Consumer and Business modes in Settings
- Useful for testing both perspectives without multiple accounts

## Known Behaviors

- Mock sign-in accepts any credentials
- Time slots are randomly available (mock data)
- No network calls (all local storage)

## No Third-Party Dependencies

This app uses only native iOS frameworks:
- SwiftUI
- Foundation
- Combine

No external AI APIs or SDKs required - the AI Assistant uses built-in pattern matching and natural language processing techniques.

## License

Copyright © 2025. All rights reserved.
