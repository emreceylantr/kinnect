import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

// ─── Metin tabanlı sahne etiketi çıkarımı ────────────────────────────────────
function extractSceneTagsFromText(content: string): string[] {
  const keywordMap: Record<string, string> = {
    'kafe': 'kafe', 'kahve': 'kahve', 'coffee': 'kahve', 'espresso': 'kahve',
    'bar': 'bar', 'restoran': 'restoran', 'yemek': 'yemek', 'pizza': 'yemek',
    'doğa': 'doğa', 'dağ': 'dağ', 'sahil': 'sahil', 'plaj': 'plaj', 'deniz': 'deniz',
    'spor': 'spor', 'koşu': 'koşu', 'futbol': 'futbol', 'basketbol': 'spor salonu', 'gym': 'spor salonu',
    'konser': 'konser', 'festival': 'festival', 'müzik': 'müzik', 'gece kulübü': 'gece hayatı',
    'seyahat': 'seyahat', 'tatil': 'tatil', 'uçak': 'seyahat',
    'gece': 'gece', 'akşam': 'akşam',
    'arkadaş': 'arkadaşlar', 'grup': 'grup', 'beraber': 'arkadaşlar',
    'oyun': 'oyun', 'gaming': 'oyun', 'valorant': 'oyun', 'cs2': 'oyun',
    'sanat': 'sanat', 'sergi': 'sergi', 'müze': 'müze',
    'alışveriş': 'alışveriş', 'kitap': 'kitap', 'okuma': 'kitap',
  }

  const lower = content.toLowerCase()
  const tags = new Set<string>()
  for (const [keyword, tag] of Object.entries(keywordMap)) {
    if (lower.includes(keyword)) tags.add(tag)
  }
  return [...tags]
}

// ─── @mention çıkarımı ───────────────────────────────────────────────────────
function extractMentions(content: string): string[] {
  const matches = [...content.matchAll(/@(\w+)/g)]
  return [...new Set(matches.map(m => m[1]))]
}

// ─── Claude ile tek bir postu analiz et ───────────────────────────────────────
async function analyzePost(post: Record<string, unknown>, anthropicKey: string): Promise<{ text: string, scene_tags: string[] }> {
  const caption     = (post.content as string) || ""
  const imageUrl    = (post.image_url as string) || (
    Array.isArray(post.image_urls) && post.image_urls.length > 0 ? post.image_urls[0] as string : null
  )
  const location    = (post.location as string) || ""
  const musicTrack  = (post.spotify_track_name as string) || ""
  const musicArtist = (post.spotify_artist_name as string) || ""

  const videoFrameUrls: string[] = Array.isArray(post.video_frame_urls) && post.video_frame_urls.length > 0
    ? post.video_frame_urls as string[]
    : []

  const contextParts: string[] = []
  if (caption)     contextParts.push(`Yazı: "${caption}"`)
  if (location)    contextParts.push(`Konum: ${location}`)
  if (musicTrack)  contextParts.push(`Müzik: ${musicTrack}${musicArtist ? ' - ' + musicArtist : ''}`)
  const context = contextParts.join(" | ")

  // Build image content blocks — use video frames if available, else single image
  const imageBlocks: any[] = []
  if (videoFrameUrls.length > 0) {
    for (const frameUrl of videoFrameUrls.slice(0, 3)) {
      imageBlocks.push({ type: "image", source: { type: "url", url: frameUrl } })
    }
  } else if (imageUrl) {
    imageBlocks.push({ type: "image", source: { type: "url", url: imageUrl } })
  }

  if (imageBlocks.length === 0) {
    const scene_tags = extractSceneTagsFromText(caption)
    return { text: context || "", scene_tags }
  }

  const promptText = videoFrameUrls.length > 0
    ? `Bu sosyal medya gönderisini analiz et (video karelerinden oluşuyor).\n${context ? `Not: ${context}\n` : ""}Şu JSON formatında yanıt ver:\n{"analysis": "2-3 cümle Türkçe: kaç kişi var, sosyal bağlam, mekan, aktivite, duygu", "scene_tags": ["etiket1", "etiket2"]}\nscene_tags: 5-8 adet Türkçe kelime (mekan tipi, aktivite, atmosfer, sosyal durum, saat dilimi). Sadece JSON döndür.`
    : `Bu sosyal medya gönderisini analiz et.\n${context ? `Not: ${context}\n` : ""}Şu JSON formatında yanıt ver:\n{"analysis": "2-3 cümle Türkçe: kaç kişi var, sosyal bağlam, mekan, aktivite, duygu", "scene_tags": ["etiket1", "etiket2"]}\nscene_tags: 5-8 adet Türkçe kelime (mekan tipi, aktivite, atmosfer, sosyal durum, saat dilimi). Sadece JSON döndür.`

  try {
    const resp = await fetch("https://api.anthropic.com/v1/messages", {
      method: "POST",
      headers: {
        "x-api-key": anthropicKey,
        "anthropic-version": "2023-06-01",
        "content-type": "application/json",
      },
      body: JSON.stringify({
        model: "claude-haiku-4-5",
        max_tokens: 300,
        system: "Respond with valid JSON only.",
        messages: [{
          role: "user",
          content: [
            ...imageBlocks,
            {
              type: "text",
              text: promptText,
            },
          ],
        }],
      }),
    })
    const data = await resp.json()
    const rawText = data.content?.[0]?.text?.trim() || ""
    if (rawText) {
      try {
        const jsonMatch = rawText.match(/\{[\s\S]*\}/)
        if (jsonMatch) {
          const parsed = JSON.parse(jsonMatch[0])
          const analysis = parsed.analysis || ""
          const scene_tags: string[] = Array.isArray(parsed.scene_tags) ? parsed.scene_tags : []
          const text = analysis ? `${analysis}${context ? ' | ' + context : ''}` : context
          return { text, scene_tags }
        }
      } catch {
        // fall through to return context
      }
    }
    return { text: context, scene_tags: [] }
  } catch {
    return { text: context, scene_tags: [] }
  }
}

