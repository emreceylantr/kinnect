import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

// ─── Jaccard benzerliği (kısmi eşleşme de sayılır) ───────────────────────────
function jaccardSimilarity(a: string[], b: string[]): number {
  if (!a?.length || !b?.length) return 0
  const setA = new Set(a.map(s => s.toLowerCase().trim()))
  const setB = new Set(b.map(s => s.toLowerCase().trim()))
  let intersection = 0
  for (const item of setA) {
    if (setB.has(item)) {
      intersection += 1
    } else {
      for (const bItem of setB) {
        if (item.includes(bItem) || bItem.includes(item)) {
          intersection += 0.5
          break
        }
      }
    }
  }
  const union = setA.size + setB.size - intersection
  return union > 0 ? Math.min(1, intersection / union) : 0
}

// ─── Ortak ilgi bul ───────────────────────────────────────────────────────────
function findCommonInterests(a: string[], b: string[]): string[] {
  const setB = new Set(b.map(s => s.toLowerCase().trim()))
  const result: string[] = []
  for (const item of a) {
    const lower = item.toLowerCase().trim()
    if (setB.has(lower)) {
      result.push(item)
    } else {
      for (const bItem of setB) {
        if (lower.includes(bItem) || bItem.includes(lower)) {
          result.push(item)
          break
        }
      }
    }
  }
  return result
}

// ─── Eşleşme sebepleri ────────────────────────────────────────────────────────
function findMatchReasons(
  myInterests: string[],
  myPosts: any[],
  otherInterests: string[],
  otherPosts: any[],
): string[] {
  const reasons: string[] = []

  // 1. Ortak Spotify sanatçı
  const myArtistSet = new Set(
    myPosts.map(p => p.spotify_artist_name).filter(Boolean).map(s => s.toLowerCase()),
  )
  for (const post of otherPosts) {
    if (post.spotify_artist_name && myArtistSet.has(post.spotify_artist_name.toLowerCase())) {
      reasons.push(`Her ikiniz de ${post.spotify_artist_name} dinliyorsunuz 🎵`)
      break
    }
  }

  // 2. Ortak konum
  const myLocSet = new Set(
    myPosts.map(p => p.location).filter(Boolean).map(s => s.toLowerCase().trim()),
  )
  for (const post of otherPosts) {
    if (post.location && myLocSet.has(post.location.toLowerCase().trim())) {
      reasons.push(`İkiniz de ${post.location}'dan paylaşım yaptınız 📍`)
      break
    }
  }

  // 3. Ortak Spotify şarkı
  if (reasons.length < 3) {
    const myTrackSet = new Set(
      myPosts.map(p => p.spotify_track_name).filter(Boolean).map(s => s.toLowerCase()),
    )
    for (const post of otherPosts) {
      if (post.spotify_track_name && myTrackSet.has(post.spotify_track_name.toLowerCase())) {
        reasons.push(`"${post.spotify_track_name}" şarkısını ikiniz de paylaştınız 🎶`)
        break
      }
    }
  }

  // 4. Post içeriğindeki konu eşleşmeleri
  if (reasons.length < 3) {
    const myContent = myPosts.map(p => p.content || '').join(' ').toLowerCase()
    const otherContent = otherPosts.map(p => p.content || '').join(' ').toLowerCase()

    const topicGroups = [
      { keywords: ['valorant', 'cs2', 'pubg', 'lol', 'fortnite', 'gaming', 'maplestory', 'dota'], label: 'Oyun tutkunusunuz 🎮' },
      { keywords: ['istanbul', 'kadıköy', 'beşiktaş', 'taksim', 'bağcılar'], label: 'İstanbul\'u seviyorsunuz 🏙️' },
      { keywords: ['ankara', 'izmir', 'bursa', 'antalya', 'trabzon'], label: 'Aynı şehri paylaşıyorsunuz 📌' },
      { keywords: ['kafe', 'kahve', 'coffee', 'cafe', 'espresso', 'latte'], label: 'Kafe kültürünü seviyorsunuz ☕' },
      { keywords: ['seyahat', 'tatil', 'yolculuk', 'gezi', 'keşif'], label: 'İkiniz de seyahat tutkunusunuz ✈️' },
      { keywords: ['konser', 'festival', 'canlı müzik'], label: 'Müzik etkinliklerine gidiyorsunuz 🎤' },
      { keywords: ['doğa', 'kamp', 'dağ', 'orman', 'yürüyüş', 'hiking'], label: 'Doğa seversiniz 🌿' },
      { keywords: ['spor', 'futbol', 'basketbol', 'voleybol', 'yüzme'], label: 'Spora ilgi duyuyorsunuz ⚽' },
    ]

    for (const group of topicGroups) {
      if (reasons.length >= 3) break
      const myHas = group.keywords.some(k => myContent.includes(k))
      const otherHas = group.keywords.some(k => otherContent.includes(k))
      if (myHas && otherHas) reasons.push(group.label)
    }
  }

  // 5. Ortak ilgi alanları (fallback)
  const commonInterests = findCommonInterests(myInterests, otherInterests)
  for (const interest of commonInterests) {
    if (reasons.length >= 3) break
    reasons.push(`${interest} ilginiz örtüşüyor ✨`)
  }

  return reasons.slice(0, 3)
}

