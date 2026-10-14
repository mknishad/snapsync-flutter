import 'package:equatable/equatable.dart';

class ProbeResult extends Equatable {
  const ProbeResult.reachable(Duration this.latency) : reachable = true;

  const ProbeResult.unreachable() : reachable = false, latency = null;

  final bool reachable;

  /// Round-trip time of the probe, when it got an answer.
  final Duration? latency;

  /// True when the probe answered within [maxLatency].
  bool isFast(Duration maxLatency) =>
      reachable && latency != null && latency! <= maxLatency;

  @override
  List<Object?> get props => [reachable, latency];
}
