import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:snapsync/app/app_routes.dart';
import 'package:snapsync/core/di/injection.dart';
import 'package:snapsync/presentation/camera/camera_preview_screen.dart';
import 'package:snapsync/presentation/camera/cubit/camera_cubit.dart';
import 'package:snapsync/presentation/upload_manager/upload_manager_screen.dart';

abstract final class AppRouter {
  static Route<void> onGenerateRoute(RouteSettings settings) {
    return switch (settings.name) {
      AppRoutes.camera => MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => BlocProvider<CameraCubit>(
          create: (_) => getIt<CameraCubit>()..initialise(),
          child: const CameraPreviewScreen(),
        ),
      ),
      // The Upload Manager is the root screen and the fallback for unknown
      // routes.
      _ => MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => const UploadManagerScreen(),
      ),
    };
  }
}
