## LibFrameFade
### v2
- Fixed an issue where animations could have incorrect durations in edge cases where the frames had already been partially animated by the default UIFrameFade manager.
- Fixed an issue where user code that modifies the on-finish callback or its arguments in the fadeInfo table directly would not result in the correct function or arguments being used when the animation finishes.
- Minor performance tweaks to reduce memory churn when processing frames.

### v1
- Initial release.
