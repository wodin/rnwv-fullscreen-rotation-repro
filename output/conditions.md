# Conditions

`react-native-webview` 17.1.0, React Native 0.88.1, Android emulator 35.4.9.
One file per run in [`conditions/`](conditions), written by
[`scripts/conditions.sh`](../scripts/conditions.sh).

| Emulator                                                 | Window (dp) | System WebView |
| -------------------------------------------------------- | ----------- | -------------- |
| Pixel 3a, API 34, `google_apis/x86_64`, 1080x2220 440dpi | 393x807     | 113.0.5672.136 |
| Pixel 3a XL, API 28, `google_apis/x86`, 1080x2160 400dpi | 432x864     | 69.0.3497.100  |

How the device was turned while the video was fullscreen:

- **Auto-rotate on**: `accelerometer_rotation` 1, emulator turned through its
  accelerometer.
- **Auto-rotate off**: `accelerometer_rotation` 0, turned the same way.
- **Maestro**: `setOrientation`, which sets `accelerometer_rotation` to 0 and
  writes `user_rotation`. The setting from before the flow has no effect.

## App locked to portrait

| API | Turned by       | Display rotated | Root laid out in landscape | WebView unmounted | Video still playing | After exit                           |
| --- | --------------- | --------------- | -------------------------- | ----------------- | ------------------- | ------------------------------------ |
| 34  | Auto-rotate on  | yes             | yes                        | yes               | no                  | portrait, new WebView, video stopped |
| 34  | Maestro         | yes             | yes                        | yes               | no                  | portrait, new WebView, video stopped |
| 34  | Auto-rotate off | no              | no                         | no                | yes                 | correct                              |
| 28  | Auto-rotate on  | no              | no                         | no                | yes                 | correct                              |
| 28  | Maestro         | not measured    | no                         | no                | yes                 | correct                              |
| 28  | Auto-rotate off | no              | no                         | no                | yes                 | correct                              |

## App with no orientation lock

| API | Turned by       | Display rotated | Root laid out in landscape | WebView unmounted | Video still playing | After exit                            |
| --- | --------------- | --------------- | -------------------------- | ----------------- | ------------------- | ------------------------------------- |
| 34  | Auto-rotate on  | yes             | yes                        | yes               | no                  | landscape, video row gone, no WebView |
| 34  | Maestro         | yes             | yes                        | yes               | no                  | landscape, video row gone, no WebView |
| 34  | Auto-rotate off | no              | no                         | no                | yes                 | correct                               |
| 28  | Auto-rotate on  | yes             | yes                        | yes               | no                  | landscape, video row gone, no WebView |
| 28  | Maestro         | yes             | yes                        | yes               | no                  | landscape, video row gone, no WebView |
| 28  | Auto-rotate off | no              | no                         | no                | yes                 | correct                               |

## What decides it

- The display has to rotate. With auto-rotate off, turning the device does
  nothing and the video keeps playing.
- Every run where the display rotated laid out the root in landscape and
  unmounted the WebView.
- On API 28 the portrait-locked app did not rotate during fullscreen, so it
  did not reproduce there. The app without a lock did.

A stock setup that reproduces: Pixel 3a AVD on the API 34 `google_apis`
x86_64 image, default settings, `bun run android && bun run test`.

## Notes on the run files

- "Video still playing" is "frames advancing" in the files: two screenshots a
  second apart differ.
- On API 28 the video sometimes did not start on the first tap
  (`api28-locked-sensor-auto-off.txt`). The counters are not affected.
- "video row on screen" comes from `uiautomator dump`, which is unreliable
  while the video plays (`api28-locked-sensor-auto-on.txt` reports `no` for a
  run that passed).
- In the locked app the display returns to portrait as soon as the WebView is
  destroyed, so "display rotation" after turning reads 0. "display followed"
  is the reliable line.