// ─── Tüm analizlerden kullanıcı profili sentezle ──────────────────────────────
async function synthesizeProfile(
  postAnalyses: string[],
  username: string,
  anthropicKey: string,
  quizContext?: string
): Promise<{ summary: string; interests: string[]; social_style: string; _debug?: string }> {
  const postsText = postAnalyses.filter(Boolean).slice(0, 25)
    .map((p, i) => `${i + 1}. ${p}`).join("\n")

  const quizSection = quizContext ? `\n\nKullanıcının kişilik anketi cevapları:\n${quizContext}` : ''

  try {
    const resp = await fetch("https://api.anthropic.com/v1/messages", {
      method: "POST",
      headers: {
        "x-api-key": anthropicKey,
        "anthropic-version": "2023-06-01",
        "content-type": "application/json",
      },
      body: JSON.stringify({
        model: "claude-sonnet-4-6",
        max_tokens: 1000,
        system: "You must respond with valid JSON only. No other text, no explanation.",
        messages: [{
          role: "user",
          content: `Analyze these social media posts and return a JSON object with exactly three fields:\n- "profile_summary": a 3-4 sentence personality and lifestyle description in Turkish\n- "interests": an array of 5-10 interest keywords in Turkish (e.g. ["müzik", "seyahat", "spor"])\n- "social_style": one of these values only: "yalnız" (usually alone in photos), "ikili" (usually with one person), "sosyal" (often in groups), "karma" (mixed)\n\nBase "social_style" on the people count and social context patterns across all posts.${quizSection}\n\nPosts:\n${postsText}\n\nRespond with only the JSON object, nothing else.`,
        }],
      }),
    })

    const rawBody = await resp.text()
    const data = JSON.parse(rawBody)

    if (data.error) {
      return { summary: "", interests: [], social_style: "", _debug: `API error: ${JSON.stringify(data.error)}` }
    }

    const text = data.content?.[0]?.text?.trim() || ""
    if (!text) {
      return { summary: "", interests: [], social_style: "", _debug: `Empty text. Full response: ${rawBody.substring(0, 500)}` }
    }

    // Extract JSON from response (sometimes wrapped in markdown code blocks)
    const jsonMatch = text.match(/\{[\s\S]*\}/)
    if (!jsonMatch) {
      return { summary: "", interests: [], social_style: "", _debug: `No JSON found in: ${text.substring(0, 300)}` }
    }

    const parsed = JSON.parse(jsonMatch[0])
    const summary = parsed.profile_summary || ""
    const interests: string[] = Array.isArray(parsed.interests) ? parsed.interests : []
    const social_style: string = parsed.social_style || ""

    return { summary, interests, social_style }
  } catch (e) {
    return { summary: "", interests: [], social_style: "", _debug: `Exception: ${e.message}` }
  }
}

