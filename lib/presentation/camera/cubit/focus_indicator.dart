import 'dart:ui';

import 'package:equatable/equatable.dart';

enum FocusPhase {
  /// The focus request was sent.
  focusing,

  /// The camera accepted the focus and exposure point. The camera API does not
  /// say when focus has actually settled, so this means "request accepted".
  done,

  /// Focus and exposure are locked (long press).
  locked,

  /// The camera rejected the request.
  failed,
}

/// The ring drawn where the user tapped.
class FocusIndicator extends Equatable {
  const FocusIndicator({
    required this.id,
    required this.position,
    required this.phase,
  });

  /// Increases with every tap, so a new tap replaces the previous indicator and
  /// a late result for an old tap can be recognised and ignored.
  final int id;

  /// In the coordinates of the widget that received the tap.
  final Offset position;
  final FocusPhase phase;

  FocusIndicator withPhase(FocusPhase newPhase) =>
      FocusIndicator(id: id, position: position, phase: newPhase);

  @override
  List<Object?> get props => [id, position, phase];
}
