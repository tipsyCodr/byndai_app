# Coding Conventions

## Language Standards
- **Dart Lints:** Follows `package:flutter_lints/flutter.yaml`.
- **Naming:**
  - Classes: `PascalCase`
  - Variables/Functions: `camelCase`
  - Files: `snake_case.dart`

## Patterns
- **State Management:** Extensive use of `ChangeNotifierProvider`.
- **Async Code:** Uses `async`/`await` with `try`/`catch` blocks for error handling.
- **Dependency Injection:** Handled via `MultiProvider` in `main.dart`.

## UI Patterns
- **Material Design:** Standard widgets and theme.
- **Themes:** Light and Dark modes managed via `ThemeProvider`.
