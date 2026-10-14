# Prompts

Prompts used with Claude Code while building SnapSync, in order.

## 1. Project setup and scaffolding

```text
You are helping me build a Flutter assessment app named "snapsync" in an existing, empty Flutter project. Refer to the doc for the specifications and the screenshots to get idea about the two screens. Do project setup and scaffolding ONLY. Do not implement feature logic yet.

App summary: a custom camera app with a resilient upload queue.
- CameraPreviewScreen: custom camera UI with pinch-to-zoom, a zoom slider, rounded zoom buttons (0.5x, 1x, 2x, based on the available back cameras), and tap-to-focus with a visual indicator at the tap point.
- Users capture images into batches. A list of "Pending Uploads" (Upload Manager screen) shows each image or batch with its status.
- Resilient sync engine: a background worker (workmanager) monitors connectivity. If an upload fails because of low bandwidth or no internet, the images stay in the local queue and are retried automatically once a stable connection is detected, without user intervention.
- No real API is available, so the upload layer must sit behind an interface with a mock implementation that returns hard-coded success or failure (switchable), and the real HTTP call must be present only as clearly commented-out code.
- State management: BLoC/Cubit (flutter_bloc). Architecture: layered (presentation, domain, data) with a clean separation.
The attached images are the reference UI for the camera screen and the Upload Manager screen.

1. Dependencies and configuration
- Look up the current stable versions of Flutter-compatible packages yourself with `flutter pub add`; do not guess versions from memory. List the versions you chose in your final summary.
- Packages: flutter_bloc, equatable, get_it, camera, path_provider, path, sqflite, workmanager, connectivity_plus, permission_handler, uuid, intl. Dev: bloc_test, mocktail, flutter_lints (or the lints package the project already uses).
- If any package conflicts with the installed Flutter/Dart SDK, tell me and propose the closest compatible choice before continuing.
- Android configuration: set an appropriate minSdk for camera and workmanager (state which and why), add permissions CAMERA, INTERNET and ACCESS_NETWORK_STATE to AndroidManifest.xml, and make sure the Gradle config builds with the current Flutter template. Do not add permissions that are not needed.
- Set the app label to "SnapSync" and keep the application id as generated.
- Enable stricter analysis options (strict-casts, strict-inference, strict-raw-types) and fix any resulting issues in the scaffold.
- Do not add any API keys or secrets anywhere.

2. Architecture and folder structure (under lib/)
- core/: di (get_it setup), constants, error types (a small sealed Failure hierarchy), utils, theme (Material 3, dark theme matching the reference screenshots: dark navy surfaces, blue accent, green for stable/synced, amber for retrying, red for failed).
- domain/: entities (CaptureBatch, CapturedImage, UploadStatus enum with at least: queued, waitingForConnection, uploading, retrying, uploaded, failed), repository interfaces (BatchRepository, UploadApi/UploadRepository), and small use cases.
- data/: local (database helper, DAO-style classes, models and mappers), file storage service, repository implementations, remote (MockUploadApi plus a commented-out RealUploadApi sketch using package:http style calls, kept entirely in comments, with no real URL).
- presentation/: camera (CameraPreviewScreen, CameraCubit, widgets), upload_manager (UploadManagerScreen, SyncCubit, widgets), batch (BatchCubit).
- background/: workmanager callback dispatcher and task names.
- Create stubs and interfaces with TODO bodies only where logic is needed. Keep each file small and single-purpose. Entities are immutable and extend Equatable.

3. App wiring
- main.dart: ensure bindings initialised, set up get_it, initialise Workmanager with a top-level callbackDispatcher annotated with @pragma('vm:entry-point') in background/, and run the app. Add a clear TODO where the periodic and one-off tasks will be registered later.
- A simple app shell with named routes between CameraPreviewScreen (home) and UploadManagerScreen, using placeholder screens that just show the screen name for now.
- A single place (core/constants) for tunable values: maximum upload retries, backoff base delay, stable-connection check parameters, mock API failure toggle default.

4. Housekeeping
- .gitignore covering keystores (*.jks, *.keystore), key.properties, local.properties, build outputs and IDE files (extend the Flutter default).
- README.md skeleton with exactly these headings: 1. Project Title and Description, 2. Project Structure / Approaches, 3. Generative AI Usage, 4. How to Run, 5. Screenshots. Leave bodies as TODO.
- PROMPTS.md containing this prompt as the first entry.
- Replace the default widget_test with a trivial smoke test that passes.

5. Verification
- Run flutter pub get, flutter analyze (must be clean), flutter test, and flutter build apk --debug, and fix any errors properly. Do not disable lints or analysis rules to pass.
- Finish with a short summary: package versions chosen, the folder tree, minSdk and why, and anything you assumed.

Rules: no secrets or keys in code or committed files; ask me before adding any dependency not listed above; keep to the architecture described.
```

