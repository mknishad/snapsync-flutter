import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:snapsync/app/app_router.dart';
import 'package:snapsync/app/app_routes.dart';
import 'package:snapsync/core/constants/app_constants.dart';
import 'package:snapsync/core/di/injection.dart';
import 'package:snapsync/core/theme/app_theme.dart';
import 'package:snapsync/presentation/batch/cubit/batch_cubit.dart';
import 'package:snapsync/presentation/upload_manager/cubit/sync_cubit.dart';

class SnapSyncApp extends StatelessWidget {
  const SnapSyncApp({super.key});

  @override
  Widget build(BuildContext context) {
    // BatchCubit and SyncCubit are shared by both screens, so they live here.
    // They are created eagerly: the sync cubit must watch connectivity and run
    // passes from app start, not from the first time a widget reads it.
    return MultiBlocProvider(
      providers: [
        BlocProvider<BatchCubit>(
          lazy: false,
          create: (_) => getIt<BatchCubit>()..start(),
        ),
        BlocProvider<SyncCubit>(
          lazy: false,
          create: (_) => getIt<SyncCubit>()..start(),
        ),
      ],
      child: MaterialApp(
        title: AppConstants.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        themeMode: ThemeMode.dark,
        initialRoute: AppRoutes.uploadManager,
        onGenerateRoute: AppRouter.onGenerateRoute,
      ),
    );
  }
}
