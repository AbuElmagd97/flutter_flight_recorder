# Walkthrough

Follow these steps in order. Each one builds on the last.

## Step 1: Install the core package

Add this to your `pubspec.yaml`, under `dependencies:`

```yaml
flutter_flight_recorder: ^0.0.7
```

Run `flutter pub get`.

Then add these 2 lines to your `main()`, in `lib/main.dart`:

```dart
import 'package:flutter_flight_recorder/flutter_flight_recorder.dart';

void main() {
  FlightRecorder.init(); // add this line
  runApp(const MyApp());
}
```

`FlightRecorder.init()` must be called before `runApp()`.

**How do I know it worked?**
Nothing visible happens yet — the recorder is now silently capturing errors and lifecycle events in the background. That's expected. Go to Step 2 to see actual proof.

## Step 2: See it working

Add this anywhere you can run code after `init()` — for example, in a button's `onPressed` or right after `runApp()` for a one-time check. This example uses a button:

```dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_flight_recorder/flutter_flight_recorder.dart';

ElevatedButton(
  onPressed: () {
    FlightRecorder.recordAction('button_tapped');
    FlightRecorder.recordAction('user_viewed_screen');

    final incident = FlightRecorder.createIncident(title: 'Test incident');
    // jsonEncode just makes the output readable in your terminal
    print(jsonEncode(incident.toJson()));
  },
  child: const Text('Test Flight Recorder'),
)
```

Tap the button, then look at your terminal (where `flutter run` is printing output). You'll see a JSON object printed with a `timeline` array containing the two actions you just recorded. That JSON is your proof it's working.

## Step 3: Add the QA bug reporter (optional)

Skip this step entirely if you only need background recording.

Add this pubspec.yaml dependency first, the same way as Step 1:

```yaml
flutter_flight_recorder_reporter: ^0.0.7
```

Wrap your app's root widget with `FlutterFlightRecorderReporter`:

```dart
import 'package:flutter_flight_recorder_reporter/flutter_flight_recorder_reporter.dart';

void main() {
  FlightRecorder.init();
  runApp(
    const FlutterFlightRecorderReporter(
      child: MyApp(), // your existing root widget
    ),
  );
}
```

To open the reporter from a button (guaranteed to work regardless of shake sensitivity), call this from any widget inside `MyApp`:

```dart
FlutterFlightRecorderReporter.open(context);
```

## Step 4: Add Dio request tracking (optional)

Skip this step entirely if you don't use Dio.

Add this pubspec.yaml dependency first, the same way as Step 1:

```yaml
flutter_flight_recorder_dio: ^0.0.7
```

Then add this one line wherever you create your `Dio` instance:

```dart
import 'package:flutter_flight_recorder_dio/flutter_flight_recorder_dio.dart';

dio.interceptors.add(FlightRecorderDioInterceptor());
```

## If something's not working

1. Did you call `FlightRecorder.init()` before `runApp()`? See [Step 1](#step-1-install-the-core-package). Fix: move `FlightRecorder.init()` above the `runApp()` line.
2. Are you calling `record*`/`log` methods AFTER `init()`, not before? Fix: move the call below `FlightRecorder.init()`, or move `init()` earlier.
3. If using the reporter and nothing opens: are you calling `FlutterFlightRecorderReporter.open(context)` from a widget that's actually inside the wrapped subtree? Fix: only call `.open(context)` from a widget built underneath the `child:` you passed to `FlutterFlightRecorderReporter`.
