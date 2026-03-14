import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase/supabase.dart';

// SCRIPT: Eski (halihazırda var olan) postları yapay zekaya taratıp vektörlerini oluşturma.

const String supabaseUrl = 'https://vxrvudcafkgqusjrawme.supabase.co';
const String supabaseServiceRoleKey =
    'sb_secret_SYJPpKVVlo1BKoViBcCpZQ_Gs1yphk_';

void main() async {
  print('=============================================');
  print('🔄 KINNECT ESKİ POSTLARI YAPAY ZEKAYA AKTARMA');
  print('=============================================\n');

  final client = SupabaseClient(supabaseUrl, supabaseServiceRoleKey);

  try {
    // 1. Tüm postları çek
    print('[1] Veritabanındaki tüm gönderiler aranıyor...');
    final postsRes =
        await client.from('posts').select('id, user_id, content, image_url');
    final posts = List<Map<String, dynamic>>.from(postsRes);

    print('Toplam ${posts.length} gönderi bulundu.\n');

    // 2. Halihazırda vektörü olanları çek
    final embeddingsRes =
        await client.from('post_embeddings').select('post_id');
    final List<String> processedPostIds =
        List<String>.from(embeddingsRes.map((e) => e['post_id'] as String));

    // 3. İşlenmemiş olanları filtrele
    final unprocessedPosts =
        posts.where((post) => !processedPostIds.contains(post['id'])).toList();

    if (unprocessedPosts.isEmpty) {
      print('✅ Harika! Tüm gönderilerin zaten yapay zeka analizi yapılmış.');
      exit(0);
    }

    print('[2] İşlem Bekleyen Gönderi Sayısı: ${unprocessedPosts.length}');
    print(
        '🕒 Yapay zeka analizleri başlatılıyor (Bu işlem api limitlerine takılmamak için biraz sürebilir)...\n');

    for (var i = 0; i < unprocessedPosts.length; i++) {
      final post = unprocessedPosts[i];
      print(
          '⏳ İşleniyor (${i + 1}/${unprocessedPosts.length}): Post ID ${post['id']}');

      // Edge Function'a doğrudan istek atıyoruz (Webhook'un yaptığı işi manuel yapıyoruz)
      final functionUrl =
          Uri.parse('$supabaseUrl/functions/v1/generate-post-embedding');

      // Not: Edge Function'da anon_key veya service_key kullanarak Bearer token yolluyoruz
      final response = await http.post(functionUrl,
          headers: {
            'Content-Type': 'application/json',
            'Authorization':
                'Bearer $supabaseServiceRoleKey' // Veya kendi giriş token'ın
          },
          body: jsonEncode({'record': post}));

      if (response.statusCode == 200) {
        print('   ✅ Başarılı: ${jsonDecode(response.body)['aiSummary']}');
      } else {
        print('   ❌ HATA Puanı: ${response.statusCode}');
        print('   Detay: ${response.body}');
      }

      // OpenAI API limitlerine (Rate Limit) takılmamak için 2 saniye bekle
      await Future.delayed(Duration(seconds: 2));
    }

    print(
        '\n🎉 Taramalar Bitti! Artık "dart test_matching.dart" komutunu çalıştırabilirsin. 🎉');
  } catch (e) {
    print('HATA: $e');
  }

  print('\n=============================================');
}
