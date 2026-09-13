// services/local_objects_service.dart
import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';

class LocalObjectsService {
  //загрузка фото
  Future<File?> getPhoto(String locationId) async {
    try {
      final assetPath = 'assets/locations/$locationId.png';

      final byteData = await rootBundle.load(assetPath);

      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/$locationId.png');
      await tempFile.writeAsBytes(byteData.buffer.asUint8List());

      return tempFile;
    } catch (e) {
      return null;
    }
  }

  //есть ли фото
  Future<bool> hasPhoto(String locationId) async {
    try {
      await rootBundle.load('assets/locations/$locationId.png');
      return true;
    } catch (e) {
      return false;
    }
  }
}
