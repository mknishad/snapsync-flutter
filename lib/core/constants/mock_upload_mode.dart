/// Behaviour of the mock upload API.
enum MockUploadMode {
  alwaysSuccess,
  alwaysNoInternet,
  alwaysLowBandwidth,
  alwaysServerError,

  /// Succeeds with a configurable probability, otherwise fails with a randomly
  /// chosen failure.
  flaky,
}
