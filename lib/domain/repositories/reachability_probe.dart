import 'package:snapsync/domain/entities/probe_result.dart';

/// A lightweight check that the internet (not just a network interface) is
/// reachable. Never throws: no answer is `ProbeResult.unreachable()`.
abstract interface class ReachabilityProbe {
  Future<ProbeResult> probe();
}
