import 'package:get_it/get_it.dart';
import 'package:snapsync/core/di/data_module.dart';
import 'package:snapsync/core/di/domain_module.dart';
import 'package:snapsync/core/di/presentation_module.dart';

final GetIt getIt = GetIt.instance;

/// Registers everything for the UI isolate. Safe to call more than once.
Future<void> configureDependencies() async {
  registerDataModule(getIt);
  registerDomainModule(getIt);
  registerPresentationModule(getIt);
}

/// Registers only what background work needs (no cubits or widgets).
///
/// The background isolate does not share [getIt] state with the UI isolate, so
/// the workmanager callback must call this itself. Workmanager can also run
/// one-off tasks on the main engine, so it must be safe to call repeatedly.
Future<void> configureBackgroundDependencies() async {
  registerDataModule(getIt);
  registerDomainModule(getIt);
}
