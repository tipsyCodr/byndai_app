# Phase 2: Refinement & Verification - Context

**Gathered:** 2026-05-12
**Status:** Ready for planning

<domain>
## Phase Boundary
This phase focuses on refining the gesture interactions to prevent conflicts between the main `PageView` and nested horizontal carousels (e.g., Suggested Connections, Events). It also ensures state persistence across page swipes.

</domain>

<decisions>
## Implementation Decisions

### State Persistence
- **KeepAlive:** Apply `AutomaticKeepAliveClientMixin` to `FeedPage`, `LeadsPage`, `DiscoverPage`, and `SettingsPage`. This prevents the pages from being disposed when swiping away, preserving scroll positions and loaded data.

### Gesture Conflict Management
- **Physics Tuning:** 
  - Main `PageView` uses `ClampingScrollPhysics` to prevent excessive bouncing at boundaries.
  - Inner carousels should use `BouncingScrollPhysics` or `AlwaysScrollableScrollPhysics` to ensure they capture gestures effectively.
- **Sensitivity:** If swiping between pages is too sensitive and triggers during carousel interaction, we may need a custom `DragGestureRecognizer` or to wrap inner carousels in `GestureDetector(onHorizontalDragUpdate: (details) {})` to stop propagation (though standard Flutter gesture arena usually handles this).

### Final Polish
- Ensure the floating dock's translucent glass effect remains performant during swipes.

</decisions>

<canonical_refs>
## Canonical References
- `lib/features/home/home_page.dart`
- `lib/features/home/feed_page.dart`
- `lib/features/discover/discover_page.dart`
- `lib/widgets/connection_suggest.dart` (Inner horizontal carousel)

</canonical_refs>

<specifics>
## Specific Ideas
- Check `ConnectionSuggest` in `FeedPage` (line 651).
- Check `DiscoverPage` for horizontal event lists.

</specifics>

<deferred>
## Deferred Ideas
- None. This is the final phase for this milestone.

</deferred>

---
*Phase: 02-refinement-verification*
*Context gathered: 2026-05-12 via initial conversation*
