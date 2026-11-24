import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

enum PackageScanMode { name, expiryDate }

class ScannedDateCandidate {
  final DateTime date;
  final String rawText;
  final bool isExplicitExpiry;

  const ScannedDateCandidate({
    required this.date,
    required this.rawText,
    this.isExplicitExpiry = false,
  });
}

class PackageScannerService {
  static final PackageScannerService instance = PackageScannerService._init();
  PackageScannerService._init();

  // Từ khóa nhiễu thường gặp trên bao bì (không phải tên sản phẩm)
  static const List<String> _noiseKeywords = [
    'nsx',
    'hsd',
    'han su dung',
    'ngay san xuat',
    'so lo',
    'lo sx',
    'thanh phan',
    'cong dung',
    'huong dan',
    'bao quan',
    'khoi luong',
    'the tich',
    'san xuat tai',
    'xuat xu',
    'dia chi',
    'luu y',
    'chong chi dinh',
    'lieu dung',
    'cach dung',
    'doc ky',
    'giu xa tam tay',
    'ma vach',
    'mfg',
    'mfd',
    'exp',
    'expiry',
    'best before',
    'use by',
    'batch',
    'lot',
    'net wt',
    'ingredients',
    'directions',
    'storage',
    'warning',
    'caution',
    'made in',
    'distributed by',
    'keep out of reach',
    'nutrition facts',
    'supplement facts',
  ];

  static const Map<String, int> _monthNames = {
    'jan': 1,
    'feb': 2,
    'mar': 3,
    'apr': 4,
    'may': 5,
    'jun': 6,
    'jul': 7,
    'aug': 8,
    'sep': 9,
    'oct': 10,
    'nov': 11,
    'dec': 12,
  };

  static final RegExp _expiryKeywordRegex = RegExp(
    r'\b(hsd|exp|expiry|bb|bbe|best before|use by|han su dung|ed)\b',
  );

  static final RegExp _mfgKeywordRegex = RegExp(
    r'\b(nsx|mfg|mfd|prod|pd|ngay san xuat)\b',
  );

