# Architecture

## Pattern
The project uses a **Feature-First** architecture with **Provider** for state management. 

## Key Layers
- **Core:** Contains shared services, themes, and utilities.
- **Features:** Each major functionality is encapsulated in its own directory (e.g., `auth`, `home`, `profile`, `leads`).
- **Data:** Handle data models and storage logic.
- **Widgets:** Shared UI components used across multiple features.

## Data Flow
1. **Providers (`lib/core/services`):** Manage state and business logic.
2. **Views (`lib/features`):** UI components that listen to Providers.
3. **Services (`lib/core/services`):** Handle API calls, Firebase interactions, and local storage.

## Entry Points
- `lib/main.dart`: Initializer for Firebase, Services, and Providers.
- `lib/routes/app_routes.dart`: Defines the application's navigation structure.
