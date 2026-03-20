import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

const supabaseUrl    = 'https://vxrvudcafkgqusjrawme.supabase.co';
const serviceKey     = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZ4cnZ1ZGNhZmtncXVzanJhd21lIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzYzNzQ2OCwiZXhwIjoyMDc5MjEzNDY4fQ.TrQDIKlh8e_AT9ld36TjjXKqSdt61g5zSo1czSn1V_M';

Future<void> main() async {
  print('Tüm kullanıcıların profilleri Claude ile analiz ediliyor...\n');

  // Tüm farklı user_id'leri çek
  final postsResp = await http.get(
    Uri.parse('$supabaseUrl/rest/v1/posts?select=user_id&order=created_at.desc'),
    headers: {
      'apikey': serviceKey,
      'Authorization': 'Bearer $serviceKey',
    },
  );

  final posts = jsonDecode(postsResp.body) as List;
  final userIds = posts.map((p) => p['user_id'] as String).toSet().toList();
  print('${userIds.length} kullanıcı bulundu.\n');

  int success = 0;
  int failed  = 0;

  for (var i = 0; i < userIds.length; i++) {
    final userId = userIds[i];
    print('[${i + 1}/${userIds.length}] Analiz ediliyor: $userId');

    try {
      final resp = await http.post(
        Uri.parse('$supabaseUrl/functions/v1/analyze-user-profile'),
        headers: {
          'Authorization': 'Bearer $serviceKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'user_id': userId}),
      ).timeout(const Duration(seconds: 120));

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map;
        final summary = (data['summary'] as String?) ?? '';
        print('  ✅ ${data['username']} — ${data['postCount']} post');
        if (summary.length > 80) print('  📋 ${summary.substring(0, 80)}...');
        else if (summary.isNotEmpty) print('  📋 $summary');
        final interests = (data['interests'] as List?)?.take(5).join(', ') ?? '';
        if (interests.isNotEmpty) print('  🎯 $interests');
        success++;
      } else {
        final body = resp.body;
        print('  ⚠️  ${resp.statusCode}: ${body.length > 200 ? body.substring(0, 200) : body}');
        failed++;
      }
    } catch (e) {
      print('  ❌ Hata: $e');
      failed++;
    }

    print('');
    await Future.delayed(const Duration(seconds: 2));
  }

  print('═══════════════════════════════════');
  print('Tamamlandı! ✅ $success başarılı  ❌ $failed başarısız');
  exit(0);
}
