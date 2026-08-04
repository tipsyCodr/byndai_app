# Phase 1: Core Implementation - Research

## Overview
Replacing `IndexedStack` with `PageView` in Flutter requires synchronizing the `BottomNavigationBar` (or custom dock) with the `PageView`'s current index using a `PageController`.

## Technical Approach
### PageView & PageController
- **Initialization:** Create a `late final PageController _pageController` in `_HomePageState`.
- **Synchronization:**
  - `PageView.onPageChanged`: Triggers when the user swipes. Updates `_selectedIndex` via `setState`.
  - `GestureDetector.onTap` (in dock): Triggers when the user taps an icon. Calls `_pageController.animateToPage`.
- **Physics:** `ClampingScrollPhysics` is recommended to prevent overscroll effects that might look jarring in a main navigation context.

### Synchronization Logic
To avoid a "ping-pong" effect where `animateToPage` triggers `onPageChanged` which then tries to update the dock again:
1. Tapping a dock item calls `animateToPage`.
2. `onPageChanged` handles the state update for `_selectedIndex`.
3. The dock builds itself based on `_selectedIndex`.
This flow is naturally unidirectional in Flutter if managed correctly.

### State Preservation
By default, `PageView` might dispose of pages that are not visible.
- `FeedPage` and other screens should mix in `AutomaticKeepAliveClientMixin` and return `true` in `wantKeepAlive` to preserve scroll positions and data during swipes.

### Scroll Conflict Management
- `PageView`'s horizontal swipe can conflict with inner horizontal widgets (like `ConnectionSuggest`).
- In Flutter, the inner widget usually wins the gesture if it's scrollable.
- If conflicts persist, `NeverScrollableScrollPhysics` on specific inner widgets or custom `GestureRecognizer` logic may be needed.

## Pitfalls to Avoid
- **Disposal:** Forgetting to `dispose()` the `PageController` can lead to memory leaks.
- **Double Taps:** Ensure the "tap-to-top" behavior doesn't trigger a page animation if the user is already on that page.
- **Initialization:** `_selectedIndex` must match the `initialPage` of the `PageController`.

## Validation Strategy
- [ ] Swiping from page 0 to 1 updates dock index 1.
- [ ] Tapping dock index 2 slides `PageView` to index 2.
- [ ] Horizontal carousels inside `FeedPage` still scroll horizontally without triggering a page turn prematurely.
- [ ] Tapping Home icon while on Home page scrolls feed to top.