## 2. Domain and data layers

```text
Continue on the existing "snapsync" Flutter project. Scaffolding is done. In this step, implement the DOMAIN and DATA layers with unit tests. Do not touch camera, sync/Workmanager logic or any real UI yet.

Before writing code, review the existing folder structure, entities, interfaces and constants, and reuse them. Tell me if you need to change any earlier decision.

1. Domain
- Entities (immutable, Equatable): CapturedImage(id, batchId, filePath, fileSizeBytes, capturedAt, status, attemptCount, lastError, nextRetryAt, uploadedAt), CaptureBatch(id, createdAt, submittedAt?, images) with derived getters (isSubmitted, total count, uploaded count, aggregate status, total bytes).
- UploadStatus: queued, waitingForConnection, uploading, retrying, uploaded, failed (permanent failure after max retries). Document the allowed transitions in a comment and enforce them in one place (a pure function or method). Illegal transitions must throw a typed error, not silently succeed.
- Sealed Failure types used here: NoInternetFailure, LowBandwidthFailure (timeout or too slow), ServerFailure(code), StorageFailure, FileMissingFailure, UnknownFailure. Distinguish retryable from non-retryable via a getter.
- Repository interfaces:
  - BatchRepository: getOrCreateOpenBatch(), addImage(batchId, capturedFile), removeImage(imageId), submitBatch(batchId) (marks all its images queued and sets submittedAt), watchOpenBatch(), watchSubmittedBatches(), getUploadable(now) (images that are queued, waitingForConnection or retrying and whose nextRetryAt is null or due), updateImageStatus(...), markUploaded(imageId), deleteBatch(batchId), refresh().
  - UploadApi: Future<UploadResult> upload(CapturedImage image, {void Function(double progress)? onProgress}) with a typed result (success with a server reference, or a Failure).
- Use cases (small classes, one public method each): AddCapturedImage, SubmitBatch, RemoveImage, GetUploadableImages, RecordUploadResult (applies the transition rules, increments attempts, computes nextRetryAt with exponential backoff and jitter using constants from core/constants, and moves to failed after the maximum retries only for retryable failures exhausted or any non-retryable failure), RecoverInterruptedUploads.
- Backoff must be a pure function with an injectable random source and clock so it can be tested.

2. Data: local storage
- A DatabaseHelper using sqflite with a versioned schema and an onUpgrade skeleton. Tables: batches and images (foreign key with ON DELETE CASCADE, foreign keys enabled via onConfigure). Indices on status and nextRetryAt. Store timestamps as UTC epoch milliseconds.
- IMPORTANT: the database must be usable from a Workmanager background isolate. The helper must not depend on get_it state created in the main isolate, must resolve the database path itself, and must be safe to open from two isolates (use a single shared path, enable WAL if appropriate, and wrap multi-row changes in transactions). Explain your approach in a comment.
- Models and mappers between DB rows and domain entities. No raw maps leaking outside the data layer.
- ImageFileStorage service: copies a captured file from the camera's temp location into the app documents directory under batches/<batchId>/<imageId>.<ext> so the image survives cache cleaning; computes the file size; deletes a file; deletes a whole batch directory; checks existence. Handle missing files and IO errors by returning typed StorageFailure or FileMissingFailure rather than throwing raw exceptions.
- BatchRepositoryImpl: implements the interface. Reactive watch methods can be built on an in-process StreamController or change notifier that fires after every write, plus the refresh() method, because writes made by a background isolate will NOT trigger the main isolate's stream; refresh() must re-emit from the database so the UI can call it on app resume and on a timer later.
- RecoverInterruptedUploads: on app start and on every background task start, any image still marked uploading (the process was killed mid-upload) must be reset to queued.
- When an uploaded image succeeds, delete its local file but keep its row for the "synced" history; make that behaviour explicit and covered by a test.
- A batch is deleted only when the user removes it or after a configurable retention period; do not implement the retention job, just expose deleteBatch.

3. Data: remote (mock)
- MockUploadApi implements UploadApi. It is configurable at runtime through a small MockUploadConfig object (mutable, held in get_it) with: a mode (alwaysSuccess, alwaysNoInternet, alwaysLowBandwidth, alwaysServerError, flaky with a configurable success probability and seeded Random), simulated latency range, and chunked progress callbacks that emit realistic progress over the simulated duration. The default mode comes from core/constants.
- The mock must respect cancellation or simply finish its simulated delay without leaking timers.
- Keep the commented-out RealUploadApi sketch updated so it matches the UploadApi interface (multipart upload with a timeout, a typed mapping of SocketException to NoInternetFailure and timeouts to LowBandwidthFailure, an idempotency key header built from the image id so a retried upload never creates duplicates on the server). It must be entirely in comments, with no real URL, token or key.
- Register everything in get_it in a way that works from both isolates (a function the background entry point can also call).

4. Unit tests (flutter_test, mocktail; for the database tests you may add sqflite_common_ffi as a dev dependency, this is the only extra dependency I approve)
- Status transition rules: every legal transition passes, illegal ones throw.
- Backoff: grows exponentially, is capped, jitter stays within bounds, deterministic with a seeded random and fake clock.
- RecordUploadResult: success marks uploaded; retryable failure increments attempts and schedules the next retry; reaching the maximum attempts moves to failed; a non-retryable failure goes to failed immediately.
- Repository with an in-memory or temp-file database: create open batch, add images, submit batch queues them all, getUploadable respects nextRetryAt, foreign key cascade, recovery of images stuck in uploading, refresh() re-emits, uploaded image deletes its file but keeps its row.
- ImageFileStorage with a temporary directory: copy, size, delete, missing file handling.
- MockUploadApi: each mode returns the expected result, progress is monotonic and ends at 1.0, a seeded flaky mode is reproducible.

5. Verification
- Run flutter analyze (must be clean), flutter test, and flutter build apk --debug. Fix failures properly and do not weaken or delete tests.
- Finish with a summary: files created, public interfaces, the status transition table, the multi-isolate approach, assumptions, and anything that can only be verified on a physical device.

Rules: no secrets or URLs in code; handle every failure explicitly instead of swallowing exceptions; keep functions small; ask me before adding any dependency other than sqflite_common_ffi.
```

