import 'package:equatable/equatable.dart';

enum SyncPassOutcome {
  /// Every due image was attempted.
  completed,

  /// The user paused uploading.
  pausedByUser,

  /// The link was not stable at the start, went offline during the pass, or an
  /// upload reported no internet.
  interruptedByConnectivity,

  /// The platform stopped the task (for example its network constraint was no
  /// longer met) and the engine released its claims.
  cancelled,
}

/// Summary of one `SyncEngine.runPass`.
class SyncPassResult extends Equatable {
  const SyncPassResult({
    required this.outcome,
    this.uploaded = 0,
    this.failed = 0,
    this.retrying = 0,
    this.waitingForConnection = 0,
    this.skippedClaimedByOther = 0,
    this.remaining = 0,
    this.nextRetryAt,
  });

  final SyncPassOutcome outcome;

  /// Counts of images this pass moved into each state.
  final int uploaded;
  final int failed;
  final int retrying;
  final int waitingForConnection;

  /// Images another engine claimed before this one.
  final int skippedClaimedByOther;

  /// Images of submitted batches still unfinished when the pass ended.
  final int remaining;

  /// When the soonest scheduled retry is due, if any.
  final DateTime? nextRetryAt;

  /// True when more work is waiting that a later pass should pick up.
  bool get hasWorkRemaining => remaining > 0;

  @override
  List<Object?> get props => [
    outcome,
    uploaded,
    failed,
    retrying,
    waitingForConnection,
    skippedClaimedByOther,
    remaining,
    nextRetryAt,
  ];
}
