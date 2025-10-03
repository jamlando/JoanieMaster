# Phase 2: Integration Diagrams and Implementation Plan

## Architecture Overview Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                         Joanie iOS App                          │
├─────────────────────────────────────────────────────────────────┤
│  View Layer                                                     │
│  ┌─────────────────┐  ┌─────────────────┐                      │
│  │ AuthenticationView │  │   PasswordResetView │                │
│  └─────────────────┘  └─────────────────┘                      │
├─────────────────────────────────────────────────────────────────┤
│  ViewModel Layer                                                │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │              AuthenticationViewModel                        │ │
│  │  ┌─────────────────────────────────────────────────────────┐ │ │
│  │  │                  AuthService                            │ │ │
│  │  │  ┌─────────────────────────────────────────────────────┐│ │ │
│  │  │  │              EmailServiceManager                     ││ │ │
│  │  │  │  ┌─────────────────┐  ┌─────────────────────────────┐││ │ │
│  │  │  │  │   ResendService │  │    SupabaseEmailService   │││ │ │
│  │  │  │  │                 │  │                             │││ │ │
│  │  │  │  │ - Template Mgmt │  │ - Supabase Auth Integration│││ │ │
│  │  │  │  │ - Error Handling│  │ - Fallback Mechanism       │││ │ │
│  │  │  │  │ - Retry Logic   │  │ - Simple Email Sending     │││ │ │
│  │  │  │  └─────────────────┘  └─────────────────────────────┘││ │ │
│  │  │  └─────────────────────────────────────────────────────┘│ │ │
│  │  └─────────────────────────────────────────────────────────┘ │ │
│  └─────────────────────────────────────────────────────────────┘ │
├─────────────────────────────────────────────────────────────────┤
│  Service Layer                                                  │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │                    SupabaseService                         │ │
│  │  ┌─────────────────────────────────────────────────────────┐ │ │
│  │  │              Supabase Auth Logic                       │ │ │
│  │  └─────────────────────────────────────────────────────────┘ │ │
│  └─────────────────────────────────────────────────────────────┘ │
├─────────────────────────────────────────────────────────────────┤
│  Infrastructure Layer                                           │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐ │
│  │   KeychainService│  │   ErrorHandler   │  │   RetryService  │ │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘ │
├─────────────────────────────────────────────────────────────────┤
│  Configuration Layer                                            │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │                      Secrets.swift                        │ │
│  │  - Resend API Key                                          │ │
│  │  - Email Configuration                                     │ │
│  │  - Feature Flags                                           │ │
│  └─────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

## Email Service Integration Flow

```
User Request → AuthenticationViewModel → AuthService → EmailServiceManager
                                                                │
                                                    ┌───────────┼───────────┐
                                                    │           │           │
                                                    ▼           ▼           ▼
                                          EmailServiceSelector  │    SupabaseEmailService
                                                    │           │           │
                                                    ▼           │           │
                                          ┌─────────────┐      │           │
                                          │   Primary   │      │           │
                                          │   Service   │──────┘           │
                                          │  Selection  │                  │
                                          │   Logic     │                  │
                                          └─────────────┘                  │.           .           │
                                          ┌─────────────┐      │           │           │
                                          │   Resend    │──────┼───────────┘           │
                                          │   Service   │                            │
                                          │   - API     │                            │
                                          │   - Templates│                            │
                                          │   - Retry   │                            │
                                          └─────────────┘                            │
                                                                                      │
                                          ┌───────────────────────────────────────────────┐
                                          │          Retry & Fallback Logic               │
                                          │  ┌─────────────────────────────────────────┐  │
                                          │  │              Error Handling           │  │
                                          │  │  - EmailError → AuthenticationError    │  │
                                          │  │  - Retry with exponential backoff     │  │
                                          │  │  - Automatic fallback to Supabase     │  │
                                          │  │  - User notification                   │  │
                                          │  └─────────────────────────────────────────┘  │
                                          └───────────────────────────────────────────────┘
                                                                                      │
                                                                                      ▼
                                                                              EmailResult
                                                                                      │
                                                                                      ▼
                                                                         Success/Error Response
```

## Error Handling Flow

```
Email Send Request
        │
        ▼
┌─────────────────┐
│  ResendService  │ ◄─── Primary Service
├─────────────────┤
│  API Call       │
├─────────────────┤
│  Error?         │─── Yes ──► Error Classification
├─────────────────┤ │
│  Success        │ │
└─────────────────┘ ▼
        │
        ▼ No
┌─────────────────┐
│ EmailService-   │
│ Selector        │ ◄─── Service Health Tracking
├─────────────────┤
│ Update Success  │
│ Count           │
└─────────────────┘

Error Classification:
├── Network Error → Retry with Backoff
├── Rate Limit → Delay and Retry
├── Auth Error → Fallback to Supabase
├── Quota Error → Emergency Supabase Fallback
└── Fatal Error → User Notification + Supabase
```

## Configuration Management

```
┌─────────────────────────────────────────────────────────────┐
│                    Configuration Flow                       │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  Environment Variables          Secrets.swift              │
│  ├── RESEND_API_KEY      ──────► └─ resendAPIKey           │
│  ├── RESEND_DOMAIN       ──────► └─ resendDomain           │
│  ├── EMAIL_FROM_ADDRESS  ──────► └─ emailFromAddress       │
│  ├── EMAIL_FROM_NAME     ──────► └─ emailFromName         │
│  ├── RESEND_EMAIL_ENABLED ──────► └─ resendEmailEnabled    │
│  └── EMAIL_FALLBACK_ENABLED───► └─ emailFallbackEnabled   │
│                                                             │
│                    ResendConfiguration                      │
│  ├── Static Configuration from Secrets                      │
│  ├── Runtime Validation                                     │
│  ├── Development/Production Profiles                        │
│  └── Security Checks (API Key Validation)                   │
│                                                             │
│              Error Configuration Management                 │
│  ├── Retry Configuration                                    │
│  ├── Timeout Settings                                       │
│  ├── Failure Thresholds                                     │
│  └── Fallback Triggers                                      │
└─────────────────────────────────────────────────────────────┘
```

