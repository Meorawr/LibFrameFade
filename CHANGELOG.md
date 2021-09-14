## LibFrameFade
### v4
- Reimplement UIFrameIsFading to return correct results for addons that need it.
  - This causes the UIFrameIsFading to always taint if called, however the function is unused by Blizzard in all current (9.1.0, 2.5.2, and 1.14.0) versions of the game.

### v3
- Fixed an issue where ElvUI's chat frame tabs would incorrectly fade out when not actively hovered over.

### v2
- Fixed an issue where animations could have incorrect durations in edge cases where the frames had already been partially animated by the default UIFrameFade manager.
- Fixed an issue where user code that modifies the on-finish callback or its arguments in the fadeInfo table directly would not result in the correct function or arguments being used when the animation finishes.
- Minor performance tweaks to reduce memory churn when processing frames.

### v1
- Initial release.
