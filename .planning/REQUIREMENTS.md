# Requirements: Swipable Bottom Navigation

## Status: Active

## 1. Functional Requirements

### 1.1 Swipable Navigation
- The main content area must support horizontal swipe gestures to switch between:
  - FeedPage
  - LeadsPage
  - DiscoverPage
  - SettingsPage
- Swipe sensitivity should be tuned to avoid accidental triggers while allowing easy navigation.

### 1.2 Bottom Dock Sync
- Tapping a dock item must navigate the `PageView` to the corresponding index with a standard slide animation.
- Swiping the `PageView` must update the active icon and background highlight in the floating dock.

### 1.3 Gesture Conflict Management
- The `PageView` must allow child horizontal widgets (e.g., Suggested Connections on Home, Event Carousels on Discover) to handle their own gestures.
- Swiping should only trigger a page change when the gesture is not captured by a sub-widget.

### 1.4 Home Feed Integration
- Tapping the "Home" icon while already on the Home page must trigger `_feedKey.currentState?.onBackToTop()`.
- Swiping to the Home page from another page should NOT trigger the scroll-to-top behavior automatically.

## 2. Technical Requirements

### 2.1 Implementation Details
- Target file: `lib/features/home/home_page.dart`.
- Replace `IndexedStack` with `PageView`.
- Initialize `PageController` in `initState` and dispose in `dispose`.
- Use `physics: const ClampingScrollPhysics()` or similar to ensure snappy feel.

### 2.2 Verification Criteria
- [ ] Swiping left/right changes pages.
- [ ] Dock icons update correctly during and after swipe.
- [ ] Tapping dock icons animates `PageView` to correct index.
- [ ] Home scroll-to-top works on double-tap/repeat-tap.
- [ ] Horizontal carousels inside pages still work correctly.
