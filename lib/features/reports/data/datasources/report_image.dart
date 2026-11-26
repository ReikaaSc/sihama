import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

/// Limits and helpers for validating report image uploads.
const maxReportImageBytes = 5 * 1024 * 1024;
const allowedReportImageExtensions = ['png', 'jpg', 'jpeg'];

class ReportImage {
  const ReportImage({required this.name, required this.bytes});

  final String name;
  final Uint8List bytes;
}

typedef ReportImagePicker = Future<ReportImage?> Function();

class ReportImagePickerException implements Exception {
  const ReportImagePickerException(this.message);

  final String message;

  @override
  String toString() => message;
}

Future<ReportImage?> pickReportImage() async {
  final files = await FilePicker.pickFiles(
    dialogTitle: 'Pilih foto tanaman',
    type: FileType.custom,
    allowedExtensions: allowedReportImageExtensions,
  );
  if (files.isEmpty) return null;
  final file = files.first;
  final size = await file.length();
  if (size != null && size > maxReportImageBytes) {
    throw const ReportImagePickerException('Ukuran foto maksimal 5 MB.');
  }
  return ReportImage(name: file.name, bytes: await file.readAsBytes());
}

String? validateReportImage(ReportImage image) {
  final extension = image.name.split('.').last.toLowerCase();
  if (!allowedReportImageExtensions.contains(extension)) {
    return 'Format foto harus PNG, JPG, atau JPEG.';
  }
  if (image.bytes.isEmpty) {
    return 'File gambar kosong atau tidak dapat dibaca.';
  }
  if (image.bytes.length > maxReportImageBytes) {
    return 'Ukuran foto maksimal 5 MB.';
  }

  final isPng =
      image.bytes.length >= 8 &&
      image.bytes[0] == 0x89 &&
      image.bytes[1] == 0x50 &&
      image.bytes[2] == 0x4E &&
      image.bytes[3] == 0x47 &&
      image.bytes[4] == 0x0D &&
      image.bytes[5] == 0x0A &&
      image.bytes[6] == 0x1A &&
      image.bytes[7] == 0x0A;
  final isJpeg =
      image.bytes.length >= 3 &&
      image.bytes[0] == 0xFF &&
      image.bytes[1] == 0xD8 &&
      image.bytes[2] == 0xFF;

  if ((extension == 'png' && !isPng) ||
      ((extension == 'jpg' || extension == 'jpeg') && !isJpeg)) {
    return 'Isi file tidak sesuai dengan format gambar yang dipilih.';
  }
  return null;
}