## 3. Sync engine, connectivity, background scheduling and SyncCubit

```text
Continue on the existing "snapsync" Flutter project. Domain and data layers are done and tested. In this step, implement the SYNC ENGINE: upload orchestration, connectivity monitoring, Workmanager background scheduling and the SyncCubit. Do not build the real UI or touch the camera yet (the Upload Manager placeholder may display raw state for manual testing).

Before writing code, review the existing entities, repositories, use cases, constants, DI setup and the background/ folder, and reuse them. Tell me if you need to change any earlier decision.

IMPORTANT: look up the CURRENT API of the workmanager and connectivity_plus packages (the installed versions) from their documentation or source before using them. Do not rely on memory of older APIs. Tell me which API surface you used.

1. Sync engine (domain/ and data/, pure Dart where possible)
- SyncEngine with one public method: Future<SyncPassResult> runPass(). One pass: recover interrupted uploads, load uploadable images (respecting nextRetryAt), upload them one at a time (or with a small configurable concurrency, default 1, justify), record each result through RecordUploadResult, and stop early if connectivity is lost or a pause flag is set. Return a summary (uploaded, failed, retrying, remaining, nextRetryAt of the soonest item).
- CLAIMING: two isolates (app and background worker) can run a pass at the same time. Make claiming atomic at the database level (for example UPDATE ... SET status='uploading', claimedAt=now WHERE id=? AND status IN (...) and check the affected row count) so an image is never uploaded twice. Add a claim timeout so a claim abandoned by a killed process is released by RecoverInterruptedUploads. Update the schema with a proper migration if needed.
- Failure handling:
  - NoInternetFailure: mark waitingForConnection WITHOUT consuming a retry attempt, and end the pass.
  - LowBandwidthFailure and retryable ServerFailure: mark retrying, increment attempts, schedule nextRetryAt with backoff.
  - Non-retryable failures: mark failed with lastError.
  - FileMissingFailure: mark failed, never retry.
- Progress: expose a Stream of SyncProgress events (imageId, fraction, bytes) from the engine for the foreground UI. Background runs just persist state.
- A persisted "paused" flag (store it in the database or a small key-value table so both isolates see it). When paused, runPass returns immediately.

2. Connectivity and "stable connection"
- ConnectivityMonitor interface plus an implementation built on connectivity_plus. Expose Stream<LinkQuality> with values: offline, unstable, stable. connectivity_plus only reports the network interface, not real internet access, so define "stable" properly: connected for a continuous debounce period (constant, e.g. 3 seconds) AND a lightweight reachability probe succeeds with latency under a threshold. The probe must be an interface (ReachabilityProbe) with a MockReachabilityProbe driven by the same MockUploadConfig as the mock API (so airplane mode and the mock failure modes behave consistently), and a commented-out real implementation sketch. Do not hit any real URL.
- Handle flapping connectivity (debounce and cancel in-flight stable checks when the link drops). Handle the connectivity_plus result being a list of results in current versions.
- The monitor must work in both isolates.

3. Background scheduling (background/)
- Abstract the plugin behind SyncScheduler (interface) with a WorkmanagerSyncScheduler implementation, so the rest of the code and the tests do not depend on the plugin.
- Tasks:
  a) A unique ONE-OFF task "snapsync.sync.now" with constraint NetworkType.connected and exponential backoff (the plugin's own backoff policy), enqueued with a replace or keep policy chosen deliberately (explain which and why) whenever: a batch is submitted, an upload fails with a retryable failure, or connectivity returns while the app is in the foreground.
  b) A unique PERIODIC safety-net task "snapsync.sync.periodic" at the platform minimum frequency (15 minutes) with the connected constraint, registered once at startup.
- The top-level callbackDispatcher (already in background/, annotated @pragma('vm:entry-point')) must: ensure bindings are initialised, set up DI via the shared function (no main-isolate state), run SyncEngine.runPass(), and return a bool that tells Workmanager whether to retry (true when retryable work remains or the pass was interrupted by connectivity loss, false when there is nothing left). Wrap everything in try/catch so an exception never kills the isolate silently: log it and return true for transient errors.
- A debug-only hook (guarded by kDebugMode) to trigger an immediate one-off background run, for testing.
- Document in comments the platform limits that matter: the 15-minute minimum for periodic work, battery optimisation and doze effects, and that background timing is not guaranteed. Mention these in the final summary so I can put them in the README honestly.

4. SyncCubit (presentation/upload_manager/)
- State (Equatable): list of UploadItemViewModel (image id, display name, thumbnail path, size, status, progress, attempt text such as "Retrying... (attempt 2/3)", last error), submitted batches summary, overall progress (uploaded bytes over total bytes of the queue), link quality, isPaused, isSyncing, and a one-off message channel for snackbars (via a field consumed once or a separate stream).
- Behaviour:
  - Listens to BatchRepository.watchSubmittedBatches(), the engine's progress stream and the ConnectivityMonitor.
  - When the link becomes stable and there is uploadable work, runs a foreground pass immediately and schedules a background one-off as a fallback.
  - When the link goes offline, items show waitingForConnection; nothing is lost.
  - Calls repository.refresh() when the app resumes (WidgetsBindingObserver wired in the presentation layer, not inside the cubit) and on a light timer while the Upload Manager is visible, so changes made by the background isolate appear.
  - Public methods: retryItem(id), retryAllFailed(), pauseAll(), resumeAll(), removeItem(id), startSyncNow().
  - Cancel all subscriptions and timers in close().
- BatchCubit (presentation/batch/): holds the current open batch, its image count, capture and delete actions, and submitBatch() which calls SubmitBatch and then asks the scheduler to enqueue a one-off sync. Keep it small.

5. Tests (flutter_test, bloc_test, mocktail; fake clocks, seeded randoms)
- SyncEngine: all-success pass; NoInternet ends the pass without consuming an attempt; LowBandwidth schedules a retry with backoff; max retries lead to failed; non-retryable failure leads to failed; FileMissing leads to failed; pause stops the pass; early stop on connectivity loss; two engines running concurrently never upload the same image twice (use a shared test database and a mock API that records calls).
- Claim timeout releases abandoned claims.
- ConnectivityMonitor: stable only after the debounce plus a successful probe, flapping resets, offline emits immediately.
- SyncCubit via bloc_test: queue shows waitingForConnection when offline; link becoming stable triggers a pass and the items move to uploaded; failures show retry text; pauseAll and resumeAll; retryAllFailed; refresh on resume picks up changes written by another connection to the same database.
- BatchCubit: submitBatch calls the use case and enqueues the scheduler once.
- WorkmanagerSyncScheduler must be tested only through its interface with a fake, plus a small test that the task names and constraints are built as intended if the plugin API allows it.

6. Verification
- Run flutter analyze (must be clean), flutter test and flutter build apk --debug. Fix failures properly, do not weaken tests.
- Finish with a summary: the API versions you used, the sync flow in a short numbered list, the claim mechanism, the platform limits, assumptions, and a manual device test checklist covering: (1) submit a batch in airplane mode, items stay queued as "waiting for connection"; (2) turn airplane mode off, upload resumes with no user action while the app is open; (3) same test with the app in the background; (4) same test after swiping the app away from recents; (5) force-stop during an upload and confirm recovery; (6) mock mode alwaysLowBandwidth shows retrying with increasing delays; (7) pause and resume.

Rules: no secrets or real URLs in code; handle every failure explicitly instead of swallowing exceptions; no logging of file paths beyond debug builds; keep functions small; ask me before adding any dependency.
```

