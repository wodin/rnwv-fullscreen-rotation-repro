# react-native-webview: rotating during fullscreen lays out the app in landscape

Android repro for `react-native-webview` 17.1.0 on React Native 0.88.1.

When web content goes fullscreen, the library sets the activity's requested
orientation to `UNSPECIFIED` and hides only the WebView. If the device is then
rotated, the React root is laid out in landscape underneath the video, even in
an app that is locked to portrait. A list that re-windows for the new size can
unmount the row holding the WebView, which destroys it and ends fullscreen.

## The app

One screen: a `FlatList` of square rows, with a WebView in row 20. The page is
inline HTML with a `<video>` fed by a canvas, so it needs no network. Tapping
it toggles fullscreen.

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

By hand: tap the video, rotate the device, and read the counters after
leaving fullscreen.

## Result on 17.1.0

Pixel 3a emulator, API 34. Full output is in [`output/`](output).

| Variant  | Expected                                            | Actual                                              |
| -------- | --------------------------------------------------- | --------------------------------------------------- |
| Locked   | `mounts: 1, unmounts: 0, layouts: 393x807`          | `mounts: 2, unmounts: 1, layouts: 393x807, 807x393` |
| Unlocked | `mounts: 1, unmounts: 0, layouts: 393x807, 807x393` | `mounts: 1, unmounts: 1, layouts: 393x807, 807x393` |
