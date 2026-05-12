# Technical Concerns

## Technical Debt
- **Large Providers:** Some providers in `lib/core/services/` might be handling too many responsibilities.
- **Backup Files:** Presence of `_backup.dart` files (e.g., `post_card_backup.dart`, `feed_page_backup.dart`) suggests manual versioning or incomplete refactors.

## Fragile Areas
- **NFC Integration:** Hardware-dependent and might be prone to device-specific issues.
- **State Management Complexity:** Mixing `Provider` and `Get` might lead to confusion or lifecycle issues if not carefully managed.

## Identified TODOs
- Fix video ID not found error in `lib/features/profile/profile_tab.dart`.
- Navigate to edit page in `lib/features/business_feed/my_post_card.dart`.
- Open comments page and report action in business feed.
