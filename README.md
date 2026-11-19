# react-native-webview: rotating during fullscreen lays out the app in landscape

Android repro for `react-native-webview` 17.1.0 on React Native 0.88.1.

When web content goes fullscreen, the library sets the activity's requested
orientation to `UNSPECIFIED` and hides only the WebView. If the device is then
rotated, the React root is laid out in landscape underneath the video, even in
an app that is locked to portrait. A list that re-windows for the new size can
unmount the row holding the WebView, which destroys it and ends fullscreen.

## The app

One screen: a `FlatList` of square rows as wide as the root view, with a
WebView in row 20. The page is inline HTML with a `<video>` fed by a canvas, so
it needs no network. Tapping it toggles fullscreen.

Three counters sit above the list:

- `mounts` and `unmounts` of the WebView row
- `layouts`: each distinct size the root view was laid out at

## Run

Needs Bun, the Android SDK, a running emulator or device, and
[Maestro](https://maestro.dev).

```sh
bun install

# Locked to portrait
bun run android
bun run test

# No orientation lock
bun run android:unlocked
bun run test:unlocked
```

Two more flows run against the locked app:

- `bun run test:modal`: the same, with the WebView inside a `Modal`.
- `bun run test:swap`: adds `onOpenWindow` while the video is fullscreen, which
  makes the library replace its `WebChromeClient`. Leaving fullscreen then
  leaves the fullscreen view on screen.

By hand: tap the video, rotate the device, and read the counters after
leaving fullscreen.

## Result on 17.1.0

Pixel 3a emulator, API 34. Full output is in [`output/`](output).

| Variant  | Expected                                     | Actual                                |
| -------- | -------------------------------------------- | ------------------------------------- |
| Locked   | `mounts: 1, unmounts: 0`                     | `mounts: 2, unmounts: 1`              |
| Unlocked | `Exit fullscreen` on screen after rotating   | not found, the WebView was destroyed  |
| Modal    | `mounts: 2, unmounts: 1`                     | `mounts: 3, unmounts: 2`              |
| Swap     | back to the list, `Enter fullscreen` visible | fullscreen view stays on screen       |

The Modal closing unmounts its own WebView, so one unmount is expected there.

The flows print `layouts` but do not assert on it. On 17.1.0 the locked app
reports `393x807, 807x393`. The unlocked app comes back in landscape and
unmounts the row then, so its flow checks for `Exit fullscreen` instead of
`unmounts: 0`.

## Result with the fix

This branch installs `react-native-webview-fix.tgz`, built from
[`fix/fullscreen-root-hide`](https://github.com/wodin/react-native-webview/tree/fix/fullscreen-root-hide).
All four flows pass on the Pixel 3a emulator (API 34) and on a Galaxy A34
(Android 16). Output is in `output/*-fix-api34.txt` and `output/*-fix-a34.txt`.

The locked app still reports two `layouts`. The library restores the
orientation and shows the root in the same step, and the root is measured once
before the display has turned back.

## Conditions

The display has to rotate, so auto-rotate must be on. See
[`output/conditions.md`](output/conditions.md) for the runs on two emulators
with auto-rotate on and off. `scripts/conditions.sh` produces them.
