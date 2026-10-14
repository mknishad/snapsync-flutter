import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:snapsync/domain/repositories/connectivity_monitor.dart';

class ConnectivityMonitorImpl implements ConnectivityMonitor {
  const ConnectivityMonitorImpl(this.connectivity);

  final Connectivity connectivity;

  @override
  Stream<bool> get onConnectivityChanged {
    // TODO: map connectivity.onConnectivityChanged to a bool.
    throw UnimplementedError('TODO: onConnectivityChanged');
  }

  @override
  Future<bool> get isConnected {
    // TODO: check connectivity.checkConnectivity().
    throw UnimplementedError('TODO: isConnected');
  }

  @override
  Future<bool> hasStableConnection() {
    // TODO: run the probe described by the stable-connection constants. No
    // real endpoint exists, so the probe target must stay configurable/mocked.
    throw UnimplementedError('TODO: hasStableConnection');
  }
}
