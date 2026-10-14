/// How usable the network is for uploading.
enum LinkQuality {
  /// No network interface is up.
  offline,

  /// An interface is up but the link is not yet proven (still inside the
  /// debounce period) or the reachability probe failed or was too slow.
  unstable,

  /// The interface has been up without a break for the debounce period and the
  /// reachability probe succeeded quickly.
  stable,
}
