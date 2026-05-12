# Directory Structure

```text
lib/
├── config/             # App-wide configuration
├── constants/          # Static constants (strings, dimensions)
├── core/               # Core infrastructure
│   ├── services/       # Business logic and API services (Providers)
│   ├── theme/          # App themes and colors
│   └── utils/          # Shared utility functions
├── data/               # Local data management
├── features/           # Feature-specific modules
│   ├── auth/           # Login and registration
│   ├── home/           # Main dashboard and navigation
│   ├── leads/          # Lead management
│   ├── profile/        # User profile management
│   └── ...             # Other features (QR, Scanner, Chat, etc.)
├── models/             # Shared data models
├── routes/             # Navigation and routing logic
├── widgets/            # Reusable UI components
└── main.dart           # App entry point
```

## Key Locations
- **Business Logic:** `lib/core/services/`
- **Feature UI:** `lib/features/`
- **Routing:** `lib/routes/`
- **Models:** `lib/models/`
