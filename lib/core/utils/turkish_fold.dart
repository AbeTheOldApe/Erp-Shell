/// Folds [input] for Turkish-aware search and comparison.
///
/// Case, the `İ/ı/I/i` distinction and diacritics are ignored, so
/// `turkishFold('İŞ EMRİ') == turkishFold('iş emri') == 'is emri'`.
/// Use this instead of `toLowerCase()` for any text matching.
String turkishFold(String input) {
  final buffer = StringBuffer();
  for (final rune in input.runes) {
    final mapped = _foldMap[rune];
    if (mapped != null) {
      buffer.write(mapped);
    } else if (rune >= 0x41 && rune <= 0x5A) {
      buffer.writeCharCode(rune + 0x20);
    } else {
      buffer.writeCharCode(rune);
    }
  }
  return buffer.toString();
}

/// True when [text] contains [query] after folding both.
bool turkishContains(String text, String query) =>
    turkishFold(text).contains(turkishFold(query.trim()));

const Map<int, String> _foldMap = {
  // Turkish specific
  0x0130: 'i', // İ
  0x0131: 'i', // ı
  0x015E: 's', 0x015F: 's', // Ş ş
  0x011E: 'g', 0x011F: 'g', // Ğ ğ
  0x00DC: 'u', 0x00FC: 'u', // Ü ü
  0x00D6: 'o', 0x00F6: 'o', // Ö ö
  0x00C7: 'c', 0x00E7: 'c', // Ç ç
  // Circumflex (Turkish loan words) and common Latin accents
  0x00C2: 'a', 0x00E2: 'a', // Â â
  0x00CE: 'i', 0x00EE: 'i', // Î î
  0x00DB: 'u', 0x00FB: 'u', // Û û
  0x00C0: 'a', 0x00E0: 'a', 0x00C1: 'a', 0x00E1: 'a',
  0x00C4: 'a', 0x00E4: 'a',
  0x00C8: 'e', 0x00E8: 'e', 0x00C9: 'e', 0x00E9: 'e',
  0x00CA: 'e', 0x00EA: 'e', 0x00CB: 'e', 0x00EB: 'e',
  0x00CC: 'i', 0x00EC: 'i', 0x00CD: 'i', 0x00ED: 'i',
  0x00CF: 'i', 0x00EF: 'i',
  0x00D2: 'o', 0x00F2: 'o', 0x00D3: 'o', 0x00F3: 'o',
  0x00D4: 'o', 0x00F4: 'o',
  0x00D9: 'u', 0x00F9: 'u', 0x00DA: 'u', 0x00FA: 'u',
  0x00D1: 'n', 0x00F1: 'n',
};
