// Sketch of the real upload API. Everything is commented out on purpose: no
// endpoint is available and the `http` package is not a dependency. To enable
// it, add `http`, replace the placeholder URL, uncomment, and register
// RealUploadApi instead of MockUploadApi in core/di/data_module.dart.
//
// import 'dart:async';
// import 'dart:io';
//
// import 'package:http/http.dart' as http;
// import 'package:snapsync/core/error/failure.dart';
// import 'package:snapsync/domain/entities/captured_image.dart';
// import 'package:snapsync/domain/repositories/upload_api.dart';
//
// class RealUploadApi implements UploadApi {
//   RealUploadApi(this._client);
//
//   final http.Client _client;
//
//   // Placeholder only. Supply the real endpoint via configuration, never
//   // hard-code it, and never commit credentials.
//   static final Uri _endpoint = Uri.parse('<UPLOAD_ENDPOINT>');
//
//   @override
//   Future<void> uploadImage(CapturedImage image) async {
//     try {
//       final request = http.MultipartRequest('POST', _endpoint)
//         ..fields['batchId'] = image.batchId
//         ..fields['imageId'] = image.id
//         ..files.add(await http.MultipartFile.fromPath('file', image.filePath));
//
//       final response = await _client
//           .send(request)
//           .timeout(const Duration(seconds: 30));
//
//       if (response.statusCode < 200 || response.statusCode >= 300) {
//         throw ServerFailure(
//           'Upload rejected',
//           statusCode: response.statusCode,
//         );
//       }
//     } on SocketException {
//       throw const NetworkUnavailableFailure('No internet connection');
//     } on TimeoutException {
//       throw const UnstableConnectionFailure('Upload timed out');
//     }
//   }
// }
