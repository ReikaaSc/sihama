import 'package:csv/csv.dart';

import 'package:sihama/core/constants/app_assets.dart';
import 'package:sihama/shared/models/sihama_models.dart';

class DiagnosisDataset {
  const DiagnosisDataset._();

  static const assetPath = AppAssets.diagnosisDataset;

  static const _requiredHeaders = [
    'slug',
    'nama',
    'kategori',
    'deskripsi_singkat',
    'bagian_tanaman_terdampak',
    'fase_pertumbuhan',
    'gejala_awal',
    'penyebab_umum',
    'referensi',
  ];

  static List<DiagnosisReference> parse(String source) {
    final normalized = source
        .replaceFirst('\uFEFF', '')
        .replaceAll('\r\n', '\n');
    final rows = Csv(autoDetect: false).decode(normalized);
    if (rows.isEmpty) throw const FormatException('Dataset CSV is empty.');

    final headers = rows.first.map((value) => value.toString().trim()).toList();
    final columnIndexes = <String, int>{};
    for (final header in _requiredHeaders) {
      final index = headers.indexOf(header);
      if (index < 0) {
        throw FormatException('Dataset CSV is missing the "$header" column.');
      }
      columnIndexes[header] = index;
    }

    final references = <DiagnosisReference>[];
    final slugs = <String>{};
    for (var rowNumber = 1; rowNumber < rows.length; rowNumber++) {
      final row = rows[rowNumber];
      if (row.every((value) => value.toString().trim().isEmpty)) continue;
      if (row.length != headers.length) {
        throw FormatException(
          'Dataset CSV row ${rowNumber + 1} has ${row.length} columns; '
          'expected ${headers.length}.',
        );
      }

      String value(String header) =>
          row[columnIndexes[header]!].toString().trim();

      final slug = value('slug');
      if (slug.isEmpty) {
        throw FormatException('Dataset CSV row ${rowNumber + 1} has no slug.');
      }
      if (!slugs.add(slug)) {
        throw FormatException('Dataset CSV contains duplicate slug "$slug".');
      }

      references.add(
        DiagnosisReference(
          slug: slug,
          name: value('nama'),
          category: value('kategori'),
          shortDescription: value('deskripsi_singkat'),
          affectedPlantParts: value('bagian_tanaman_terdampak'),
          growthPhase: value('fase_pertumbuhan'),
          firstSymptoms: value('gejala_awal'),
          typicalCauses: value('penyebab_umum'),
          moreInfo: value('referensi'),
        ),
      );
    }
    return references;
  }
}
