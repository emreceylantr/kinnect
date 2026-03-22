import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

function formatPost(post: any): string {
  const parts: string[] = []
  if (post.content) parts.push(`"${post.content.slice(0, 80)}"`)
  if (post.spotify_artist_name) {
    parts.push(`[${post.spotify_artist_name}${post.spotify_track_name ? ` - ${post.spotify_track_name}` : ''}]`)
  }
  if (post.location) parts.push(`📍${post.location}`)
  if (post.image_urls?.length) parts.push('[fotoğraf]')
  return parts.join(' ')
}

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })

  try {
    const {
      user1_id,
      user2_id,
      user1_name,
      user2_name,
      user1_profile,
      user2_profile,
      user1_interests,
      user2_interests,
      match_reasons,
      language,
    } = await req.json()
    const isEn = language === 'en'

    const anthropicKey = Deno.env.get('ANTHROPIC_API_KEY')
    if (!anthropicKey) throw new Error('ANTHROPIC_API_KEY eksik')

    // Gerçek postları çek
    let user1PostsText = ''
    let user2PostsText = ''

    if (user1_id && user2_id) {
      const supabase = createClient(
        Deno.env.get('SUPABASE_URL')!,
        Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
      )

      const [u1Posts, u2Posts] = await Promise.all([
        supabase
          .from('posts')
          .select('content, spotify_track_name, spotify_artist_name, location, image_urls')
          .eq('user_id', user1_id)
          .order('created_at', { ascending: false })
          .limit(10),
        supabase
          .from('posts')
          .select('content, spotify_track_name, spotify_artist_name, location, image_urls')
          .eq('user_id', user2_id)
          .order('created_at', { ascending: false })
          .limit(10),
      ])

      const u1Formatted = (u1Posts.data || []).map(formatPost).filter(Boolean)
      const u2Formatted = (u2Posts.data || []).map(formatPost).filter(Boolean)

      if (u1Formatted.length > 0) user1PostsText = isEn ? `Recent posts: ${u1Formatted.slice(0, 6).join(' | ')}` : `Son paylaşımları: ${u1Formatted.slice(0, 6).join(' | ')}`
      if (u2Formatted.length > 0) user2PostsText = isEn ? `Recent posts: ${u2Formatted.slice(0, 6).join(' | ')}` : `Son paylaşımları: ${u2Formatted.slice(0, 6).join(' | ')}`
    }

    const reasonsText = match_reasons?.length > 0
      ? isEn
        ? `\nDetected common points: ${match_reasons.join(', ')}`
        : `\nTespit edilen ortak noktalar: ${match_reasons.join(', ')}`
      : ''

    const prompt = isEn
      ? `Two users' profiles and posts:

**${user1_name}:**
- Interests: ${(user1_interests || []).join(', ')}
- Profile: ${user1_profile || 'No info'}
${user1PostsText ? `- ${user1PostsText}` : ''}

**${user2_name}:**
- Interests: ${(user2_interests || []).join(', ')}
- Profile: ${user2_profile || 'No info'}
${user2PostsText ? `- ${user2PostsText}` : ''}
${reasonsText}

TASK: Write a short message to "${user1_name}" explaining why "${user2_name}" is a great match for them.

RULES:
- Address "${user1_name}" directly (use "you")
- Talk about "${user2_name}" — their interests, posts, and shared things
- Give concrete examples like "You both love X..." or "You share an interest in X..."
- 2-3 sentences, warm and genuine tone
- Do NOT use technical words like "AI", "algorithm", "embedding"
- Write only the message, nothing else`
      : `İki kullanıcının profilleri ve paylaşımları:

**${user1_name}:**
- İlgi alanları: ${(user1_interests || []).join(', ')}
- Profil: ${user1_profile || 'Bilgi yok'}
${user1PostsText ? `- ${user1PostsText}` : ''}

**${user2_name}:**
- İlgi alanları: ${(user2_interests || []).join(', ')}
- Profil: ${user2_profile || 'Bilgi yok'}
${user2PostsText ? `- ${user2PostsText}` : ''}
${reasonsText}

GÖREV: "${user1_name}" adlı kullanıcıya, neden "${user2_name}" ile iyi bir eşleşme olduğunu anlatan kısa bir mesaj yaz.

KURALLAR:
- Doğrudan "${user1_name}"e hitap et (sen diye)
- "${user2_name}" hakkında konuş — onun ilgi alanlarını, paylaşımlarını, ortaklıkları anlat
- "Sen X seversin, o da..." ya da "İkinizin de X ilgin var..." formatında somut örnekler ver
- 2-3 cümle, samimi ve sıcak bir dil
- "AI", "algoritma", "embedding" gibi teknik kelimeler kullanma
- Sadece mesajı yaz, başka bir şey ekleme`

    const resp = await fetch('https://api.anthropic.com/v1/messages', {
      method: 'POST',
      headers: {
        'x-api-key': anthropicKey,
        'anthropic-version': '2023-06-01',
        'content-type': 'application/json',
      },
      body: JSON.stringify({
        model: 'claude-haiku-4-5-20251001',
        max_tokens: 250,
        messages: [{ role: 'user', content: prompt }],
      }),
    })

    const data = await resp.json()
    const explanation = data.content?.[0]?.text?.trim()
      || (isEn ? `You and ${user2_name} have great things in common, worth meeting!` : `${user2_name} ile harika ortak noktalarınız var, tanışmaya değer!`)

    return new Response(JSON.stringify({ explanation }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200,
    })
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 500,
    })
  }
})
