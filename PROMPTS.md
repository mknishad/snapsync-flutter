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
