# Project: Swipable Bottom Navigation

## What This Is
Implementation of a swipable PageView-based navigation for the main app interface, replacing the current static IndexedStack.

## Core Value
Enhance user experience by allowing intuitive horizontal gestures to navigate between major app sections (Home, Leads, Discover, Settings).

## Context
The app uses a custom floating bottom dock. Current implementation uses `IndexedStack` which is instantaneous but lacks transition feel and swiping capability.

## Requirements

### Validated
- ✓ Feature-first architecture with Provider state management.
- ✓ Custom floating bottom dock implemented with `GlassBox`.
- ✓ Replace `IndexedStack` with `PageView` in `HomePage`. (Phase 1)
- ✓ Implement `PageController` for bidirectional synchronization. (Phase 1)
- ✓ Preserve "tap-to-scroll-top" behavior for the Home feed. (Phase 1)
- ✓ Standard slide transitions between main screens. (Phase 1)
- ✓ Ensure horizontal carousels don't conflict with PageView swiping. (Phase 2)
- ✓ Implement KeepAlive for all main sub-pages. (Phase 2)

### Active
- None.

### Out of Scope
- Custom transition animations (e.g., zoom, fade-through).
- Refactoring the entire navigation system to a different library (e.g., GoRouter).

## Key Decisions
| Decision | Rationale | Outcome |
|----------|-----------|---------|
| PageView over IndexedStack | Enables swipe gestures between main app modules. | ✓ Implemented |
| Standard Slide Animation | Keep UI consistent with platform defaults and user preference. | ✓ Implemented |
| KeepAlive Mixin | Preserves scroll and state during rapid tab switching. | ✓ Implemented |

## Evolution
Milestone Complete. Swipable bottom navigation is fully implemented with state preservation and gesture conflict handling.
---
*Last updated: 2026-05-12 after final verification*