// ─── MAIN ─────────────────────────────────────────────────────────────────────
serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })

  try {
    const { user_id } = await req.json()
    if (!user_id) throw new Error('user_id gerekli')

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    )

    // 0. Kendi profil bilgilerim
    const { data: myProfileInfo } = await supabase
      .from('profiles')
      .select('id, username, full_name')
      .eq('id', user_id)
      .maybeSingle()

    // 1. Kendi profilim
    const { data: myProfile } = await supabase
      .from('user_profiles')
      .select('interests, profile_summary, social_style, spotify_top_artists, spotify_top_tracks')
      .eq('user_id', user_id)
      .maybeSingle()

    if (!myProfile) {
      return new Response(JSON.stringify([]), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    // 2. Kendi postlarım (id dahil — engagement sorguları için)
    const { data: myPosts } = await supabase
      .from('posts')
      .select('id, content, spotify_track_name, spotify_artist_name, location, image_urls, photo_scene_tags, mentioned_usernames')
      .eq('user_id', user_id)
      .order('created_at', { ascending: false })
      .limit(30)

    // 3. Diğer kullanıcı profilleri
    const { data: otherProfiles } = await supabase
      .from('user_profiles')
      .select('user_id, profile_summary, interests, social_style, analyzed_post_count, spotify_top_artists, spotify_top_tracks')
      .neq('user_id', user_id)

    if (!otherProfiles?.length) {
      return new Response(JSON.stringify([]), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    // 4. Tüm diğer kullanıcıların postları (id dahil)
    const otherUserIds = otherProfiles.map(p => p.user_id)
    const { data: allOtherPosts } = await supabase
      .from('posts')
      .select('id, user_id, content, spotify_track_name, spotify_artist_name, location, image_urls, photo_scene_tags, mentioned_usernames')
      .in('user_id', otherUserIds)
      .order('created_at', { ascending: false })

    // user_id'ye göre grupla
    const postsByUser: Record<string, any[]> = {}
    for (const post of (allOtherPosts || [])) {
      if (!postsByUser[post.user_id]) postsByUser[post.user_id] = []
      if (postsByUser[post.user_id].length < 30) postsByUser[post.user_id].push(post)
    }

    // 5. Profil bilgileri (avatar, username)
    const { data: profileInfos } = await supabase
      .from('profiles')
      .select('id, username, full_name, avatar_url')
      .in('id', otherUserIds)

    const profileInfoMap: Record<string, any> = {}
    for (const p of (profileInfos || [])) profileInfoMap[p.id] = p

    // ── Engagement verileri ────────────────────────────────────────────────────
    const myPostIds = (myPosts || []).map(p => p.id)
    const allOtherPostIds = (allOtherPosts || []).map(p => p.id)

    // 6a. Benim diğer kullanıcılara attığım harlamalar
    const { data: myLikesData } = allOtherPostIds.length > 0
      ? await supabase.from('likes').select('post_id').eq('user_id', user_id).in('post_id', allOtherPostIds)
      : { data: [] }

    // 6b. Diğer kullanıcıların benim postlarıma attığı harlamalar
    const { data: likesOnMyPostsData } = myPostIds.length > 0
      ? await supabase.from('likes').select('user_id, post_id').in('post_id', myPostIds).neq('user_id', user_id)
      : { data: [] }

    // 6c. Benim diğer kullanıcılara yazdığım yorumlar
    const { data: myCommentsData } = allOtherPostIds.length > 0
      ? await supabase.from('comments').select('post_id').eq('user_id', user_id).in('post_id', allOtherPostIds)
      : { data: [] }

    // 6d. Diğer kullanıcıların benim postlarıma yazdığı yorumlar
    const { data: commentsOnMyPostsData } = myPostIds.length > 0
      ? await supabase.from('comments').select('user_id, post_id').in('post_id', myPostIds).neq('user_id', user_id)
      : { data: [] }

    // Post ID → post owner map (diğer kullanıcıların postları)
    const postOwnerMap: Record<string, string> = {}
    for (const post of (allOtherPosts || [])) postOwnerMap[post.id] = post.user_id

    // Benim beğenilerim: otherUserId → count
    const myLikesPerUser: Record<string, number> = {}
    for (const like of (myLikesData || [])) {
      const owner = postOwnerMap[like.post_id]
      if (owner) myLikesPerUser[owner] = (myLikesPerUser[owner] || 0) + 1
    }

    // Diğerlerinin bana beğenileri: otherUserId → count
    const likesOnMePerUser: Record<string, number> = {}
    for (const like of (likesOnMyPostsData || [])) {
      likesOnMePerUser[like.user_id] = (likesOnMePerUser[like.user_id] || 0) + 1
    }

    // Benim yorumlarım: otherUserId → count
    const myCommentsPerUser: Record<string, number> = {}
    for (const comment of (myCommentsData || [])) {
      const owner = postOwnerMap[comment.post_id]
      if (owner) myCommentsPerUser[owner] = (myCommentsPerUser[owner] || 0) + 1
    }

    // Diğerlerinin bana yorumları: otherUserId → count
    const commentsOnMePerUser: Record<string, number> = {}
    for (const comment of (commentsOnMyPostsData || [])) {
      commentsOnMePerUser[comment.user_id] = (commentsOnMePerUser[comment.user_id] || 0) + 1
    }

    const myPostCount = myPostIds.length

    // 7. Her kullanıcı için skor + sebepler hesapla
    const results: any[] = []
    for (const otherProfile of otherProfiles) {
      const otherPosts = postsByUser[otherProfile.user_id] || []
      const profileInfo = profileInfoMap[otherProfile.user_id]
      if (!profileInfo) continue

      // ── 1. İlgi alanı skoru (0–1) ─────────────────────────────────────────
      const interestScore = jaccardSimilarity(
        myProfile.interests || [],
        otherProfile.interests || [],
      )

      // ── 2. Müzik skoru (0–1) ──────────────────────────────────────────────
      const myTopArtistSet = new Set([
        ...(myProfile.spotify_top_artists || []).map((s: string) => s.toLowerCase()),
        ...(myPosts || []).map((p: any) => p.spotify_artist_name).filter(Boolean).map((s: string) => s.toLowerCase()),
      ])
      const otherTopArtists = [
        ...(otherProfile.spotify_top_artists || []).map((s: string) => s.toLowerCase()),
        ...otherPosts.map((p: any) => p.spotify_artist_name).filter(Boolean).map((s: string) => s.toLowerCase()),
      ]
      const commonTopArtists = otherTopArtists.filter(a => myTopArtistSet.has(a))
      const artistScore = Math.min(commonTopArtists.length / 5, 1)

      const myTopTrackSet = new Set(
        (myProfile.spotify_top_tracks || []).map((s: string) => s.toLowerCase()),
      )
      const otherTopTracks = (otherProfile.spotify_top_tracks || []).map((s: string) => s.toLowerCase())
      const commonTopTracks = otherTopTracks.filter((t: string) => myTopTrackSet.has(t))
      const trackScore = Math.min(commonTopTracks.length / 3, 1)

      const musicScore = artistScore * 0.70 + trackScore * 0.30

      // ── 3. Davranış skoru (0–1) ───────────────────────────────────────────
      const mySocialStyle = myProfile.social_style || ""
      const otherSocialStyle = otherProfile.social_style || ""
      const socialStyleMatch = mySocialStyle && otherSocialStyle && mySocialStyle === otherSocialStyle
      const styleScore = socialStyleMatch ? 1 : 0

      const mySceneTags = new Set(
        (myPosts || []).flatMap(p => (p.photo_scene_tags as string[]) || []).map(t => t.toLowerCase())
      )
      const otherSceneTagsList = otherPosts
        .flatMap(p => (p.photo_scene_tags as string[]) || [])
        .map(t => t.toLowerCase())
      const commonSceneTags = [...new Set(otherSceneTagsList.filter(t => mySceneTags.has(t)))]
      const totalUniqueTags = new Set([...mySceneTags, ...otherSceneTagsList]).size
      const sceneJaccard = totalUniqueTags > 0 ? commonSceneTags.length / totalUniqueTags : 0

      const myLocSet = new Set(
        (myPosts || []).map((p: any) => p.location).filter(Boolean).map((s: string) => s.toLowerCase().trim()),
      )
      const hasCommonLocation = otherPosts.some(
        (p: any) => p.location && myLocSet.has(p.location.toLowerCase().trim()),
      )
      const locationScore = hasCommonLocation ? 1 : 0

      const behaviorScore = styleScore * 0.40 + sceneJaccard * 0.40 + locationScore * 0.20

      // ── 4. Sosyal graf skoru (mention) (0–1) ──────────────────────────────
      const myUsername = (myProfileInfo?.username || '').toLowerCase()
      const myFirstName = (myProfileInfo?.full_name || myProfileInfo?.username || '').split(' ')[0].toLowerCase()
      const otherUsername = (profileInfo.username || '').toLowerCase()
      const otherFirstName = (profileInfo.full_name || profileInfo.username || '').split(' ')[0].toLowerCase()

      const myMentionsOther = (myPosts || []).some(p => {
        const mentions = ((p.mentioned_usernames as string[]) || []).map(m => m.toLowerCase())
        if (otherUsername && mentions.includes(otherUsername)) return true
        if (otherFirstName.length >= 4 && (p.content || '').toLowerCase().includes(otherFirstName)) return true
        return false
      })
      const otherMentionsMe = otherPosts.some(p => {
        const mentions = ((p.mentioned_usernames as string[]) || []).map(m => m.toLowerCase())
        if (myUsername && mentions.includes(myUsername)) return true
        if (myFirstName.length >= 4 && (p.content || '').toLowerCase().includes(myFirstName)) return true
        return false
      })

      const socialScore = (myMentionsOther && otherMentionsMe) ? 1.0
        : (myMentionsOther || otherMentionsMe) ? 0.50
        : 0

      // ── 5. Engagement skoru (beğeni + yorum) (0–1) ────────────────────────
      const otherId = otherProfile.user_id
      const otherPostCount = otherPosts.length

      const myLikesOnOther = myLikesPerUser[otherId] || 0
      const othersLikesOnMe = likesOnMePerUser[otherId] || 0
      const myCommentsOnOther = myCommentsPerUser[otherId] || 0
      const othersCommentsOnMe = commentsOnMePerUser[otherId] || 0

      // Oran: kaç postunu beğendim / toplam post sayısı
      const likeRateMyToOther = otherPostCount > 0 ? Math.min(myLikesOnOther / otherPostCount, 1) : 0
      const likeRateOtherToMe = myPostCount > 0 ? Math.min(othersLikesOnMe / myPostCount, 1) : 0
      // Yorum: 3+ yorum = max puan
      const commentScoreMyToOther = Math.min(myCommentsOnOther / 3, 1)
      const commentScoreOtherToMe = Math.min(othersCommentsOnMe / 3, 1)

      const engagementScore = likeRateMyToOther * 0.40
        + likeRateOtherToMe * 0.30
        + commentScoreMyToOther * 0.20
        + commentScoreOtherToMe * 0.10

      // ── Final skor: 5 kategori ────────────────────────────────────────────
      const score = interestScore  * 0.30
        + musicScore       * 0.25
        + behaviorScore    * 0.18
        + socialScore      * 0.12
        + engagementScore  * 0.15

      const commonInterests = findCommonInterests(
        myProfile.interests || [],
        otherProfile.interests || [],
      )

      // ── Match reasons ─────────────────────────────────────────────────────
      const spotifyReasons: string[] = []
      if (commonTopArtists.length > 0) {
        const artistDisplay = otherProfile.spotify_top_artists?.find(
          (a: string) => myTopArtistSet.has(a.toLowerCase()),
        ) || commonTopArtists[0]
        spotifyReasons.push(`Her ikiniz de ${artistDisplay} dinliyorsunuz 🎵`)
        if (commonTopArtists.length >= 3) {
          spotifyReasons.push(`${commonTopArtists.length} ortak favori sanatçınız var 🎶`)
        }
      }

      const socialStyleLabels: Record<string, string> = {
        "yalnız": "İkiniz de bağımsız ruhlar — tek başına vakit geçirmeyi seviyorsunuz 🌙",
        "ikili": "İkiniz de yakın çevrenizle birlikteyken en mutlusunuz 🤝",
        "sosyal": "İkiniz de kalabalık ortamları seviyorsunuz 🎉",
        "karma": "İkiniz de hem sosyal hem de sessiz anlara değer veriyorsunuz ⚖️",
      }

      const socialStyleReasons: string[] = socialStyleMatch && socialStyleLabels[mySocialStyle]
        ? [socialStyleLabels[mySocialStyle]]
        : []

      const socialGraphReasons: string[] = []
      if (myMentionsOther && otherMentionsMe) {
        socialGraphReasons.push('Birbirinizin paylaşımlarında görünüyorsunuz 👥')
      } else if (myMentionsOther || otherMentionsMe) {
        socialGraphReasons.push('Birbirinizi etiketlediniz 🔗')
      }
      if (commonSceneTags.length >= 3) {
        socialGraphReasons.push(`Benzer ortamları paylaşıyorsunuz 📸`)
      }

      // Engagement sebepleri
      const engagementReasons: string[] = []
      const isMutualLike = myLikesOnOther >= 1 && othersLikesOnMe >= 1
      const isMutualComment = myCommentsOnOther >= 1 && othersCommentsOnMe >= 1
      const highLikeRate = otherPostCount >= 3 && likeRateMyToOther >= 0.5

      if (isMutualComment || (myCommentsOnOther >= 2) || (othersCommentsOnMe >= 2)) {
        engagementReasons.push('Birbirinizin paylaşımlarına yorum yapıyorsunuz 💬')
      } else if (isMutualLike) {
        engagementReasons.push('Birbirinizin paylaşımlarını harlıyorsunuz 🔥')
      } else if (highLikeRate) {
        engagementReasons.push('Paylaşımları genellikle ilgini çekiyor 🔥')
      }

      const matchReasons = [
        ...engagementReasons,
        ...socialGraphReasons,
        ...spotifyReasons,
        ...socialStyleReasons,
        ...findMatchReasons(
          myProfile.interests || [],
          myPosts || [],
          otherProfile.interests || [],
          otherPosts,
        ).filter(r => !r.includes('dinliyorsunuz')),
      ].slice(0, 3)

      results.push({
        user_id: otherProfile.user_id,
        similarity: score,
        profile_summary: otherProfile.profile_summary || '',
        interests: otherProfile.interests || [],
        common_interests: commonInterests,
        match_reasons: matchReasons,
        profile: profileInfo,
      })
    }

    // Min-max normalizasyon: 30%–85% bandı
    const rawScores = results.map(r => r.similarity as number)
    const minRaw = Math.min(...rawScores)
    const maxRaw = Math.max(...rawScores)
    const rawRange = maxRaw - minRaw

    for (const r of results) {
      r.similarity = rawRange > 0.05
        ? 0.30 + ((r.similarity - minRaw) / rawRange) * 0.55
        : 0.50 + r.similarity * 0.20
    }

    results.sort((a, b) => b.similarity - a.similarity)

    return new Response(JSON.stringify(results.slice(0, 25)), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  } catch (err) {
    return new Response(JSON.stringify({ error: err.message }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 500,
    })
  }
})
