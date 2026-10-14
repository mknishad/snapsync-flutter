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
