import 'package:flutter_test/flutter_test.dart';
import 'package:snapsync/app/app.dart';
import 'package:snapsync/core/di/injection.dart';

void main() {
  setUp(() async {
    await getIt.reset();
    await configureDependencies();
  });

  tearDown(() => getIt.reset());

  testWidgets('app starts on the Upload Manager placeholder screen', (
    tester,
  ) async {
    await tester.pumpWidget(const SnapSyncApp());

    expect(find.text('UploadManagerScreen'), findsOneWidget);
    expect(find.text('CameraPreviewScreen'), findsNothing);
  });

  testWidgets('start new upload batch opens the camera screen', (
    tester,
  ) async {
    await tester.pumpWidget(const SnapSyncApp());

    await tester.tap(find.text('START NEW UPLOAD BATCH'));
    await tester.pumpAndSettle();

    expect(find.text('CameraPreviewScreen'), findsOneWidget);
  });
}
