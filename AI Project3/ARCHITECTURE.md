# DetailerDash Architecture

## App Flow Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                        First Launch                             │
│                      AuthView (Sign In / Create Account)        │
└───────────────────────┬─────────────────────────────────────────┘
                        │
                        ├── Personal Account → Consumer Mode
                        └── Business Account → Business Mode
                                    │
                                    └── Generate Business Code (5-digit)
                                        Store as BusinessName#12345

┌─────────────────────────────────────────────────────────────────┐
│                     Consumer Mode (TabView)                      │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  Tab 1: Schedule                                                │
│  ├── List of appointments (upcoming only)                       │
│  └── AppointmentDetailView → Cancel                            │
│                                                                  │
│  Tab 2: Find                                                    │
│  ├── Format hint card (case-insensitive search)                │
│  ├── Search by handle (BusinessName#12345)                     │
│  ├── BusinessProfileView                                        │
│  │   └── "Book with [business]" button                         │
│  │       └── BusinessServicesView (list services)              │
│  │           └── Select service → BookingFlowView              │
│  │               ├── Step 1: Select Service                    │
│  │               ├── Step 2: Select Date (14-day picker)       │
│  │               ├── Step 3: Select Time (30-min slots)        │
│  │               ├── Step 4: Enter Details                     │
│  │               └── Step 5: Confirm → Book                    │
│  │                   └── Success → Back to Schedule            │
│                                                                  │
│  Tab 3: Settings                                                │
│  ├── Account Info                                               │
│  ├── App Mode Picker (demo)                                     │
│  └── Sign Out                                                   │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                     Business Mode (TabView)                      │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  Tab 1: Schedule                                                │
│  ├── List of client appointments (upcoming only)                │
│  └── AppointmentDetailView → Cancel                            │
│                                                                  │
│  Tab 2: Services                                                │
│  ├── ServicesManagerView                                        │
│  │   ├── Add Service → ServiceEditorView                       │
│  │   ├── Edit Service → ServiceEditorView                      │
│  │   ├── Delete Service                                         │
│  │   └── Reorder Services                                       │
│                                                                  │
│  Tab 3: Settings                                                │
│  ├── Account Info                                               │
│  ├── Business Handle Display with Copy Button (NEW)             │
│  ├── Manage Services Link                                       │
│  ├── App Mode Picker (demo)                                     │
│  └── Sign Out                                                   │
└─────────────────────────────────────────────────────────────────┘
```

## Data Flow

```
┌──────────────────────────────────────────────────────────────┐
│                      UserDefaults                             │
├──────────────────────────────────────────────────────────────┤
│                                                               │
│  auth.user              → Current user data (with password)  │
│  auth.hasAuthenticated  → Authentication status              │
│  auth.userRegistry      → All registered users (NEW)         │
│  app.mode               → Consumer/Business mode (demo)      │
│  business.directory     → BusinessProfile lookup table       │
│  business.usedCodes     → Set of generated codes             │
│  services.profile.XXXXX → Services per business code         │
│  appointments.consumer  → Consumer's appointments            │
│  appointments.business  → All business appointments          │
│                                                               │
└──────────────────────────────────────────────────────────────┘
```

## MVVM Architecture

```
┌─────────────┐       ┌──────────────┐       ┌─────────────┐
│    View     │◄──────│  ViewModel   │◄──────│    Model    │
└─────────────┘       └──────────────┘       └─────────────┘
      │                      │                       │
      │                      │                       │
   SwiftUI            @Published              Codable Structs
   Bindings           Properties              Identifiable
      │                      │                       │
      │                      ▼                       │
      │              ┌──────────────┐                │
      │              │ Repository   │                │
      │              └──────────────┘                │
      │                      │                       │
      │                      ▼                       │
      │              ┌──────────────┐                │
      └─────────────►│    Store     │◄───────────────┘
                     └──────────────┘
                            │
                            ▼
                     UserDefaults
```

## Key Components

### Models
- **User**: id, firstName, lastName, email, **password**, accountType, businessProfile?
  - Password stored in plain text (demo only - production should use hashing)
- **BusinessProfile**: businessName, code, handle (computed)
- **Service**: id, name, description, durationMinutes, basePriceCents, category
- **Appointment**: id, service, startDate, endDate, customer, vehicle, items, notes, businessCode, businessName
- **Customer**: firstName, lastName, email, phone
- **Vehicle**: year, make, model, color?

### Repositories
- **ServiceRepository**: getServices()
- **MutableServiceRepository**: getServices(), saveServices()
- **LocalServiceRepository**: Per-business service storage
- **BookingRepository**: availableSlots(), createAppointment()
- **MockBookingRepository**: Mock implementation with idempotency
- **ScheduleRepository**: getAppointments(), cancelAppointment()
- **ConsumerScheduleRepository**: Consumer appointments
- **BusinessScheduleRepository**: Business appointments filtered by code

### Stores
- **AuthStore**: User authentication and profile management
  - Maintains user registry for all created accounts
  - Validates email AND password on sign-in
  - Stores current user and authentication state
- **AppointmentStore**: Centralized appointment CRUD with notifications
- **BusinessDirectory**: Business lookup and code generation
  - Case-insensitive handle search
  - Whitespace trimming on search input
  - Unique code generation (5-digit, zero-padded)
- **AppState**: App mode (consumer/business) management

### ViewModels
- **AuthViewModel**: Sign in/create account logic
- **BookingViewModel**: Complete booking flow state and validation
- **ServiceCatalogViewModel**: Service listing for consumers
- **ServicesManagerViewModel**: Service CRUD for business owners
- **ScheduleViewModel**: Appointment listing and cancellation

## Notification Flow

```
┌──────────────────────┐
│ BookingRepository    │
│ createAppointment()  │
└──────────┬───────────┘
           │
           ▼
┌──────────────────────┐
│ AppointmentStore     │
│ add(appointment)     │
└──────────┬───────────┘
           │
           ▼
┌──────────────────────────────────────┐
│ NotificationCenter                   │
│ .appointmentCreated                  │
└──────────┬───────────────────────────┘
           │
           ├─────────► ScheduleViewModel.loadAppointments()
           │
           └─────────► Auto-refresh UI

Same flow for cancellations with .appointmentCancelled
```

## Idempotency Strategy

```
┌────────────────────────────────────────────────────────┐
│  Booking Request with requestId (UUID)                 │
└────────────────────┬───────────────────────────────────┘
                     │
                     ▼
┌────────────────────────────────────────────────────────┐
│  Check 1: Dedupe by (startDate + customer.email)      │
│  Already exists? → Return existing                     │
└────────────────────┬───────────────────────────────────┘
                     │ No match
                     ▼
┌────────────────────────────────────────────────────────┐
│  Check 2: requestId already processed?                 │
│  Yes? → Find and return by requestId                   │
└────────────────────┬───────────────────────────────────┘
                     │ Not processed
                     ▼
┌────────────────────────────────────────────────────────┐
│  Create new appointment                                │
│  Store requestId in processedRequests                  │
│  Save to AppointmentStore                              │
│  Post notification                                     │
└────────────────────────────────────────────────────────┘
```

## Design System

```
Theme
├── Colors
│   ├── primary: Purple-blue (#6747E6)
│   ├── primaryLight: Lighter variant
│   ├── accent: Cyan-blue
│   ├── background: System background
│   ├── cardBackground: Secondary background
│   └── text: Primary/Secondary
│
├── Fonts (Rounded)
│   ├── title: Bold, 28pt
│   ├── headline: Semibold, 20pt
│   ├── body: Regular, 16pt
│   └── caption: Regular, 14pt
│
├── Spacing
│   ├── XS: 4pt
│   ├── S: 8pt
│   ├── M: 16pt
│   ├── L: 24pt
│   └── XL: 32pt
│
└── Components
    ├── Card: Elevated, shadowed container
    ├── PrimaryButton: Gradient with loading state
    ├── SecondaryButton: Flat style
    └── Tag: Pill-shaped status badge
```

## Validation Rules

### Authentication
- **Sign Up**: firstName, lastName, email, password, accountType, businessName (if business)
- **Sign In**: email AND password (both must match exactly)
- **Password**: Stored in plain text (DEMO ONLY - not production ready)
- **Email**: Case-insensitive lookup for user accounts

### Booking
- **Required**: service, firstName, lastName, email, phone, make, model, year (≥4 digits), time
- **Optional**: color, notes
- **Year**: Sanitized (digits only, no commas)

### Services
- **Required**: name, description, durationMinutes, basePriceCents, category
- **Price**: Stored as cents (int), displayed as dollars (formatted)

### Business
- **Code**: 5 digits, zero-padded, unique
- **Handle**: BusinessName#12345 format
- **Search**: Case-insensitive with whitespace trimming
- **Lookup**: Full handle (name + code) required for uniqueness

## State Management

```
AuthStore (@ObservableObject)
├── @Published currentUser: User?
└── @Published hasAuthenticated: Bool

AppState (@ObservableObject)
└── @Published mode: AppMode (consumer/business)

ViewModels (@ObservableObject)
├── @Published properties for UI state
└── Combine publishers for async operations

Views
└── @StateObject / @ObservedObject / @EnvironmentObject
```

## Error Handling

- Repository errors propagated via Combine (Future + .sink)
- UI shows retry buttons or error messages
- Graceful degradation (empty states, fallbacks)
- No crashes on missing data

## Testing Strategy

### Manual Testing Checklist
1. ✅ Create consumer account (with password)
2. ✅ Create business account (generates code, with password)
3. ✅ Sign out and sign back in (password validation)
4. ✅ Test wrong password (should fail)
5. ✅ Copy business handle from Settings
6. ✅ Add services (business mode)
7. ✅ Find business by handle (consumer mode, case-insensitive)
8. ✅ Complete booking flow
9. ✅ Verify appointment appears in both schedules
10. ✅ Cancel appointment
11. ✅ Verify removal from both schedules
12. ✅ Test idempotency (rapid button taps)
13. ✅ Test validation (missing fields)
14. ✅ Test year sanitization (commas, letters)
15. ✅ Test duplicate business names (different codes)

## Performance Considerations

- UserDefaults used for simplicity (suitable for prototype)
- Lazy loading in lists (LazyVStack)
- Combine cancellables properly stored and managed
- No memory leaks (weak self in closures)
- Efficient view updates (minimal @Published properties)
- NavigationStack (iOS 16+) for modern navigation
- Case-insensitive search with O(n) complexity on business directory

## Security Considerations

⚠️ **For Demo/Prototype Only - NOT Production Ready:**
- Passwords stored in **plain text** in UserDefaults
- No password hashing (bcrypt, scrypt, Argon2)
- No SSL/TLS (local only)
- No rate limiting on authentication attempts
- No password complexity requirements
- No session token management

**Production Requirements:**
- Implement proper password hashing
- Use Keychain for sensitive data
- Add backend API with secure authentication
- Implement JWT or OAuth tokens
- Add password strength validation
- Enable two-factor authentication

## UI/UX Enhancements Implemented

- ✅ **App Icon**: Custom purple calendar + car icon (1024x1024)
- ✅ **AccentColor**: Purple-blue theme color in asset catalog
- ✅ **Copy Handle Button**: One-tap copy with clipboard feedback
- ✅ **Format Hint Card**: Helpful search instructions in Find tab
- ✅ **Case-Insensitive Search**: Flexible business lookup
- ✅ **Modern Navigation**: NavigationStack (iOS 16+) implementation

## Future Enhancements (Not Implemented)

- Real backend API with secure authentication
- Push notifications for appointment reminders
- Photo upload for vehicles and services
- Payment integration (Stripe, Apple Pay)
- Calendar sync (iCloud Calendar, Google Calendar)
- Maps/location for business addresses
- Reviews and ratings system
- Multi-business support per user
- Analytics dashboard
- Password reset via email
- Biometric authentication (Face ID, Touch ID)

