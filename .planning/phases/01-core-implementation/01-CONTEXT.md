# Phase 1: Core Implementation - Context

**Gathered:** 2026-05-12
**Status:** Ready for planning

<domain>
## Phase Boundary
This phase replaces the current `IndexedStack` navigation in `HomePage` with a `PageView` and `PageController`. It ensures that taps on the floating dock and swipe gestures on the page view are synchronized.

</domain>

<decisions>
## Implementation Decisions

### Navigation Control
- **PageView:** Replace `IndexedStack` with `PageView` in the stack body of `HomePage`.
- **PageController:** Use a single `PageController` to manage the `PageView` and respond to dock taps.
- **Synchronization:**
  - `onPageChanged` updates the local `_selectedIndex` state.
  - Dock taps call `_pageController.animateToPage` with a standard duration and curve.

### Home Behavior
- **Tap-to-top:** Preserve the existing logic where tapping "Home" while on the home page triggers `_feedKey.currentState?.onBackToTop()`.

### Animation
- **Standard Slide:** Use standard slide transitions provided by `PageView.animateToPage`.

### the agent's Discretion
- **Scroll Physics:** Use `ClampingScrollPhysics` or `BouncingScrollPhysics` for a snappy feel.
- **PageView Attributes:** Configure `allowImplicitScrolling` if beneficial for pre-loading adjacent pages.

</decisions>

<canonical_refs>
## Canonical References
- `lib/features/home/home_page.dart` — Main navigation host.
- `lib/features/home/feed_page.dart` — Home feed with scroll-to-top capability.

</canonical_refs>

<specifics>
## Specific Ideas
- The floating dock is a `Positioned` widget in a `Stack`. Ensure the `PageView` is placed below it in the stack.
- Padding at the bottom of the `PageView` children should account for the floating dock height (approx 72+ padding).

</specifics>

<deferred>
## Deferred Ideas
- Advanced gesture handling for horizontal conflict resolution (Phase 2).
- Detailed verification of all edge cases (Phase 2).

</deferred>

---
*Phase: 01-core-implementation*
*Context gathered: 2026-05-12 via initial conversation*
