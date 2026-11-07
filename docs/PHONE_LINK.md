# Ithir phone companion

The Android app is a small foreground camera-module prototype for the Realme RMX3363. It shows connection state, camera state, model availability, and a bounded activity log. No model runs yet. Phone captures are stationary. Simulated map replay is available only in the optional sample survey.

The dashboard connects **directly over Bluetooth LE** using Web Bluetooth. A laptop bridge and Wi-Fi are not required for this link. Use desktop Chrome on macOS or Windows, served from `http://localhost` or HTTPS. Browser and operating-system Bluetooth permissions are required. Safari and Firefox are not supported by this prototype.

## Build and run

Requires JDK 17 or newer, Android SDK platform 36, build tools 35.0.0, and an Android phone supporting BLE peripheral advertising. SDK location comes from `ANDROID_HOME` or an untracked `android/local.properties` file containing `sdk.dir=/absolute/path/to/sdk`.

```sh
cd android
./gradlew assembleDebug
```

Install `android/app/build/outputs/apk/debug/app-debug.apk` on the phone. Android may ask permission to install this debug app. For an already authorized USB debugging connection:

```sh
adb install -r android/app/build/outputs/apk/debug/app-debug.apk
```

From the repository root, serve the dashboard:

```sh
python3 -m http.server 5173 --directory dashboard
```

1. On the phone, open **Ithir Phone** and tap **Start Bluetooth**. Grant Nearby devices permission. If Bluetooth was disabled, enable it and tap Start again.
2. Keep the app visible. Its six-digit connection code changes each time Bluetooth starts.
3. On the laptop, open `http://localhost:5173` in Chrome. Open **Phone**, enter the code, and click **Connect Bluetooth**. Select the advertised device. The custom service UUID filters the chooser; the displayed name may be the phone's system Bluetooth name.
4. Click **Ping phone**, or use **Send connection test** on the phone. Logs confirm actual packets without inventing observations.
5. Enable **Allow camera requests** on the phone and grant Camera permission. Click **Request image** in the dashboard. The phone opens the rear camera, captures one small JPEG, releases the camera, and transfers the image. No location is attached automatically.
6. **Stop camera** cancels an active capture. A JPEG already captured and queued may finish transferring. Disconnect abandons the transfer. Leaving the Android app or stopping Bluetooth releases the camera and disconnects the session. Idle does not run a preview, encoder, or model.

Photos are capped at 320 pixels on the longest side and 32,000 compressed bytes. They are temporary in-memory inspection images, not calibrated measurements or full-resolution survey evidence. No continuous video is implemented. Live video remains a separate future Wi-Fi/WebRTC feature.

The six-digit code gates this demonstration's commands; it is not encryption or a production security design. Keep the app foregrounded for the static demonstration. Background service operation and unattended flight are outside this prototype.

## Simulated LoRa constraints

The phone's optional **Limit link to 1 kbit/s (simulation)** switch paces outgoing notifications by their byte length. It includes serialized JSON and base64 overhead. This is an illustrative application-level cap, not an exact LoRa or LoRaWAN configuration. It does not emulate radio range, interference, duty cycle, energy consumption, or retransmissions. Images may take minutes; a seven-minute dashboard timeout bounds a request. Keep the switch off for the first Bluetooth connection test.

## Packet handoff for the AI teammate

This is a **proposed transport envelope**, ready for agreement with the model owner. It does not establish an agreed model result schema. Confirm findings, capture timestamps, locations, source evidence, failed/unavailable analysis, and delivery cadence before integrating the model.

| BLE item | UUID / format |
| --- | --- |
| Advertised service | `aa7a0001-7f6b-4c80-9f55-477f39b00001` |
| Dashboard → phone | `aa7a0002-7f6b-4c80-9f55-477f39b00001`, write with response |
| Phone → dashboard | `aa7a0003-7f6b-4c80-9f55-477f39b00001`, notifications |
| Framing | UTF-8 JSON followed by newline; packets may span many BLE operations |
| Limits | 1,024 bytes per incoming command; 65,536 bytes per outgoing packet; eight queued phone packets |

The dashboard writes chunks of at most 20 bytes. The phone sends notifications serially, using negotiated MTU up to 180 payload bytes. A new connection clears partial messages and queued packets. No automatic reconnect or durable queue is included.

Initial command:

```json
{"v":1,"type":"command","command":"hello","pin":"123456"}
```

The phone accepts the code and responds with `ready`, then `status`. Subsequent commands are `ping`, `capture`, and `stop_camera`, each with an `id`. Replies include `pong`, `ack`, `image`, or `error`. Status contains `camera`, `armed`, `model`, `battery` (nullable), and `simulatedBps` (nullable). All phone envelopes contain `v:1` and `sentAt` as Unix milliseconds. Image packets add `id`, `capturedAt` in Unix milliseconds, `mime:"image/jpeg"`, and `base64`.

The Android activity exposes `publishObservations(JSONArray observations, long capturedAt)` as the single integration handoff. Call it with agreed results; it posts onto the app thread and sends only during an authenticated connection. It sends this envelope:

```json
{"v":1,"type":"observations","capturedAt":1794056400000,"observations":[]}
```

The dashboard reuses `normaliseFeed` for received positions and findings. Empty or malformed results preserve existing observations. Do not attach the simulated drone route as the capture location. The current adapter labels received results unvalidated; no confidence or agronomic accuracy is asserted. The app displays **Model not connected** until an actual integration updates this implementation.

## Checks and limits

```sh
node --test dashboard/*.test.mjs
mkdir -p /tmp/corkathon-java-check
javac -d /tmp/corkathon-java-check android/app/src/main/java/ie/corkathon/phone/PacketBuffer.java android/app/src/test/java/ie/corkathon/phone/PacketBufferCheck.java
java -cp /tmp/corkathon-java-check ie.corkathon.phone.PacketBufferCheck
javac --release 8 -d /tmp/corkathon-java-check android/app/src/main/java/ie/corkathon/phone/PacketBuffer.java
```

The tests cover Bluetooth packet framing, fragmented UTF-8, malformed/oversized packet recovery, authentication gating, serialized writes, and disconnect cleanup. An APK build verifies Android compilation. Physical advertising, radio transfer, permissions, and Camera2 compatibility still require a connected phone; browser doubles do not verify hardware.
