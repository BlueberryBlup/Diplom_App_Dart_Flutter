
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:image_picker/image_picker.dart';

class LocalStorageService {
  final ImagePicker _picker = ImagePicker();

  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  //получение фото из галереи
  Future<File?> pickImageFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 800,
        maxHeight: 800,
      );
      if (image != null) {
        return File(image.path);
      }
    } catch (e) {}
    return null;
  }

  //фото с камеры
  Future<File?> pickImageFromCamera() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
        maxWidth: 800,
        maxHeight: 800,
      );
      if (image != null) {
        return File(image.path);
      }
    } catch (e) {}
    return null;
  }

  //сохранение фото
  Future<String?> savePhoto(File imageFile) async {
    try {
      final localPath = await _localPath;
      final fileName = 'defect_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final File localFile = File('$localPath/$fileName');

      await imageFile.copy(localFile.path);

      return localFile.path;
    } catch (e) {
      return null;
    }
  }

  //получение фото
  Future<File?> getPhoto(String? path) async {
    if (path == null || path.isEmpty) return null;

    try {
      final file = File(path);
      if (await file.exists()) {
        return file;
      }
    } catch (e) {}
    return null;
  }

  //удаление фото
  Future<void> deletePhoto(String? path) async {
    if (path == null || path.isEmpty) return;

    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {}
  }
}
