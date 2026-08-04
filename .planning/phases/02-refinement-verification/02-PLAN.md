# Phase 2: Refinement & Verification - Plan

## Objective
Ensure seamless state preservation across navigation and resolve any gesture conflicts with nested carousels.

## Proposed Changes

### `lib/features/home/feed_page.dart`
- Mix in `AutomaticKeepAliveClientMixin`.
- Implement `wantKeepAlive => true`.
- Wrap `build` with `super.build(context)`.

### `lib/features/leads/leads_page.dart`
- Mix in `AutomaticKeepAliveClientMixin`.
- Implement `wantKeepAlive => true`.

### `lib/features/discover/discover_page.dart`
- Mix in `AutomaticKeepAliveClientMixin`.
- Implement `wantKeepAlive => true`.

### `lib/features/settings/settings_page.dart`
- Mix in `AutomaticKeepAliveClientMixin`.
- Implement `wantKeepAlive => true`.

## Tasks

### Wave 1: State Preservation (KeepAlive)
- [ ] **Task 1.1: Update FeedPage**
  - `<action>` Add `AutomaticKeepAliveClientMixin` to `FeedPageState`. Implement `bool get wantKeepAlive => true;`. Add `super.build(context);` at the start of `build()`. `</action>`
  - `<read_first>` `lib/features/home/feed_page.dart` `</read_first>`
  - `<acceptance_criteria>` `FeedPageState` contains `wantKeepAlive` and `super.build`. `</acceptance_criteria>`

- [ ] **Task 1.2: Update DiscoverPage**
  - `<action>` Add `AutomaticKeepAliveClientMixin` to `_DiscoverPageState`. Implement `bool get wantKeepAlive => true;`. Add `super.build(context);` at the start of `build()`. `</action>`
  - `<read_first>` `lib/features/discover/discover_page.dart` `</read_first>`
  - `<acceptance_criteria>` `_DiscoverPageState` contains `wantKeepAlive`. `</acceptance_criteria>`

- [ ] **Task 1.3: Update LeadsPage & SettingsPage**
  - `<action>` Apply the same `KeepAlive` pattern to `LeadsPage` and `SettingsPage`. `</action>`
  - `<read_first>` `lib/features/leads/leads_page.dart`, `lib/features/settings/settings_page.dart` `</read_first>`
  - `<acceptance_criteria>` Both pages have `AutomaticKeepAliveClientMixin`. `</acceptance_criteria>`

### Wave 2: Final Verification
- [ ] **Task 2.1: Verification of Conflicts**
  - `<action>` Final code review of `home_page.dart` PageView physics. Confirm `ClampingScrollPhysics` is appropriate. `</action>`
  - `<read_first>` `lib/features/home/home_page.dart` `</read_first>`
  - `<acceptance_criteria>` Physics remains `ClampingScrollPhysics`. `</acceptance_criteria>`

## Verification Criteria
- [ ] Swiping away from a page and back preserves the scroll position.
- [ ] Horizontal carousels in Feed/Discover handle gestures correctly without accidentally turning the page.
- [ ] Memory usage remains stable (KeepAlive keeps widgets in memory).

## must_haves
- State preserved during swipe.
- Carousels remain usable.
