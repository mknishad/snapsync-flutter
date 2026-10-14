enum FlashSetting {
  off,
  auto,
  always;

  /// The next setting when the user taps the flash button.
  FlashSetting get next => switch (this) {
    off => auto,
    auto => always,
    always => off,
  };
}
