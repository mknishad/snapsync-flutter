// Sketch of the real reachability probe. Commented out on purpose: no endpoint
// is available. To enable it, supply a lightweight health-check URL through
// configuration (never hard-code or commit one), uncomment, and register it
// instead of MockReachabilityProbe in core/di/data_module.dart.
//
// import 'dart:async';
// import 'dart:io';
//
// import 'package:snapsync/domain/entities/probe_result.dart';
// import 'package:snapsync/domain/repositories/reachability_probe.dart';
//
// class RealReachabilityProbe implements ReachabilityProbe {
//   RealReachabilityProbe(this._healthCheckUri);
//
//   /// Injected from configuration.
//   final Uri _healthCheckUri;
//
//   @override
//   Future<ProbeResult> probe() async {
//     final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
//     final stopwatch = Stopwatch()..start();
//     try {
//       // A HEAD request keeps the probe tiny.
//       final request = await client.headUrl(_healthCheckUri);
//       final response = await request.close().timeout(const Duration(seconds: 5));
//       await response.drain<void>();
//       final ok = response.statusCode >= 200 && response.statusCode < 400;
//       return ok
//           ? ProbeResult.reachable(stopwatch.elapsed)
//           : const ProbeResult.unreachable();
//     } on SocketException {
//       return const ProbeResult.unreachable();
//     } on TimeoutException {
//       return const ProbeResult.unreachable();
//     } on HttpException {
//       return const ProbeResult.unreachable();
//     } finally {
//       client.close(force: true);
//     }
//   }
// }
