class ContentFilterService {
  ContentFilterService._();

  // Common objectionable, abusive, sexually explicit, and harmful keywords in Vietnamese and English
  static final Set<String> _prohibitedKeywords = {
    // English objectionable / abuse / profanity
    'fuck',
    'shit',
    'bitch',
    'asshole',
    'bastard',
    'dick',
    'pussy',
    'cunt',
    'whore',
    'slut',
    'nigger',
    'nigga',
    'faggot',
    'kill yourself',
    'die bitch',
    'porn',
    'xxx',
    'sex video',
    'nude',
    'naked',

    // Vietnamese objectionable / vulgar / harassment terms
    'đụ',
    'đụ má',
    'đụ mẹ',
    'đm',
    'dcm',
    'đcm',
    'vcl',
    'vcc',
    'vl',
    'lồn',
    'cặc',
    'buồi',
    'đĩ',
    'chó đẻ',
    'óc chó',
    'con mẹ mày',
    'thằng chó',
    'chết đi',
    'khiêu dâm',
    'lộ clip',
    'gái gọi',
    'chat sex',
    'mua dâm',
  };

  /// Checks whether a given string contains objectionable or abusive terms.
  static bool isObjectionable(String? text) {
    if (text == null || text.trim().isEmpty) return false;
    final normalized = _normalizeText(text);

    for (final word in _prohibitedKeywords) {
      if (word.contains(' ')) {
        if (normalized.contains(word)) return true;
      } else {
        final regex = RegExp(
          r'(^|\s|[^\w\s])' + RegExp.escape(word) + r'($|\s|[^\w\s])',
          caseSensitive: false,
        );
        if (regex.hasMatch(normalized)) return true;
      }
    }
    return false;
  }

  /// Normalizes Vietnamese diacritics and symbols for robust detection.
  static String _normalizeText(String input) {
    var text = input.toLowerCase();
    text = text.replaceAll('@', 'a').replaceAll('0', 'o').replaceAll('1', 'i');
    return text;
  }
}
