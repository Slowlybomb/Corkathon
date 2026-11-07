# Ithir camera module

The Android app is a small foreground camera-module prototype for the Realme RMX3363. It shows connection state, camera state, model availability, and a bounded activity log. No model runs yet. Camera module captures are stationary. Simulated map replay is available only in the optional sample survey.

The dashboard connects **directly over Bluetooth LE** using Web Bluetooth. A laptop bridge and Wi-Fi are not required for this link. Use desktop Chrome on macOS or Windows, served from `http://localhost` or HTTPS. Browser and operating-system Bluetooth permissions are required. Safari and Firefox are not supported by this prototype.

## Build and run

Requires JDK 17 or newer, Android SDK platform 36, build tools 35.0.0, and an Android device supporting BLE peripheral advertising. SDK location comes from `ANDROID_HOME` or an untracked `android/local.properties` file containing `sdk.dir=/absolute/path/to/sdk`.

```sh
cd android
./gradlew assembleDebug
```

Install `android/app/build/outputs/apk/debug/app-debug.apk` on the camera module. Android may ask permission to install this debug app. For an already authorized USB debugging connection:

```sh
adb install -r android/app/build/outputs/apk/debug/app-debug.apk
```

For sharing the test build, send the APK as a file to the Realme, open it in the phone's file manager, and allow **Install unknown apps** for that file manager if prompted. Launch **Ithir Camera Module** after installation. The app requires Android 8.0 or newer. This is a debug-signed test build.

From the repository root, serve the dashboard:

```sh
python3 -m http.server 5173 --directory dashboard
```

1. On the camera module, open **Ithir Camera Module** and tap **Start Bluetooth**. Grant Nearby devices permission. If Bluetooth was disabled, enable it and tap Start again.
2. Keep the app visible. Its six-digit connection code changes each time Bluetooth starts.
3. On the laptop, open `http://localhost:5173` in Chrome. Open **Camera module**, enter the code, and click **Connect Bluetooth**. Select the advertised device. The custom service UUID filters the chooser; the displayed name may be the camera module's system Bluetooth name.
4. Click **Test connection**, or use **Send connection test** on the camera module. Logs confirm actual packets without inventing observations.
5. Enable **Share GPS and orientation** on the camera module, grant **Precise location / While using the app**, and turn on Android Location. Wait for a satellite fix outdoors or near a window. The dashboard shows coordinates, horizontal accuracy, GPS altitude, ground speed, heading, and tilt when available. Use **Locate drone** to centre the map. The first fresh GPS fix also centres it automatically.
6. Enable **Allow camera requests** on the camera module and grant Camera permission. Click **Request image** in the dashboard. The camera module opens the rear camera, captures one small JPEG, releases the camera, and transfers the image. A fresh phone GPS fix is attached when available, including its timestamp, age, and accuracy. Otherwise the image stays unlocated.
7. **Stop camera** cancels an active capture. A JPEG already captured and queued may finish transferring. Disconnect abandons the transfer. Leaving the Android app stops sensors, releases the camera, and disconnects the session. While sharing sensors, the screen stays awake; turning off the sharing switch releases the sensors. Camera idle does not run a preview, encoder, or model.

Photos are capped at 320 pixels on the longest side and 32,000 compressed bytes. They are temporary in-memory inspection images, not calibrated measurements or full-resolution survey evidence. No continuous video is implemented. Live video remains a separate future Wi-Fi/WebRTC feature.

Version 0.2 warms up the camera with discarded metering frames before taking the JPEG. Automatic exposure and white balance run for at least half a second, continuing until the camera reports settled exposure or a 2.5-second fallback expires. Automatic focus runs when supported. These frames stay on the phone; capture still sends one JPEG and releases the camera afterward. This addresses the immediate first-frame capture used in version 0.1. Very low light can still produce a dark or noisy image; compare captures on the Realme after installing the update.

The six-digit code gates this demonstration's commands; it is not encryption or a production security design. Keep the app foregrounded for the static demonstration. Background service operation and unattended flight are outside this prototype.

## Phone GPS and orientation