## Dependency Injection Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                DependencyContainer                         │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  Service Initialization Order:                             │
│  1. Core Services (Logging, KeyChain)                     │
│  2. Infrastructure Services (Retry, Error Handling)        │
│  3. Supabase Service                                        │
│  4. Email Services Creation                                 │
│     ├── EmailServiceManager                                │
│     ├── ResendService (if enabled)                         │
│     └── SupabaseEmailService                                │
│  5. Business Services (Auth, Storage, AI)                  │
│  6. ViewModels                                              │
│                                                             │
│  Service Dependencies:                                      │
│  ┌─────────────────────────────────────────────────────────┐
│  │ AuthService ──┐                                        │
│  │        │      │                                        │
│  │        └──────┼──► SupabaseService                     │
│  │              │        │                                │
│  │              │        └──► EmailServiceManager         │
│  │              │             │                           │
│  │              │             ├──► ResendService         │
│  │              │             └──► SupabaseEmailService   │
│  │                                                                   │
│  └─────────────────────────────────────────────────────────┘
│                                                             │
│  Testing Integration:                                       │
│  - MockEmailService for unit tests                          │
│  - TestConfiguration for integration tests                  │
│  - Service replacement via protocols                       │
└─────────────────────────────────────────────────────────────┘
```

## Implementation Sequence

### Stage 1: Foundation (Weeks 1-2)
```
1. Protocol Definition
   ├── EmailService protocol
   ├── EmailResult model
   ├── EmailError enum
   └── Configuration models

2. Resend Service Core
   ├── ResendAPIClient
   ├── ResendService class
   ├── Basic HTTP communication
   └── Error handling foundation

3. Configuration Integration
   ├── Secrets.swift updates
   ├── ResendConfiguration
   └── Environment variable support
```

### Stage 2: Fallback Mechanism (Week 3)
```
1. Service Manager
   ├── EmailServiceManager
   ├── Service selection logic
   ├── Health tracking
   └── Automatic fallback

2. Supabase Email Service
   ├── SupabaseEmailService wrapper
   ├── Supabase auth integration
   └── Result standardization

3. Error Mapping
   ├── EmailError → AuthenticationError
   ├── EmailError → AppError
   └── Unified error handling
```

### Stage 3: Template Management (Week 4)
```
1. Email Templates
   ├── Template definitions
   ├── HTML/Text templates
   ├── Dynamic content injection
   └── Template caching

2. Password Reset Integration
   ├── Token generation
   ├── Template rendering
   ├── AuthService updates
   └── End-to-end testing

3. Template Management
   ├── EmailTemplateManager
   ├── Template storage
   ├── Version management
   └── Localization support
```

### Stage 4: Advanced Features (Week 5-6)
```
1. Analytics & Monitoring
   ├── Email delivery tracking
   ├── Success/failure metrics
   ├── Service health monitoring
   └── Performance analytics

2. Testing Suite
   ├── Unit tests
   ├── Integration tests
   ├── Mock services
   └── Test data fixtures

3. Documentation
   ├── API documentation
   ├── Integration guide
   ├── Troubleshooting guide
   └── Performance tuning
```

### Stage 5: Production Deployment (Week 7-8)
```
1. Production Configuration
   ├── API key management
   ├── Domain setup
   ├── Monitoring dashboard
   └── Alerting rules

2. Gradual Rollout
   ├── Feature flags
   ├── Percentage deployment
   ├── Canary testing
   └── Rollback procedures

3. Monitoring & Maintenance
   ├── Health checks
   ├── Automated alerts
   ├── Performance optimization
   └── Continuous monitoring
```

## Testing Strategy

### Unit Tests
```
┌─────────────────────────────────────────┐
│           Test Coverage                │
├─────────────────────────────────────────┤
│ - EmailService protocol implementation │
│ - ResendService individual methods      │
│ - Error handling and mapping            │
│ - Configuration validation              │
│ - Template rendering                    │
│ - Service health tracking               │
└─────────────────────────────────────────┘
```

### Integration Tests
```
┌─────────────────────────────────────────┐
│        Integration Test Scenarios       │
├─────────────────────────────────────────┤
│ - End-to-end password reset flow        │
│ - Service fallback mechanism            │
│ - Error retry and escalation            │
│ - Configuration runtime validation       │
│ - Email template rendering              │
│ - Dependency injection correctness      │
└─────────────────────────────────────────┘
```

### Performance Tests
```
┌─────────────────────────────────────────┐
│         Performance Benchmarks         │
├─────────────────────────────────────────┤
│ - Email sending latency                 │
│ - Template loading performance          │
│ - Memory usage under load               │
│ - Concurrent email handling              │
│ - Fallback switching performance        │
└─────────────────────────────────────────┘
```

## Monitoring & Alerting

### Key Metrics
- Email delivery success rate
- Service response times
- Fallback activation frequency
- Template rendering performance
- Error classification distribution
- User experience impact

### Alert Conditions
- Resend service failure rate > 10%
- Email delivery latency > 30 seconds
- Supabase fallback activation > 5%
- Template loading failures
- Configuration validation errors

This comprehensive integration plan ensures smooth implementation while maintaining system reliability and providing excellent user experience through robust error handling and fallback mechanisms.

