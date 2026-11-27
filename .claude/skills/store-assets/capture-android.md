# Capture on Android

- `adb devices -l`; with two transports for one device set `ANDROID_SERIAL` to the USB serial.
- Capture: `adb exec-out screencap -p > <workspace>/raw-<lang>/<screen>.png`.
- Crop the status bar: set `title_px` on these frames to its height in pixels (measure one capture).
- Close overlays first (chat heads, translator bubbles) and set the app language through the system per-app
  language setting; put the phone's own settings back afterwards.
- Read each capture before the next one: a toast or keyboard ruins the frame.
