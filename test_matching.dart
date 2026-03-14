import 'dart:io';
import 'package:supabase/supabase.dart';

// TEST SCRIPT: UI kullanmadan gönderi eşleşmesini arka planda test etme.
// Not: Bu scripti terminalden 'dart test_matching.dart' şeklinde çalıştırabilirsiniz.

// 🚨 BURAYA SUPABASE VE OPENAI BİLGİLERİNİ GİRİN
const String supabaseUrl = 'https://vxrvudcafkgqusjrawme.supabase.co';
const String supabaseAnonKey = 'sb_publishable_tSqnWtXnUhEog3MIx5ajRw_PZeTlwuG';
const String openAIApiKey =
    'REDACTED_OPENAI_API_KEY'; // Test için geçici

void main() async {
  print('=====================================');
  print('🤖 KINNECT AI MATCHING TEST SCRIPT 🤖');
  print('=====================================\n');

  final client = SupabaseClient(supabaseUrl, supabaseAnonKey);

  // 1. Örnek Test Kullanıcıları oluşturulduğunu varsayıyoruz
  // veya mevcut kullanıcılardan birini test için seçeceğiz.
  print('[1] Test Kullanıcıları Aranıyor...');

  // En son iki post atan kişiyi bulalım
  final postsRes = await client.from('posts').select('user_id').limit(2);
  if (postsRes.isEmpty) {
    print('❌ Veritabanında hiç post yok! Lütfen uygulamadan 2 post atın.');
    exit(1);
  }

  // 2. OpenAI Embedding Testi
  print('\n[2] OpenAI Text Embedding API Testi...');
  final queryText =
      "Boğazda çay içmek ve martıları izlemek bana çok huzur veriyor...";
  print('Sorgu Metni: "$queryText"');

  List<double> queryVector = [];
  try {
    // Burada aslında Edge Function'ı çağırıp sadece RPC'yi test edeceğiz.
    // Ancak basitlik olsun diye Edge Function'a doğrudan POST atıp vektörü simüle edebiliriz.
    // ŞİMDİLİK: Supabase RPC (Stored Procedure) tarafını doğrudan Dart ile test edelim.
    // Varsayalım Edge Function veritabanına kayıtı başarıyla attı. Olan vektörler üzerinden test:
    print('Test: Vektör Arama Fonksiyonu Çalıştırılıyor (RPC)');

    // DB'deki ilk postun embedding'ini alalım (eğer Edge Function çalıştıysa dolmuş olmalı)
    final embeddingRes = await client
        .from('post_embeddings')
        .select('embedding')
        .limit(1)
        .maybeSingle();

    if (embeddingRes == null || embeddingRes['embedding'] == null) {
      print('⚠️ Henüz kaydedilmiş bir embedding (vektör) bulunamadı.');
      print(
          'Edge Function tetiklenmemiş veya OpenAI API düzgün çalışmamış olabilir.');
      print(
          'Lütfen uygulamadan fotoğraf yükleyip post paylaşın, Edge Function DB webhook u tetiklenecek.');
    } else {
      // pgvector returns embedding as a string like "[0.1,0.2,...]"
      final embeddingRaw = embeddingRes['embedding'];
      if (embeddingRaw is String) {
        final cleaned = embeddingRaw.replaceAll('[', '').replaceAll(']', '');
        queryVector =
            cleaned.split(',').map((s) => double.parse(s.trim())).toList();
      } else {
        queryVector = List<double>.from(embeddingRaw);
      }
      print(
          '✅ Örnek bir vektör başarıyla çekildi. Boyutu: ${queryVector.length}');

      print('\n[3] Yapay Zeka Eşleştirme Algoritması Testi (Gemini - 768 Dim)');
      final matchRes = await client.rpc('match_users_by_post', params: {
        'query_embedding': queryVector, // Gemini 768-dim vektör
        'match_threshold':
            0.60, // Gemini için eşik değerini biraz düşürebiliriz test için
        'match_count': 5,
        'exclude_user_id': postsRes.first['user_id']
      });

      print('Eşleşen Sayısı: ${(matchRes as List).length}');
      for (var match in matchRes) {
        print(
            '❤️ UYUM! Skor: %${(match['similarity'] * 100).toStringAsFixed(1)} | Kullanıcı: ${match['user_id']}');
        print('  📝 Gönderi Özeti: ${match['content_summary'] ?? "Özet yok"}');
      }
    }
  } catch (e) {
    print('HATA: $e');
  }

  print('\n=====================================');
}