## 4. Camera logic

```text
Continue on the existing "snapsync" Flutter project. Domain, data and sync layers are done and tested. In this step, implement the CAMERA LOGIC: a camera service, CameraCubit, zoom, tap-to-focus, lens switching, capture into the open batch, and permission and hardware-failure handling. Do not build the final UI yet. A minimal temporary CameraPreviewScreen (live preview plus plain buttons to exercise each feature) is fine.

Before writing code, review the existing entities, use cases (AddCapturedImage and others), BatchCubit, DI setup and constants, and reuse them. Tell me if you need to change any earlier decision.

IMPORTANT: look up the CURRENT API of the installed camera package and permission_handler (documentation or source) before using them. Do not rely on memory of older APIs. Tell me which API surface you used. Where the camera package behaves differently across devices, say so in code comments and in the final summary.

1. CameraService (data/ or core/, behind an interface so the cubit can be tested with a fake)
- Interface CameraService, implemented by CameraPackageService wrapping CameraController. It exposes: initialise(CameraDescription, resolution preset), dispose(), the live preview widget or controller handle needed by the UI, zoom range (min, max), setZoom(double), setFocusPoint(Offset normalised), setExposurePoint(Offset normalised), setFlashMode, capture() returning a temp file, supportsFocus/supportsFlash flags, and a stream or callback for camera errors.
- Camera discovery: list available cameras once, group them into back and front. Back cameras may be reported as one logical camera or several (wide, ultra-wide, telephoto) depending on the device. Build a ZoomPresets model from what is actually available:
  - 1x is always present.
  - 0.5x is offered ONLY if it can really be achieved: either the controller's minimum zoom level is below 1.0 (then map 0.5x to that zoom), or a second back camera exists that can plausibly be the ultra-wide (then switch to it). If neither applies, do not show 0.5x at all. Never fake a 0.5x button that does nothing.
  - 2x is offered if max zoom is at least 2.0 (digital or optical).
  - Express the presets as a list of ZoomPreset(label, targetZoom, optional cameraToSwitchTo) so the UI just renders them.
  - Document the heuristic used for "which back camera is the ultra-wide" and its limits honestly.
- Resolution: default to a high preset, with automatic fallback to a lower one if initialisation fails. Use JPEG output. Disable audio (enableAudio: false) so no microphone permission is needed.
- Lock capture orientation sensibly or handle rotation so saved images are upright; explain what you chose.

2. Zoom
- Pure, testable logic (a ZoomController class or functions, no Flutter dependencies): clamp to [min, max]; pinch scale to zoom (base zoom at gesture start multiplied by scale); slider value (0..1) to zoom and back using a logarithmic or perceptually even mapping (explain the choice) so 0.5x to 2x feels even; snapping of the displayed preset button to the nearest preset when within a small tolerance.
- setZoom calls are async and can arrive faster than the platform handles them. Coalesce updates (apply only the latest pending value, never queue a backlog) and never let a slow zoom call freeze the UI.
- Zoom resets to 1x when switching lens, and the state always reflects the real current zoom, so pinch, slider and buttons stay in sync with each other.

3. Tap to focus
- Pure function that converts a tap position in the preview widget's local coordinates to the normalised (0..1) point the camera expects, correctly accounting for the preview's actual displayed size, aspect ratio, any letterboxing, and device orientation. Unit test it with several sizes and corner cases (taps at corners, outside the preview area ignored).
- CameraCubit state holds focusIndicator (position in widget coordinates, a timestamp or id, and a phase: focusing, locked/done, failed). The cubit sets the focus and exposure point, then auto-clears the indicator after a short constant duration. A new tap replaces the previous indicator immediately.
- If the device does not support focus points, show nothing and do not crash; surface supportsFocus in state.
- Optional but welcome: a long-press (or double-tap) to lock focus/exposure, shown differently. Skip it if it complicates the code; tell me whether you did it.

4. CameraCubit (presentation/camera/)
- State (Equatable), as a single state class with a status enum or a sealed hierarchy (your call, justify briefly), covering: initialising, ready, permissionDenied, permissionPermanentlyDenied, noCameraAvailable, cameraInUse or unavailable (hardware failure), error with a retryable flag, capturing, plus: current lens direction, available presets, current zoom and range, flash mode, focus indicator, isCapturing, and a short-lived one-off message.
- Methods: initialise(), requestPermission(), openAppSettings(), switchLens(), selectPreset(preset), onPinchStart/onPinchUpdate/onPinchEnd, setZoomFromSlider(value), onTapToFocus(localPosition, previewSize), cycleFlash(), capture(), retry(), and a lifecycle pair pause()/resume().
- Capture: ignore taps while a capture is in progress; take the picture, call AddCapturedImage (which copies it into the app documents directory), then delete the temp file; on success update the batch image count through BatchCubit; on StorageFailure or low storage show a clear message and keep the camera running. Add a minimum gap between captures to avoid double triggers.
- Lifecycle: release the camera when the app goes to background (AppLifecycleState.inactive or paused) and re-initialise on resume, using a WidgetsBindingObserver wired in the presentation layer. Make sure rapid pause/resume cycles and disposal during an in-flight initialisation never throw or leak the controller.
- Permissions: use permission_handler for the camera permission. Handle first request, denied (explain and offer retry), permanently denied (offer to open app settings), and the user returning from settings with permission granted (re-check on resume and initialise automatically). Do not request any permission that is not needed.
- Hardware and runtime failures to handle explicitly with typed states and messages (no raw exception text shown to users): no cameras found, camera already in use by another app, camera disconnected or runtime error while previewing, initialisation timeout, controller disposed unexpectedly, capture failure, flash not supported. Offer retry where it makes sense, with one automatic re-initialisation attempt for transient errors before showing the error state.
- Cancel subscriptions and dispose the controller in close(), and guard against emitting after close.

5. Wiring and temporary screen
- Register CameraService and CameraCubit in get_it (factory scope for the cubit so each screen visit gets a fresh instance, with the service disposing its controller).
- Update the temporary CameraPreviewScreen to: show the live preview, pinch and tap gestures, a slider, preset buttons, lens switch, flash button, capture button, the current batch image count, and a button that navigates to the Upload Manager. Plain styling is fine. It must display every error and permission state with the right action button.

6. Tests (flutter_test, bloc_test, mocktail with a FakeCameraService)
- ZoomPresets: single back camera with min 1.0 and max 8.0 gives 1x and 2x only; min 0.6 adds 0.5x; two back cameras adds 0.5x with a camera switch; max below 2.0 omits 2x.
- Zoom math: clamping, pinch scaling, slider mapping round trip, preset snapping.
- Tap-to-focus coordinate conversion, including letterboxed previews and taps outside the preview.
- CameraCubit: initialise success; permission denied then granted; permanently denied offers settings; no camera; initialisation failure triggers one retry then error; switchLens resets zoom; capture success increments the batch count and deletes the temp file; capture ignored while capturing; storage failure shows the message and the camera stays ready; focus indicator appears then clears after the duration (use fake async); pause releases the controller and resume re-initialises; close during initialisation does not throw.

7. Verification
- Run flutter analyze (must be clean), flutter test and flutter build apk --debug. Fix failures properly, do not weaken tests.
- Finish with a summary: API versions used, the presets heuristic and its limits, the orientation approach, assumptions, and a manual device test checklist: (1) deny permission, then allow; (2) deny permanently, open settings, return; (3) pinch, slider and preset buttons stay in sync; (4) 0.5x appears or is hidden correctly on this device; (5) tap-to-focus indicator position is correct in portrait and when the preview is letterboxed; (6) switch lens front and back; (7) background and resume the app mid-preview; (8) capture rapidly and confirm the batch count and the files saved under the app documents directory; (9) fill the device storage or simulate a storage failure if possible.

Rules: no secrets in code; no microphone permission; handle every failure explicitly instead of swallowing exceptions; do not log file paths outside debug builds; keep functions small; ask me before adding any dependency.
```

