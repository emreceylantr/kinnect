#!/bin/bash

# Configuration
PROJECT_URL="https://vxrvudcafkgqusjrawme.supabase.co"
SERVICE_ROLE_KEY="sb_secret_SYJPpKVVlo1BKoViBcCpZQ_Gs1yphk_"

echo "🚀 Eskiden kalan postları yeni AI sistemiyle analiz ediyorum..."

# 1. Tüm postları çek
POSTS_JSON=$(curl -s -X GET "$PROJECT_URL/rest/v1/posts?select=id,user_id,content,image_url" \
-H "apikey: $SERVICE_ROLE_KEY" \
-H "Authorization: Bearer $SERVICE_ROLE_KEY")

# 2. Her post için Edge Function'ı tetikle
echo "$POSTS_JSON" | jq -c '.[]' | while read -r post; do
    POST_ID=$(echo "$post" | jq -r '.id')
    echo "🔄 İşleniyor: $POST_ID"
    
    # Edge Function çağrısı
    RESPONSE=$(curl -s -X POST "$PROJECT_URL/functions/v1/generate-post-embedding" \
    -H "Authorization: Bearer $SERVICE_ROLE_KEY" \
    -H "Content-Type: application/json" \
    -d "{\"record\": $post}")
    
    echo "✅ Sonuç: $RESPONSE"
    
    # API'yi yormamak için kısa bekleme
    sleep 0.5
done

echo "🏁 İşlem tamamlandı! Tüm postlar derinlemesine analiz edildi."
