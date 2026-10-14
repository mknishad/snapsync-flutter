import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:snapsync/core/constants/app_constants.dart';
import 'package:snapsync/core/error/failure.dart';

/// A file copied into app storage.
class StoredImageFile {
  const StoredImageFile({required this.path, required this.sizeBytes});

  final String path;
  final int sizeBytes;
}

/// Keeps captured files in app-private storage (no storage permission needed):
/// `<app documents>/batches/<batchId>/<imageId>.<ext>`.
///
/// The camera leaves its output in the cache directory, which the OS may clear.
/// Copying it here keeps queued images alive until they are uploaded.
///
/// Every I/O problem is reported as [StorageFailure] or [FileMissingFailure];
/// no raw [FileSystemException] escapes.
class ImageFileStorage {
  ImageFileStorage({Future<Directory> Function()? baseDirectory})
    : _baseDirectory = baseDirectory ?? getApplicationDocumentsDirectory;

  final Future<Directory> Function() _baseDirectory;

  /// Copies [sourcePath] into the batch directory and returns the new path and
  /// size. The source file is left in place for the OS to clear.
  Future<StoredImageFile> store({
    required String sourcePath,
    required String batchId,
    required String imageId,
  }) async {
    _checkSegment(batchId);
    _checkSegment(imageId);
    final source = File(sourcePath);
    try {
      if (!await source.exists()) {
        throw FileMissingFailure('Captured file not found: $sourcePath');
      }
      final extension = p.extension(sourcePath);
      final directory = await _batchDirectory(batchId);
      await directory.create(recursive: true);
      final target = File(
        p.join(
          directory.path,
          '$imageId${extension.isEmpty ? '.jpg' : extension}',
        ),
      );
      await source.copy(target.path);
      return StoredImageFile(
        path: target.path,
        sizeBytes: await target.length(),
      );
    } on FileSystemException catch (e) {
      throw StorageFailure('Could not store the image: ${e.message}');
    }
  }

  /// Size of an existing file.
  Future<int> sizeOf(String path) async {
    try {
      final file = File(path);
      if (!await file.exists()) {
        throw FileMissingFailure('File not found: $path');
      }
      return await file.length();
    } on FileSystemException catch (e) {
      throw StorageFailure('Could not read the file size: ${e.message}');
    }
  }

  Future<bool> exists(String path) async {
    try {
      return await File(path).exists();
    } on FileSystemException catch (e) {
      throw StorageFailure('Could not check the file: ${e.message}');
    }
  }

  /// Deletes one file. Does nothing if it is already gone.
  Future<void> deleteFile(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } on FileSystemException catch (e) {
      throw StorageFailure('Could not delete the file: ${e.message}');
    }
  }

  /// Deletes a batch's whole directory. Does nothing if it does not exist.
  Future<void> deleteBatchDirectory(String batchId) async {
    _checkSegment(batchId);
    try {
      final directory = await _batchDirectory(batchId);
      if (await directory.exists()) await directory.delete(recursive: true);
    } on FileSystemException catch (e) {
      throw StorageFailure('Could not delete the batch folder: ${e.message}');
    }
  }

  Future<Directory> _batchDirectory(String batchId) async {
    final base = await _baseDirectory();
    return Directory(
      p.join(base.path, AppConstants.imageDirectoryName, batchId),
    );
  }

  /// Ids come from the repository, but a path separator in one would let a
  /// file escape its folder, so refuse it.
  void _checkSegment(String value) {
    if (value.isEmpty || value != p.basename(value) || value.contains('..')) {
      throw StorageFailure('Invalid storage identifier: "$value"');
    }
  }
}
