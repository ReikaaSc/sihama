part of 'package:sihama/features/sihama/presentation/screens/sihama_shell.dart';

String _formatPrice(int price) {
  final digits = price.toString();
  final grouped = StringBuffer();
  for (var index = 0; index < digits.length; index++) {
    if (index > 0 && (digits.length - index) % 3 == 0) grouped.write('.');
    grouped.write(digits[index]);
  }
  return 'Rp$grouped';
}

IconData _productIcon(String category) {
  if (category == 'Fungisida') return Icons.spa_outlined;
  if (category == 'Bakterisida') return Icons.biotech_outlined;
  if (category == 'Insektisida') return Icons.pest_control_outlined;
  return Icons.grass_rounded;
}

List<MarketProduct> _recommendedProducts(
  CropReport report,
  List<MarketProduct> products,
) {
  final storedNames = RegExp(r'Obat yang disarankan:\s*([^\n]+)')
      .firstMatch(report.recommendation ?? '')
      ?.group(1)
      ?.split(',')
      .map((name) => name.trim())
      .where((name) => name.isNotEmpty)
      .toSet();
  if (storedNames != null && storedNames.isNotEmpty) {
    return products
        .where((product) => storedNames.contains(product.name))
        .toList();
  }
  return products.where((product) => product.stock > 0).take(2).toList();
}

String _initials(String name) {
  final words = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty);
  return words.take(2).map((word) => word[0].toUpperCase()).join();
}
