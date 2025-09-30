# Joanie iOS App

Joanie is an iOS app designed to help parents digitally preserve and analyze their preschool and elementary-aged children's creative works (drawings, artwork, school assignments). The app emphasizes family engagement through AI-powered insights, storytelling, and progress tracking.

## Features

- 📸 **Photo Capture & Upload**: Easy photo capture with automatic upload to secure cloud storage
- 👶 **Child Profiles**: Manage multiple children with age-appropriate customization
- 🎨 **AI-Powered Analysis**: Get insights and tips about your child's creative development
- 📚 **Story Generation**: Create personalized stories from your child's artwork
- 📊 **Progress Tracking**: Visual timeline and progress charts
- 👨‍👩‍👧‍👦 **Family Sharing**: Share with co-parents and family members
- 🔒 **Privacy First**: COPPA compliant with secure data handling

## Tech Stack

- **Frontend**: Swift + SwiftUI
- **Backend**: Supabase (PostgreSQL + Storage + Auth)
- **AI Services**: Apple Vision Framework + OpenAI GPT-4o/xAI Grok API
- **Architecture**: MVVM pattern with Core Data for offline support

## Getting Started

### Prerequisites

- Xcode 15.0+
- iOS 15.0+ target device or simulator
- Supabase account
- OpenAI API key (for AI features)

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/jamlando/JoanieMaster.git
   cd JoanieMaster
   ```

2. **Set up Supabase**
   - Create a new Supabase project
   - Run the SQL scripts in the root directory:
     ```bash
     # Execute database-schema.sql in Supabase SQL editor
     # Execute storage-setup.sql in Supabase SQL editor
     ```

3. **Configure secrets**
   - Copy `secrets.template` to `Joanie/Config/Secrets.swift`
   - Fill in your actual Supabase and API credentials:
     ```swift
     struct Secrets {
         static let supabaseURL = "https://your-project-id.supabase.co"
         static let supabaseAnonKey = "your-anon-key-here"
         static let openAIAPIKey = "your-openai-api-key-here"
         // ... other secrets
     }
     ```

4. **Open in Xcode**
   ```bash
   open Joanie.xcodeproj
   ```

5. **Build and run**
   - Select your target device or simulator
   - Press Cmd+R to build and run

### Development Setup

1. **Install SwiftLint** (for code quality)
   ```bash
   brew install swiftlint
   ```

2. **Run tests**
   ```bash
   xcodebuild test -project Joanie.xcodeproj -scheme Joanie
   ```

3. **Run SwiftLint**
   ```bash
   swiftlint lint
   ```

## Project Structure

```
Joanie/
├── Models/           # Data models (User, Child, ArtworkUpload, Story)
├── Views/            # SwiftUI views
├── ViewModels/       # MVVM view models
├── Services/         # Business logic services (SupabaseService, etc.)
├── Utils/            # Utilities and configuration
├── Config/           # Secrets and configuration (not in git)
└── Assets.xcassets/  # App icons and images
```

## CI/CD

The project uses GitHub Actions for automated testing and code quality checks:

- **Build & Test**: Runs on every push and pull request
- **Code Quality**: SwiftLint checks for code style and best practices
- **Security**: Scans for hardcoded secrets and security issues
- **Branch Protection**: Main branch requires passing tests and code review

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Development Workflow

- `main`: Production-ready code
- `develop`: Integration branch for features
- `staging`: Pre-production testing
- `feature/*`: Individual feature branches

## Security

- All API keys and secrets are stored in `Joanie/Config/Secrets.swift` (not in git)
- Supabase Row Level Security (RLS) policies protect user data
- COPPA compliance for child data handling
- Regular security audits and dependency updates

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Support

For support, email support@joanie.app or create an issue in this repository.

## Roadmap

- [ ] Phase 1: Project Setup & Foundation ✅
- [ ] Phase 2: Core Features Development
- [ ] Phase 3: AI Integration
- [ ] Phase 4: Advanced Features
- [ ] Phase 5: Testing & Polish
- [ ] Phase 6: Launch Preparation

See the [Product Requirements Document](Product%20Requirements%20Document%20(PRD)%20for%20Joanie%20iOS%20App.md) for detailed feature specifications.