Version 0.3 reads satellite positions from Android [`GPS_PROVIDER`](https://developer.android.com/reference/android/location/LocationManager#GPS_PROVIDER) and orientation from [`TYPE_ROTATION_VECTOR`](https://developer.android.com/reference/android/hardware/SensorManager#getRotationMatrixFromVector(float%5B%5D,%20float%5B%5D)). The laptop supplies neither GPS nor orientation. No cached location is loaded at startup. Denied precise permission, disabled GPS, missing sensors, unreliable orientation, and missing fixes remain unavailable. Mock-provider locations are ignored. Keep the phone attached to the construction for the stationary demo; these are readings from the phone, not the flight controller.

The mounting convention is **screen up, top edge forward**. The model's nose follows that top edge, including tilt. Different mounting requires an explicit mounting transform; there is no automatic drone-frame calibration. The quaternion is device-to-magnetic East/North/Up, in `[x,y,z,w]` order. When fresh GPS is available, Android's geomagnetic model supplies declination: heading is corrected to true north. Otherwise the heading remains labelled magnetic. Metal and electronics can affect the compass. Sensor accuracy is reported, not guaranteed.

The dashboard's **Drone telemetry** bar shows a 3D attitude view, GPS position/accuracy, pitch, roll, and heading outside connection settings. Its attitude view works before GPS gets a fix; its centred model does not represent a geographic position. The map model still requires a fresh GPS fix. Both models use the same reported `headingDeg`, `pitchDeg`, and `rollDeg` values, with Android's rotation order `Rz(-heading) Rx(-pitch) Ry(roll)` and the phone-to-model mounting transform. Heading is already corrected by the phone when declination is available, so the renderer does not correct it twice. **Pitch 0° and roll 0° mean level at every heading.** Android positive pitch is nose-down; positive roll banks right. No hover animation adds tilt or movement to live data.

GPS altitude is metres above the WGS84 ellipsoid, not height above ground. When altitude is missing, the map draws the location on its map plane and the altitude readout stays unavailable. The 3D drone needs both a fresh GPS fix and orientation; GPS alone keeps a geographic point. Display size remains exaggerated. Sample rotor animation does not run for live sensor data.

Version 0.4 attempts up to five telemetry packets per second during an authenticated connection, or one per second with the simulated link limit. Actual cadence depends on Bluetooth throughput. It keeps no telemetry backlog and pauses these packets during image transfers. GPS expires after 15 seconds and orientation after 3 seconds. The browser adds the measured fragmented-packet transfer duration and time since reception to each reading's age, without comparing laptop and phone wall clocks. It hides expired readings and clears the marker on disconnect. Low-bandwidth transfer can therefore leave orientation unavailable; keep the simulated link limit off for the first sensor test. Selecting the sample survey explicitly restores its labelled replay; failed Bluetooth pairing preserves it.

Telemetry packets add `type:"telemetry"`, `gpsState`, `orientationState`, and nullable `location`/`orientation` objects. Location fields are `latitude`, `longitude`, `accuracyM`, nullable `altitudeM`, `altitudeAccuracyM`, `speedMps`, Unix-millisecond `capturedAt`, monotonic `ageMs`, and `mock:false`. Orientation fields are `quaternion`, `reference:"magnetic"` (the quaternion reference), nullable `declinationDeg`, `headingDeg` (true when declination exists), `pitchDeg`, `rollDeg`, `accuracy:"low"|"medium"|"high"`, `capturedAt`, and `ageMs`. Image packets optionally carry the same location object, representing the GPS reading available when the JPEG was received from the camera, rather than a precisely synchronised shutter location.

## Simulated LoRa constraints

The camera module's optional **Limit link to 1 kbit/s (simulation)** switch paces outgoing notifications by their byte length. It includes serialized JSON and base64 overhead. This is an illustrative application-level cap, not an exact LoRa or LoRaWAN configuration. It does not emulate radio range, interference, duty cycle, energy consumption, or retransmissions. Images may take minutes; a seven-minute dashboard timeout bounds a request. Keep the switch off for the first Bluetooth connection test.

## Packet handoff for the AI teammate

This is a **proposed transport envelope**, ready for agreement with the model owner. It does not establish an agreed model result schema. Confirm findings, capture timestamps, locations, source evidence, failed/unavailable analysis, and delivery cadence before integrating the model.

| BLE item | UUID / format |
| --- | --- |
| Advertised service | `aa7a0001-7f6b-4c80-9f55-477f39b00001` |
| Dashboard → camera module | `aa7a0002-7f6b-4c80-9f55-477f39b00001`, write with response |
| Camera module → dashboard | `aa7a0003-7f6b-4c80-9f55-477f39b00001`, notifications |
| Framing | UTF-8 JSON followed by newline; packets may span many BLE operations |
| Limits | 1,024 bytes per incoming command; 65,536 bytes per outgoing packet; eight queued camera module packets |

The dashboard writes chunks of at most 20 bytes. The camera module sends notifications serially, using negotiated MTU up to 180 payload bytes. A new connection clears partial messages and queued packets. No automatic reconnect or durable queue is included.

Initial command:

```json
{"v":1,"type":"command","command":"hello","pin":"123456"}
```

The camera module accepts the code and responds with `ready`, then `status`. Subsequent commands are `ping`, `capture`, and `stop_camera`, each with an `id`. Replies include `pong`, `ack`, `image`, or `error`. Status contains `camera`, `armed`, `model`, `battery` (nullable), and `simulatedBps` (nullable). All camera module envelopes contain `v:1` and `sentAt` as Unix milliseconds. Image packets add `id`, `capturedAt` in Unix milliseconds, `mime:"image/jpeg"`, and `base64`.

The Android activity exposes `publishObservations(JSONArray observations, long capturedAt)` as the single integration handoff. Call it with agreed results; it posts onto the app thread and sends only during an authenticated connection. It sends this envelope:

```json
{"v":1,"type":"observations","capturedAt":1794056400000,"observations":[]}
```

The dashboard reuses `normaliseFeed` for received positions and findings. Empty or malformed results preserve existing observations. Do not attach the simulated drone route as the capture location. The current adapter labels received results unvalidated; no confidence or agronomic accuracy is asserted. The app displays **Model not connected** until an actual integration updates this implementation.

## Checks and limits

```sh
cd android
./gradlew assembleDebug lintDebug
cd ..
node --test dashboard/*.test.mjs
mkdir -p /tmp/corkathon-java-check
javac -d /tmp/corkathon-java-check android/app/src/main/java/ie/corkathon/phone/PacketBuffer.java android/app/src/test/java/ie/corkathon/phone/PacketBufferCheck.java
java -cp /tmp/corkathon-java-check ie.corkathon.phone.PacketBufferCheck
javac -d /tmp/corkathon-java-check android/app/src/main/java/ie/corkathon/phone/ExposureGate.java android/app/src/test/java/ie/corkathon/phone/ExposureGateCheck.java
java -cp /tmp/corkathon-java-check ie.corkathon.phone.ExposureGateCheck
javac -cp "$ANDROID_HOME/platforms/android-36/android.jar" -d /tmp/corkathon-java-check android/app/src/main/java/ie/corkathon/phone/PhoneTelemetry.java android/app/src/test/java/ie/corkathon/phone/PhoneTelemetryCheck.java
java -cp "/tmp/corkathon-java-check:$ANDROID_HOME/platforms/android-36/android.jar" ie.corkathon.phone.PhoneTelemetryCheck
javac --release 8 -d /tmp/corkathon-java-check android/app/src/main/java/ie/corkathon/phone/PacketBuffer.java
```

The tests cover Bluetooth packet framing, fragmented UTF-8, malformed/oversized packet recovery, authentication gating, serialized writes, and disconnect cleanup. An APK build verifies Android compilation. Physical advertising, radio transfer, permissions, and Camera2 compatibility still require a connected camera module; browser doubles do not verify hardware.

`ExposureGateCheck` verifies the minimum metering delay, waiting for settled exposure, the bounded fallback for missing exposure metadata, and preventing duplicate captures from late callbacks. It does not verify image brightness or the physical camera pipeline.

`PhoneTelemetryCheck` verifies monotonic sensor ageing and rejecting missing, future, and expired samples. Dashboard tests cover independent GPS/orientation validation, expiry, mounting quaternion/declination, and fragmented-packet duration. `node scripts/check-panels.mjs` checks the real browser UI and map with a doubled Bluetooth radio, including geographic placement, missing readings, located captures, disconnect cleanup, and cancelled pairing. GPS acquisition, compass quality, and the physical mounting still require a phone test.

For the first physical test, leave the simulated link limit off, connect with the six-digit code, run **Test connection**, and request an image after allowing the camera. Confirm an actual JPEG appears in the dashboard. Then stop Bluetooth and reconnect to check that a fresh code works. Denied permissions should leave the app usable; grant them in Android settings before retrying. Keep the app visible throughout the test.