// ─── Ana Handler ──────────────────────────────────────────────────────────────
serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { user_id, quiz_answers } = await req.json()
    if (!user_id) {
      return new Response(JSON.stringify({ error: 'user_id gerekli' }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 400,
      })
    }

    const supabaseUrl        = Deno.env.get('SUPABASE_URL') ?? ''
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    const anthropicKey       = Deno.env.get('ANTHROPIC_API_KEY') ?? ''
    if (!anthropicKey) throw new Error('ANTHROPIC_API_KEY eksik')

    const supabase = createClient(supabaseUrl, supabaseServiceKey)

    const { data: profileData } = await supabase
      .from('profiles').select('username, full_name').eq('id', user_id).maybeSingle()
    const username = profileData?.full_name || profileData?.username || 'Kullanıcı'

    const { data: posts, error: postsError } = await supabase
      .from('posts')
      .select('id, content, image_url, image_urls, location, spotify_track_name, spotify_artist_name, video_frame_urls')
      .eq('user_id', user_id)
      .order('created_at', { ascending: false })
      .limit(30)

    if (postsError) throw postsError
    if (!posts || posts.length === 0) {
      return new Response(JSON.stringify({ message: 'Post bulunamadı' }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200,
      })
    }

    console.log(`${username} için ${posts.length} post analiz ediliyor...`)

    // Paralel analiz (5'erli batch)
    const postResults: { text: string, scene_tags: string[] }[] = []
    for (let i = 0; i < posts.length; i += 5) {
      const batch = posts.slice(i, i + 5)
      const results = await Promise.all(batch.map(p => analyzePost(p, anthropicKey)))
      postResults.push(...results)
    }

    // Her postu DB'de güncelle (photo_scene_tags + mentioned_usernames)
    await Promise.all(posts.map((post, i) => {
      const result = postResults[i]  // { text, scene_tags }
      const mentions = extractMentions((post.content as string) || '')
      return supabase.from('posts').update({
        photo_scene_tags: result.scene_tags,
        mentioned_usernames: mentions,
      }).eq('id', post.id)
    }))

    const validAnalyses = postResults.map(r => r.text).filter(Boolean)
    if (validAnalyses.length === 0) {
      return new Response(JSON.stringify({ message: 'Analiz edilecek içerik yok' }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200,
      })
    }

    // Build quiz context string if available
    let quizContext: string | undefined
    if (quiz_answers && typeof quiz_answers === 'object') {
      const questionLabels: Record<string, string> = {
        q1: 'Hafta sonu enerjisi', q2: 'Motivasyon kaynağı', q3: 'Sosyal inisiyatif',
        q4: 'Stres sıfırlama', q5: 'İlk kıvılcım', q6: 'İlk buluşma tercihi',
        q7: 'Kırmızı çizgi', q8: 'Bağın derinleşme işareti', q9: 'İlişki uyumu',
        q10: 'Aşk stili', q11: 'Sosyal rol', q12: 'Çatışma tarzı', q13: 'Eşten beklenti'
      }
      quizContext = Object.entries(quiz_answers as Record<string, string>)
        .filter(([k]) => k.startsWith('q'))
        .map(([k, v]) => `- ${questionLabels[k] ?? k}: ${v}`)
        .join('\n')
    }

    const { summary, interests, social_style, _debug } = await synthesizeProfile(validAnalyses, username, anthropicKey, quizContext)
    console.log(`Profil: ${summary.substring(0, 80)}`)
    console.log(`İlgiler: ${interests.join(', ')}`)
    console.log(`Sosyal stil: ${social_style}`)
    if (_debug) console.error(`Debug: ${_debug}`)

    const { error: upsertError } = await supabase
      .from('user_profiles')
      .upsert({
        user_id,
        profile_summary:     summary,
        interests,
        social_style,
        analyzed_post_count: posts.length,
        updated_at:          new Date().toISOString(),
      }, { onConflict: 'user_id' })

    if (upsertError) throw upsertError
    console.log(`✅ ${username} profili kaydedildi`)

    return new Response(
      JSON.stringify({ success: true, username, postCount: posts.length, summary, interests, social_style, _debug }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 }
    )

  } catch (error) {
    console.error("analyze-user-profile hatası:", error)
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 500,
    })
  }
})
