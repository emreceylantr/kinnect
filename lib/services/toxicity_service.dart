class ToxicityService {
  // Kötü kelimeler listesi - Sadece açıkça toxic olanlar (False positive riski düşük)
  static final Set<String> _toxicKeywords = {
    // Küfürler
    'siktir', 'sikeyim', 'amk', 'amq', 'amına', 'amını', 'götünü', 'göt',
    'bok', 'koduğumun',

    // Hakaretler
    'aptal', 'salak', 'mal', 'ahmak', 'dangalak', 'gerizekalı', 'budala',
    'ezik', 'yıkık', 'pislik', 'berbat',

    // Cinsel içerikli
    'orospu', 'kaltak', 'ibne', 'penis', 'emmek', 'becer', 'horoz', 'fahişe',
    'kahpe', 'piç',

    // İngilizce küfürler
    'fuck', 'fucker', 'shit', 'dick', 'cunt', 'suck', 'wanker', 'fagot',

    // Nefret söylemi
    'nefret', 'lanet', 'kahretsin',

    // Saldırgan ifadeler
    'defol', 'kes', 'kapa çeneni',
  };

  /// Verilen metni toxicity kontrolünden geçirir
  /// Basit kelime eşleştirme yaklaşımı - daha güvenilir
  bool checkToxicity(String text) {
    final lowerText = text.toLowerCase().trim();

    // Kötü kelime kontrolü
    for (final keyword in _toxicKeywords) {
      if (lowerText.contains(keyword)) {
        print('⛔ Toxic kelime bulundu: "$keyword" in "$text"');
        return true;
      }
    }

    print('✅ Yorum temiz: "$text"');
    return false;
  }
}