## 5. Real UI for the camera and Upload Manager screens

```text
Continue on the existing "snapsync" Flutter project. Domain, data, sync and camera logic are done and tested. In this step, build the real UI for CameraPreviewScreen and UploadManagerScreen to match the attached reference mockups, replacing the temporary screens. Do not change domain, data, sync or camera logic. If the UI needs something the cubits do not expose, tell me first and make the smallest possible change.

Before writing code, review the existing cubits and their states (CameraCubit, BatchCubit, SyncCubit), the theme, routes and DI, and reuse them.

1. CameraPreviewScreen (match the left mockup)
- Full-screen live preview, correctly scaled with the right aspect ratio (cover or contain, your call, but tap-to-focus must still map correctly using the existing conversion function). Dark system UI, status bar overlay handled.
- Top row: round translucent close (X) button on the left; flash toggle (cycles modes, icon reflects the current mode) and a second small icon button on the right (use it for a grid overlay toggle, rule-of-thirds lines drawn with a CustomPainter, and say so). Hide the flash button if the camera does not support flash.
- Vertical zoom slider on the right edge: translucent track, a thumb, the current zoom label at the top (for example "3x") and "1x" at the bottom as in the mockup; bound to the cubit's slider methods and in sync with pinch and preset buttons.
- Row of small round zoom preset buttons above the shutter row (render the cubit's ZoomPresets list only; the selected preset is highlighted white with the label such as "1x"; unavailable presets do not appear). Show the live zoom value on the selected button while the user pinches.
- Pinch-to-zoom over the preview via GestureDetector or Listener, plus tap-to-focus: an animated square or ring indicator at the tap point (scale-in, brief hold, fade-out) using the cubit's focusIndicator state; a different look for the locked or failed phase. The indicator must sit exactly at the tap position.
- Bottom area: a rounded thumbnail of the most recent captured image on the left with a blue count badge (for example 12) showing the open batch's image count (hidden or empty-state when zero); a large white circular shutter button centre with a press animation and a disabled or busy state while capturing; a lens-flip button on the right. Tapping the thumbnail opens a batch review bottom sheet (see section 3).
- Wide blue "UPLOAD BATCH (n)" button at the very bottom, disabled when the batch is empty. Tapping it submits the batch (BatchCubit.submitBatch), shows a short confirmation, and navigates to the Upload Manager.
- A brief white flash or shutter animation on capture, and a light haptic if available without new dependencies (HapticFeedback from services).
- Error and permission states from CameraCubit rendered full-screen over a dark background with an icon, a plain-language message and the right action button: request permission, open settings, retry, or go to Upload Manager. No raw exception text.
- Respect the camera lifecycle already wired; do not duplicate it in widgets.

2. UploadManagerScreen (match the right mockup)
- Dark navy theme, an app bar with the title "Upload Manager", a back button, and on the right a status pill driven by link quality: green "STABLE LINK", amber "UNSTABLE", red "OFFLINE". Add a small overflow menu with the "Mock network" tools described in section 4.
- Summary card: uppercase caption "BATCH SYNC PROGRESS", the percentage on the right, a thick rounded linear progress bar, and a line such as "2.4 MB / 3.2 MB Uploaded" (human-readable sizes via one helper with tests) plus a "PAUSE ALL" text button that switches to "RESUME ALL" when paused. Overall progress comes from SyncCubit state, bytes based.
- Section header "PENDING UPLOADS (n)" with the count of items not yet uploaded.
- List (ListView.builder with stable keys, separated cards) of upload items. Each card: thumbnail (decode at reduced size using ResizeImage or cacheWidth so large photos do not exhaust memory; show a placeholder if the file is missing), file name or generated label, size, and a status line with colour and icon per status:
  - waitingForConnection: amber "WAITING FOR CONNECTION"
  - retrying: amber "RETRYING... (ATTEMPT 2/3)" with a small next-retry hint if available
  - uploading: blue progress bar with the percentage and, if cheaply computable, the transfer speed
  - queued: neutral "QUEUED"
  - failed: red "FAILED" with a Retry button and a Remove option
  - uploaded: dimmed card with a green "SYNCED" label (and a relative time such as "2m ago")
  Group or order items: uploading first, then retrying and waiting, queued, failed, then synced. Swipe to remove (with confirmation or undo snackbar) for items that are not currently uploading.
- Empty state when there is nothing queued: icon, short text, and the "START NEW UPLOAD BATCH" action.
- Bottom pinned blue "START NEW UPLOAD BATCH" button returning to the camera. 
- Pull-to-refresh calls repository refresh via the cubit. Also call refresh on app resume using the existing observer pattern, and keep the light timer while visible.
- Animate status changes and progress smoothly (AnimatedSwitcher, TweenAnimationBuilder) without rebuilding the entire list on every progress tick: use BlocSelector or per-item widgets so only the changing card rebuilds.
- Snackbars for one-off messages from SyncCubit (for example "Upload resumed" or "Back online, syncing").

3. Batch review bottom sheet
- Opens from the camera thumbnail. A grid of the open batch's images with the image count, delete-per-image with a confirm, and a "Discard batch" action with confirmation. Close button. Large batches must scroll smoothly (GridView.builder, reduced-size decoding).

4. Mock network tools (needed so reviewers can see the failure and recovery behaviour in the release APK, because no real API exists)
- A bottom sheet reachable from the Upload Manager overflow menu titled "Mock network (assessment demo)" with a clearly labelled selector bound to MockUploadConfig modes: Always succeed, Offline (no internet), Low bandwidth, Server error, Flaky. Changing the mode updates the config immediately and shows what it simulates in one line each.
- It must be obviously labelled as a demo control, unobtrusive, and available in release builds. Do not hide it behind kDebugMode. Document in a code comment that it exists because the assessment provides no API.

5. Design system and quality
- All colours, text styles, spacing and shapes come from the theme (extend with semantic colour roles for success, warning, danger, info and the surface levels). No hardcoded hex values inside widgets. Match the mockup's visual language: dark navy surfaces, blue primary, rounded cards, uppercase small caption labels with letter spacing, green STABLE LINK pill.
- Split widgets into small files under presentation/**/widgets/ (for example zoom_slider.dart, zoom_preset_buttons.dart, focus_indicator.dart, shutter_button.dart, batch_thumbnail.dart, upload_item_card.dart, sync_summary_card.dart, link_status_pill.dart). Screens are thin and wire cubits via BlocProvider and BlocBuilder or BlocSelector; the content widgets are stateless where possible and take plain data plus callbacks so they can be tested and previewed.
- No business logic in widgets. No setState for anything the cubits own, except purely visual animation controllers.
- Accessibility: semantic labels for every icon button, the shutter button, zoom controls (announce zoom level), status pills and progress (announce percentage); minimum 48 dp touch targets; status never conveyed by colour alone (always an icon or text too); text scaling up to 200 percent must not overflow (use Flexible, ellipsis and wrapping deliberately).
- Handle small screens, tall screens, landscape (camera controls reposition or the screen locks to portrait; choose one and say which), and notches or system bars via SafeArea.
- Use const constructors where possible. No unnecessary rebuilds of the camera preview widget on zoom or focus state changes (isolate it with RepaintBoundary and selectors).

6. Tests (flutter_test with bloc_test and mocktail; fake cubit states)
- Widget tests: upload_item_card renders each status correctly (text, icon, progress, retry button only for failed); sync_summary_card shows percentage and size text and toggles PAUSE ALL and RESUME ALL; link_status_pill for each quality; zoom_preset_buttons renders only provided presets and highlights the selected one; UPLOAD BATCH button is disabled at zero and enabled otherwise and shows the count; error and permission screens show the right action buttons and call the right cubit methods; Mock network sheet changes the config mode; empty state appears when the queue is empty.
- Unit tests for the size formatter and the relative-time formatter.
- A test that the focus indicator is positioned at the tapped coordinates.
- Add golden tests only for two or three stable widgets if it is cheap; otherwise skip and say so.

7. Verification
- Run flutter analyze (must be clean), flutter test and flutter build apk --debug. Fix failures properly, do not weaken tests.
- Finish with a summary: files created, any cubit changes you had to make, assumptions, and a list of what needs on-device visual comparison against the mockups.

Rules: no secrets or URLs in code; no new dependencies without asking me first (use built-in Flutter widgets and CustomPainter); do not log file paths outside debug builds; keep functions and widgets small.
```
