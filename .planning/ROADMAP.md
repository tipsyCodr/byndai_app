# Roadmap: Swipable Bottom Navigation

## Milestone 1: Navigation Transformation

### Phase 1: Core Implementation
Replace the static `IndexedStack` with a dynamic `PageView` and establish controller-based synchronization.

- **1.1 Setup PageController**
  - Initialize `PageController` in `HomePage`.
  - Update `initState` and `dispose`.
- **1.2 Replace IndexedStack**
  - Swap `IndexedStack` for `PageView` in `Scaffold` body.
  - Link `controller` and implement `onPageChanged`.
- **1.3 Update Dock Logic**
  - Modify `_onItemTapped` to use `animateToPage`.
  - Ensure state updates correctly for both swipe and tap.

### Phase 2: Refinement & Verification
Tune gestures and verify integration with existing features.

- **2.1 Gesture Conflict Tuning**
  - Verify horizontal scroll behavior in `FeedPage` and `DiscoverPage`.
  - Adjust `PageView` physics if necessary.
- **2.2 Behavior Verification**
  - Confirm "Tap-to-top" persists.
  - Verify subscription/auth logic still triggers redirects correctly.

---

## ▶ Next Steps
1. Run `/gsd-plan-phase 1` to detail the implementation steps.
