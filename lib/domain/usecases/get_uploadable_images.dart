import 'package:snapsync/core/utils/clock.dart';
import 'package:snapsync/domain/entities/captured_image.dart';
import 'package:snapsync/domain/repositories/batch_repository.dart';

class GetUploadableImages {
  const GetUploadableImages(this.repository, {required this.now});

  final BatchRepository repository;
  final Clock now;

  Future<List<CapturedImage>> call() => repository.getUploadable(now());
}
