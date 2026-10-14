import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:snapsync/presentation/batch/cubit/batch_state.dart';

class BatchCubit extends Cubit<BatchState> {
  BatchCubit() : super(const BatchState());

  // TODO: start a batch, add captured images, close the batch for upload.
}
