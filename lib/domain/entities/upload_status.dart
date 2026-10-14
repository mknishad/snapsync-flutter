/// Where an image is in the upload lifecycle.
enum UploadStatus {
  /// Captured and stored locally, not yet attempted.
  queued,

  /// An attempt failed or was skipped because there is no stable connection.
  waitingForConnection,

  /// An upload is in flight.
  uploading,

  /// A previous attempt failed and another is scheduled.
  retrying,

  /// The server accepted the image.
  uploaded,

  /// Retries are exhausted.
  failed,
}
