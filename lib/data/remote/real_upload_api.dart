// Sketch of the real upload API. Everything is commented out on purpose: no
// endpoint is available and the `http` package is not a dependency. To enable
// it: add `http`, supply the endpoint through configuration (never hard-code
// it), uncomment, and register RealUploadApi instead of MockUploadApi in
// core/di/data_module.dart.
//
// import 'dart:async';
// import 'dart:io';
//
// import 'package:http/http.dart' as http;
// import 'package:snapsync/core/error/failure.dart';
// import 'package:snapsync/domain/entities/captured_image.dart';
// import 'package:snapsync/domain/entities/upload_result.dart';
// import 'package:snapsync/domain/repositories/upload_api.dart';
//
// class RealUploadApi implements UploadApi {
//   RealUploadApi(this._client, this._endpoint);
//
//   final http.Client _client;
//
//   /// Injected from configuration, e.g. a build-time define. Never commit a
//   /// real URL, token or key. Authentication, when needed, should come from an
//   /// injected provider and be added as a request header.
//   final Uri _endpoint;
//
//   static const Duration _timeout = Duration(seconds: 30);
//
//   @override
//   Future<UploadResult> upload(
//     CapturedImage image, {
//     void Function(double progress)? onProgress,
//   }) async {
//     try {
//       final request = http.MultipartRequest('POST', _endpoint)
//         // The server must treat a repeated key as the same upload, so a retry
//         // after a lost response never creates a duplicate.
//         ..headers['Idempotency-Key'] = image.id
//         ..fields['batchId'] = image.batchId
//         ..fields['imageId'] = image.id
//         ..files.add(await http.MultipartFile.fromPath('file', image.filePath));
//
//       // package:http does not report upload progress. For real progress, send
//       // the body through a stream wrapper that counts bytes and calls
//       // onProgress(sent / total).
//       final streamed = await _client.send(request).timeout(_timeout);
//       final response = await http.Response.fromStream(streamed);
//
//       if (response.statusCode >= 200 && response.statusCode < 300) {
//         onProgress?.call(1);
//         // Parse the server reference from response.body according to the API
//         // contract.
//         return UploadSuccess(serverReference: image.id);
//       }
//       return UploadFailed(
//         ServerFailure('Upload rejected', code: response.statusCode),
//       );
//     } on SocketException {
//       return const UploadFailed(NoInternetFailure('No internet connection'));
//     } on TimeoutException {
//       return const UploadFailed(LowBandwidthFailure('Upload timed out'));
//     } on FileSystemException {
//       return const UploadFailed(FileMissingFailure('Image file is missing'));
//     } on http.ClientException catch (e) {
//       return UploadFailed(UnknownFailure('Upload failed: ${e.message}'));
//     }
//   }
// }
