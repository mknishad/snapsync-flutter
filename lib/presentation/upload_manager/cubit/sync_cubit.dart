import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:snapsync/presentation/upload_manager/cubit/sync_state.dart';

class SyncCubit extends Cubit<SyncState> {
  SyncCubit() : super(const SyncState());

  // TODO: watch pending batches, start/pause sync, retry, react to
  // connectivity changes.
}
