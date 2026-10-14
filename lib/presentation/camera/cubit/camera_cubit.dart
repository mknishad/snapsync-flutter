import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:snapsync/presentation/camera/cubit/camera_state.dart';

class CameraCubit extends Cubit<CameraState> {
  CameraCubit() : super(const CameraState());

  // TODO: permission request, camera controller lifecycle, lens discovery,
  // zoom, tap-to-focus, capture into the current batch.
}
