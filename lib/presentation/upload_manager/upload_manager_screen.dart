import 'package:flutter/material.dart';
import 'package:snapsync/app/app_routes.dart';

class UploadManagerScreen extends StatelessWidget {
  const UploadManagerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // TODO: replace the placeholder body with the Upload Manager UI (see
    // reference screenshot): header, progress, pending uploads list.
    return Scaffold(
      body: const Center(child: Text('UploadManagerScreen')),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: FilledButton(
          onPressed: () => Navigator.of(context).pushNamed(AppRoutes.camera),
          child: const Text('START NEW UPLOAD BATCH'),
        ),
      ),
    );
  }
}
