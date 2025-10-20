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
│  │   ├── "Book with [business]" button                         │
│  │   ├── AI Assistant button → AIAssistantView                 │
│  │   │   ├── Chat interface with NLP                           │
│  │   │   ├── Service discovery through conversation            │
│  │   │   └── Extract booking info → Start Booking             │
│  │   └── BusinessServicesView (list services)                  │
│  │       └── Select service → BookingFlowView                  │
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
- **ChatMessage**: id, sender (user/assistant), content, timestamp
- **ExtractedBookingInfo**: vehicleYear, vehicleMake, vehicleModel, vehicleColor, servicePreference, preferredDate, preferredTime, customerNotes

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
- **AIAssistantViewModel**: Chat interface and NLP processing for booking assistance

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

## AI Assistant Architecture

```
┌────────────────────────────────────────────────────────────┐
│  User Input: "I need a detail for my 2020 Honda Civic"    │
└────────────────────┬───────────────────────────────────────┘
                     │
                     ▼
┌────────────────────────────────────────────────────────────┐
│  AIAssistantViewModel.processUserMessage()                 │
│  ├── Intent Detection (rule-based)                         │
│  │   ├── Greeting detection                                │
│  │   ├── Service inquiry                                   │
│  │   ├── Pricing questions                                 │
│  │   ├── Duration questions                                │
│  │   ├── Booking intent                                    │
│  │   └── Problem/need detection                            │
│  │                                                          │
│  └── Information Extraction (regex + pattern matching)     │
│      ├── Vehicle year (4-digit pattern)                    │
│      ├── Vehicle make (30+ manufacturers)                  │
│      ├── Vehicle model (common models)                     │
│      ├── Vehicle color (14 colors)                         │
│      ├── Service keywords (detail, wash, coating, etc.)    │
│      └── Date/time preferences                             │
└────────────────────┬───────────────────────────────────────┘
                     │
                     ▼
┌────────────────────────────────────────────────────────────┐
│  Context-Aware Response Generation                         │
│  ├── Match extracted info with available services          │
│  ├── Generate personalized recommendations                 │
│  ├── Provide pricing and duration details                  │
│  └── Suggest next steps (booking action)                   │
└────────────────────┬───────────────────────────────────────┘
                     │
                     ▼
┌────────────────────────────────────────────────────────────┐
│  Display Response + Action Buttons                         │
│  └── "Start Booking" button (when service suggested)       │
└────────────────────────────────────────────────────────────┘
```

### NLP Capabilities

**Intent Detection Methods:**
- Greeting patterns: "hi", "hello", "hey", etc.
- Service inquiries: "what services", "show me", "do you have", etc.
- Pricing: "how much", "cost", "price", "pricing", etc.
- Duration: "how long", "duration", "time", etc.
- Booking: "book", "schedule", "appointment", "reserve", etc.
- Problem keywords: "scratched", "dirty", "stained", "damaged", etc.

**Information Extraction:**
- **Vehicle Year**: Regex pattern `\b(19|20)\d{2}\b` (1900-2099)
- **Vehicle Make**: 30+ manufacturers (Honda, Toyota, Ford, BMW, Tesla, etc.)
  - Handles aliases: "chevy" → "Chevrolet", "vw" → "Volkswagen"
- **Vehicle Color**: 14 common colors (black, white, silver, red, blue, etc.)
- **Service Matching**: 
  - Exact name match (case-insensitive)
  - Category keywords: "detail", "wash", "coating", "ceramic", "polish", "wax"
  - Compound terms: "full detail", "express wash", "interior clean"

**Response Strategies:**
1. **Priority-based**: Most specific intent wins (e.g., specific service + price > general pricing)
2. **Contextual**: Uses business profile and available services for recommendations
3. **Multi-turn**: Maintains conversation history for context
4. **Actionable**: Provides clear next steps (booking buttons when ready)

**No External APIs:**
- All processing happens locally on-device
- No network calls to OpenAI, Claude, or other LLM services
- Pattern matching and keyword detection only
- Fast response times (simulated 0.8s delay for UX)
- Complete privacy - no data sent to external servers

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
    ├── Tag: Pill-shaped status badge
    ├── MessageBubble: Chat message with sender-specific styling
    ├── TypingIndicator: Animated dots for AI processing
    └── AIAssistantButton: Floating gradient button with sparkles
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
8. ✅ Test AI Assistant from business profile
9. ✅ Ask about services, pricing, duration in chat
10. ✅ Test vehicle info extraction (year, make, model, color)
11. ✅ Test service discovery through natural language
12. ✅ Start booking from AI Assistant
13. ✅ Complete booking flow
14. ✅ Verify appointment appears in both schedules
15. ✅ Cancel appointment
16. ✅ Verify removal from both schedules
17. ✅ Test idempotency (rapid button taps)
18. ✅ Test validation (missing fields)
19. ✅ Test year sanitization (commas, letters)
20. ✅ Test duplicate business names (different codes)
21. ✅ Test AI chat clear functionality
22. ✅ Test multiple conversation turns in AI Assistant

## Performance Considerations

- UserDefaults used for simplicity (suitable for prototype)
- Lazy loading in lists (LazyVStack)
- Combine cancellables properly stored and managed
- No memory leaks (weak self in closures)
- Efficient view updates (minimal @Published properties)
- NavigationStack (iOS 16+) for modern navigation
- Case-insensitive search with O(n) complexity on business directory
- AI Assistant uses local pattern matching (no network latency)
- Simulated 0.8s processing delay for natural conversation feel
- Chat messages stored in memory only (cleared on dismiss)
- Regex compilation happens once per message (efficient)

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
- ✅ **AI Booking Assistant**: Conversational interface with rule-based NLP
- ✅ **Chat Interface**: Message bubbles, typing indicators, auto-scroll
- ✅ **Bold Markdown**: Support for **bold** text in AI responses
- ✅ **Contextual Actions**: Dynamic "Start Booking" button when ready

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
- Advanced AI with LLM integration (GPT-4, Claude)
- Voice input for AI Assistant (Speech-to-Text)
- Multilingual support in AI chat
- AI-powered service recommendations based on vehicle history
- Sentiment analysis for customer feedback

