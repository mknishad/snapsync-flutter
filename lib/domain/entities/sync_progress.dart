import 'package:equatable/equatable.dart';

/// Progress of the upload currently running, for the foreground UI.
class SyncProgress extends Equatable {
  const SyncProgress({
    required this.imageId,
    required this.fraction,
    required this.totalBytes,
  });

  final String imageId;

  /// 0.0 to 1.0.
  final double fraction;
  final int totalBytes;

  int get bytesUploaded => (fraction * totalBytes).round();

  @override
  List<Object?> get props => [imageId, fraction, totalBytes];
}