  // --- LUỒNG 1: CHUYÊN QUÉT TÊN SẢN PHẨM ---
  Future<List<String>> scanProductName(String imagePath) async {
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final recognizedText = await textRecognizer.processImage(inputImage);
      return _extractNameCandidates(recognizedText);
    } catch (_) {
      return const [];
    } finally {
      await textRecognizer.close();
    }
  }

  // --- LUỒNG 2: CHUYÊN QUÉT NGÀY HẾT HẠN ---
  Future<List<ScannedDateCandidate>> scanExpiryDate(String imagePath) async {
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final recognizedText = await textRecognizer.processImage(inputImage);
      return _extractDateCandidates(recognizedText);
    } catch (_) {
      return const [];
    } finally {
      await textRecognizer.close();
    }
  }

  // ===========================================================================
  // PHẦN 1: XỬ LÝ TÊN SẢN PHẨM
  // ===========================================================================
  List<String> _extractNameCandidates(RecognizedText recognizedText) {
    final List<({String text, double height})> candidates = [];

    for (final block in recognizedText.blocks) {
      final validLines = <({String text, double height})>[];

      for (final line in block.lines) {
        final cleaned = _cleanLineText(line.text);
        if (_isValidNameLine(cleaned)) {
          validLines.add((text: cleaned, height: line.boundingBox.height));
        }
      }

      if (validLines.isEmpty) continue;

      if (validLines.length >= 2) {
        final first = validLines[0];
        final second = validLines[1];
        final ratio = second.height / (first.height == 0 ? 1 : first.height);
        final combined = '${first.text} ${second.text}';
        if (ratio >= 0.7 && combined.length <= 55) {
          candidates.add((
            text: combined,
            height: (first.height + second.height) / 2 + 1,
          ));
        }
      }

      candidates.addAll(validLines);
    }

    candidates.sort((a, b) => b.height.compareTo(a.height));

    final List<String> result = [];
    final Set<String> seen = {};

    for (final item in candidates) {
      final key = item.text.toLowerCase();
      if (seen.add(key)) {
        result.add(item.text);
        if (result.length >= 3) break;
      }
    }

    return result;
  }

  bool _isValidNameLine(String text) {
    if (text.length < 3 || text.length > 55) return false;

    final letterCount = RegExp(r'[a-zA-ZÀ-ỹ]').allMatches(text).length;
    if (letterCount < 2) return false;

    if (RegExp(
      r'^\d+([.,]\d+)?\s*(ml|l|g|kg|mg|mcg|viên|gói|hộp|túi|pcs|tabs|caps)\.?$',
      caseSensitive: false,
    ).hasMatch(text)) {
      return false;
    }

    if (RegExp(r'^[\d\s./:-]+$').hasMatch(text)) return false;

    final normalized = _removeVietnameseDiacritics(text.toLowerCase());
    for (final noise in _noiseKeywords) {
      if (normalized.startsWith(noise) || normalized.contains('$noise:')) {
        return false;
      }
    }

    return true;
  }

  // ===========================================================================
  // PHẦN 2: XỬ LÝ NGÀY HẾT HẠN CHUYÊN SÂU
  // ===========================================================================
  List<ScannedDateCandidate> _extractDateCandidates(
    RecognizedText recognizedText,
  ) {
    final List<ScannedDateCandidate> found = [];
    final List<DateTime> manufacturingDates = [];

    final allLines = <String>[
      for (final block in recognizedText.blocks)
        for (final line in block.lines) _cleanLineText(line.text),
    ];

    // Theo dõi nhãn HSD/NSX đứng một mình ở dòng ngay phía trên
    String? pendingLabelFromPrevLine;

    for (final line in allLines) {
      if (line.isEmpty) continue;
      final normalized = _removeVietnameseDiacritics(line.toLowerCase());

      final bool hasExpiryKw = _expiryKeywordRegex.hasMatch(normalized);
      final bool hasMfgKw = _mfgKeywordRegex.hasMatch(normalized);

      final bool isExpiryLine =
          hasExpiryKw || (!hasMfgKw && pendingLabelFromPrevLine == 'expiry');
      final bool isMfgLine = !isExpiryLine &&
          (hasMfgKw || pendingLabelFromPrevLine == 'mfg');

      final bool allowCompact =
          hasExpiryKw || hasMfgKw || pendingLabelFromPrevLine != null || line.length <= 14;

      final extracted = _parseDatesFromLine(line, allowCompact: allowCompact);

      if (extracted.isEmpty) {
        // Lưu lại nhãn nếu dòng này chỉ có chữ "HSD:" / "EXP" và ngày nằm ở dòng kế tiếp
        if (hasExpiryKw) {
          pendingLabelFromPrevLine = 'expiry';
        } else if (hasMfgKw) {
          pendingLabelFromPrevLine = 'mfg';
        } else {
          pendingLabelFromPrevLine = null;
        }
        continue;
      }

      pendingLabelFromPrevLine = null;

      for (final item in extracted) {
        if (isMfgLine) {
          manufacturingDates.add(item.date);
        } else {
          found.add(
            ScannedDateCandidate(
              date: item.date,
              rawText: item.rawText,
              isExplicitExpiry: isExpiryLine,
            ),
          );
        }
      }
    }

    if (found.isEmpty && manufacturingDates.isNotEmpty) {
      for (final d in manufacturingDates) {
        found.add(ScannedDateCandidate(date: d, rawText: ''));
      }
    }

    final Map<String, ScannedDateCandidate> uniqueByDate = {};
    for (final item in found) {
      final key = '${item.date.year}-${item.date.month}-${item.date.day}';
      final existing = uniqueByDate[key];
      if (existing == null ||
          (!existing.isExplicitExpiry && item.isExplicitExpiry)) {
        uniqueByDate[key] = item;
      }
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final sorted = uniqueByDate.values.toList()
      ..sort((a, b) {
        if (a.isExplicitExpiry != b.isExplicitExpiry) {
          return a.isExplicitExpiry ? -1 : 1;
        }
        final aFuture = !a.date.isBefore(today);
        final bFuture = !b.date.isBefore(today);
        if (aFuture != bFuture) {
          return aFuture ? -1 : 1;
        }
        return b.date.compareTo(a.date);
      });

    return sorted.take(3).toList();
  }

  List<({DateTime date, String rawText})> _parseDatesFromLine(
    String line, {
    required bool allowCompact,
  }) {
    final List<({DateTime date, String rawText})> results = [];
    String working = line;

    // 1. Tên tháng tiếng Anh trước khi sửa ký tự OCR (VD: "15 MAR 2027", "15AUG26", "MAR 2027")
    final textMonthRegex = RegExp(
      r'\b(?:(\d{1,2})\s*)?(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*[\s./-]*(20[2-5]\d|\d{2})\b',
      caseSensitive: false,
    );
    for (final m in textMonthRegex.allMatches(working)) {
      final monthKey = m.group(2)!.toLowerCase().substring(0, 3);
      final month = _monthNames[monthKey];
      if (month == null) continue;

      final rawYear = int.parse(m.group(3)!);
      final year = rawYear < 100 ? 2000 + rawYear : rawYear;
      final dayStr = m.group(1);
      final valid = dayStr != null
          ? _buildValidDate(year, month, int.parse(dayStr))
          : _lastDayOfMonth(year, month);
      if (valid != null) {
        results.add((date: valid, rawText: m.group(0)!));
        working = _maskMatch(working, m);
      }
    }

    // Chuẩn hóa lỗi OCR chữ/số (O->0, I/l->1) trên phần văn bản còn lại
    working = _normalizeOcrDateDigits(working);

    // 2. Dạng YYYY/MM/DD (hỗ trợ dấu /, ., -, hoặc khoảng trắng)
    final ymdRegex =
        RegExp(r'\b(20[2-5]\d)[/.\- ](\d{1,2})[/.\- ](\d{1,2})\b');
    for (final m in ymdRegex.allMatches(working)) {
      final year = int.parse(m.group(1)!);
      final month = int.parse(m.group(2)!);
      final day = int.parse(m.group(3)!);
      final valid = _buildValidDate(year, month, day);
      if (valid != null) {
        results.add((date: valid, rawText: m.group(0)!));
        working = _maskMatch(working, m);
      }
    }

    // 3. Dạng DD/MM/YYYY hoặc DD/MM/YY (tự đảo MM/DD nếu định dạng Mỹ như 12/31/2026)
    final dmyRegex =
        RegExp(r'\b(\d{1,2})[/.\- ](\d{1,2})[/.\- ](20[2-5]\d|\d{2})\b');
    for (final m in dmyRegex.allMatches(working)) {
      final first = int.parse(m.group(1)!);
      final second = int.parse(m.group(2)!);
      final rawYear = int.parse(m.group(3)!);
      final year = rawYear < 100 ? 2000 + rawYear : rawYear;

      DateTime? valid = _buildValidDate(year, second, first);
      if (valid == null && first <= 12 && second <= 31) {
        valid = _buildValidDate(year, first, second);
      }
      if (valid != null) {
        results.add((date: valid, rawText: m.group(0)!));
        working = _maskMatch(working, m);
      }
    }

    // 4. Dạng chỉ có Tháng/Năm: MM/YYYY hoặc MM/YY (chỉ quét trên phần chưa khớp phía trên)
    final myRegex = RegExp(r'\b(\d{1,2})[/.\- ](20[2-5]\d|\d{2})\b');
    for (final m in myRegex.allMatches(working)) {
      final month = int.parse(m.group(1)!);
      final rawYear = int.parse(m.group(2)!);
      final year = rawYear < 100 ? 2000 + rawYear : rawYear;
      final valid = _lastDayOfMonth(year, month);
      if (valid != null) {
        results.add((date: valid, rawText: m.group(0)!));
        working = _maskMatch(working, m);
      }
    }

    // 5. Dạng viết liền không dấu ngăn cách (VD: 20270501, 31122026, 311226)
    if (allowCompact) {
      final compact8Regex = RegExp(r'\b(\d{8})\b');
      for (final m in compact8Regex.allMatches(working)) {
        final s = m.group(1)!;
        DateTime? valid;
        if (s.startsWith('20')) {
          valid = _buildValidDate(
            int.parse(s.substring(0, 4)),
            int.parse(s.substring(4, 6)),
            int.parse(s.substring(6, 8)),
          );
        } else {
          valid = _buildValidDate(
            int.parse(s.substring(4, 8)),
            int.parse(s.substring(2, 4)),
            int.parse(s.substring(0, 2)),
          );
        }
        if (valid != null) {
          results.add((date: valid, rawText: s));
          working = _maskMatch(working, m);
        }
      }

      final compact6Regex = RegExp(r'\b(\d{6})\b');
      for (final m in compact6Regex.allMatches(working)) {
        final s = m.group(1)!;
        final valid = _buildValidDate(
          2000 + int.parse(s.substring(4, 6)),
          int.parse(s.substring(2, 4)),
          int.parse(s.substring(0, 2)),
        );
        if (valid != null) {
          results.add((date: valid, rawText: s));
          working = _maskMatch(working, m);
        }
      }
    }

    return results;
  }

  String _normalizeOcrDateDigits(String input) {
    return input.replaceAllMapped(
      RegExp(r'[A-Za-z0-9/.\-]+'),
      (match) {
        final token = match.group(0)!;
        if (!RegExp(r'\d').hasMatch(token)) return token;
        if (RegExp(r'[A-Za-z]{2,}').hasMatch(token)) return token;
        return token
            .replaceAll(RegExp(r'[Oo]'), '0')
            .replaceAll(RegExp(r'[Il]'), '1');
      },
    );
  }

  String _maskMatch(String source, RegExpMatch match) {
    return source.replaceRange(
      match.start,
      match.end,
      ' ' * (match.end - match.start),
    );
  }

  DateTime? _buildValidDate(int year, int month, int day) {
    if (year < 2020 || year > 2050) return null;
    if (month < 1 || month > 12) return null;
    if (day < 1 || day > 31) return null;

    final candidate = DateTime(year, month, day);
    if (candidate.year != year ||
        candidate.month != month ||
        candidate.day != day) {
      return null;
    }
    return candidate;
  }

  DateTime? _lastDayOfMonth(int year, int month) {
    if (year < 2020 || year > 2050) return null;
    if (month < 1 || month > 12) return null;
    return DateTime(year, month + 1, 0);
  }

  String _cleanLineText(String raw) {
    return raw.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  String _removeVietnameseDiacritics(String str) {
    const withDia =
        'àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ';
    const withoutDia =
        'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyyd';
    var result = str;
    for (int i = 0; i < withDia.length; i++) {
      result = result.replaceAll(withDia[i], withoutDia[i]);
    }
    return result;
  }
}