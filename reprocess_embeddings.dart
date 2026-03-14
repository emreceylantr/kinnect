import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';

void main() async {
  // Supabase bağlantısı
  // Not: Gerçek projede .env veya Supabase.initialize kullanılır.
  // Burada doğrudan client üzerinden manuel bağlanıyoruz (script olduğu için).

  final supabase = SupabaseClient(
    'https://vxrvudcafkgqusjrawme.supabase.co',
    'REDACTED_SUPABASE_SERVICE_ROLE_KEY', // Service Role Key from existing setup
  );

  print('Eskiden kalan "sadece yazı" olan analizleri güncelliyorum...');

  // 1. Tüm postları çek
  final posts =
      await supabase.from('posts').select('id, user_id, content, image_url');

  print('Toplam ${posts.length} post bulundu.');

  for (var post in posts) {
    print('İşleniyor: ${post['id']} - ${post['content']}');

    try {
      // Edge Function'ı manuel tetikle
      final response = await supabase.functions.invoke(
        'generate-post-embedding',
        body: {'record': post},
      );

      if (response.status == 200) {
        print('✅ Başarılı: ${response.data['aiSummary']}');
      } else {
        print('❌ Hata (${response.status}): ${response.data}');
      }
    } catch (e) {
      print('🔥 İstisna: $e');
    }

    // API limitlerine takılmamak için kısa bir bekleme
    await Future.delayed(Duration(milliseconds: 500));
  }

  print('İşlem tamamlandı! Artık eşleşmeler çok daha kaliteli olacak.');
  exit(0);
}
