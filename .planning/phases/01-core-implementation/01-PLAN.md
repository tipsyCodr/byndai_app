# Phase 1: Core Implementation - Plan

## Objective
Enable swipable navigation by replacing `IndexedStack` with `PageView` and syncing it with the bottom dock.

## Proposed Changes

### `lib/features/home/home_page.dart`
- Initialize `PageController`.
- Replace `IndexedStack` with `PageView`.
- Link `onPageChanged` and dock tap handlers.
- Dispose controller.

## Tasks

### Wave 1: Controller & State Setup
- [ ] **Task 1.1: Initialize PageController**
  - `<action>` Add `late final PageController _pageController;` to `_HomePageState`. Initialize in `initState` with `initialPage: _selectedIndex`. Dispose in `dispose()`. `</action>`
  - `<read_first>` `lib/features/home/home_page.dart` `</read_first>`
  - `<acceptance_criteria>` `lib/features/home/home_page.dart` contains `_pageController = PageController(` and `_pageController.dispose()`. `</acceptance_criteria>`

- [ ] **Task 1.2: Sync Navigation Logic**
  - `<action>` Modify `_onItemTapped(int index)`: If `_selectedIndex == index` and `index == 0`, call `onBackToTop`. Else, call `_pageController.animateToPage(index, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut)`. `</action>`
  - `<read_first>` `lib/features/home/home_page.dart` `</read_first>`
  - `<acceptance_criteria>` `_onItemTapped` uses `_pageController.animateToPage`. `</acceptance_criteria>`

### Wave 2: UI Transformation
- [ ] **Task 2.1: Implement PageView**
  - `<action>` In `build()` method, replace `IndexedStack` with `PageView`. Set `controller: _pageController`, `onPageChanged: (index) => setState(() => _selectedIndex = index)`, and `physics: const ClampingScrollPhysics()`. `</action>`
  - `<read_first>` `lib/features/home/home_page.dart` `</read_first>`
  - `<acceptance_criteria>` `PageView(` exists in `build()` with `onPageChanged` updating `_selectedIndex`. `</acceptance_criteria>`

## Verification Criteria
- [ ] App launches and shows Home page by default.
- [ ] Swiping horizontally changes pages and updates the bottom dock highlight.
- [ ] Tapping dock icons smoothly animates to the selected page.
- [ ] Tapping "Home" while on Home page scrolls the feed to the top (existing logic preserved).
- [ ] No layout overflows or gesture dead zones introduced.

## must_haves
- Swiping works bidirectionally.
- Dock stays in sync with swipe.
- Tap-to-top behavior persists.
