import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

// ─── Post özeti tipi ─────────────────────────────────────────────────────────
interface PostSummary {
  id: string
  image_urls: string[] | null
  video_url: string | null
  video_frame_urls: string[] | null
  content: string | null
  spotify_track_name: string | null
  spotify_artist_name: string | null
  spotify_album_image: string | null
  location: string | null
}

// ─── Sebep + kaynak post tipi ─────────────────────────────────────────────────
interface ReasonWithSource {
  reason: string
  my_posts: PostSummary[]
  other_posts: PostSummary[]
}

function toPostSummary(p: any): PostSummary {
  return {
    id: p.id,
    image_urls: p.image_urls ?? null,
    video_url: p.video_url ?? null,
    video_frame_urls: p.video_frame_urls ?? null,
    content: p.content ? (p.content as string).slice(0, 120) : null,
    spotify_track_name: p.spotify_track_name ?? null,
    spotify_artist_name: p.spotify_artist_name ?? null,
    spotify_album_image: p.spotify_album_image ?? null,
    location: p.location ?? null,
  }
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

// ─── Eşleşme sebepleri (kaynak postlarla birlikte) ────────────────────────────
function findMatchReasons(
  myInterests: string[],
  myPosts: any[],
  otherInterests: string[],
  otherPosts: any[],
  lang: string = 'tr',
): ReasonWithSource[] {
  const isEn = lang === 'en'
  const reasons: ReasonWithSource[] = []

  // 1. Ortak Spotify sanatçı (post bazlı)
  const myArtistSet = new Set(
    myPosts.map(p => p.spotify_artist_name).filter(Boolean).map(s => s.toLowerCase()),
  )
  for (const post of otherPosts) {
    if (post.spotify_artist_name && myArtistSet.has(post.spotify_artist_name.toLowerCase())) {
      const artistLower = post.spotify_artist_name.toLowerCase()
      reasons.push({
        reason: isEn ? `You both listen to ${post.spotify_artist_name} 🎵` : `Her ikiniz de ${post.spotify_artist_name} dinliyorsunuz 🎵`,
        my_posts: myPosts.filter(p => p.spotify_artist_name?.toLowerCase() === artistLower).slice(0, 4).map(toPostSummary),
        other_posts: otherPosts.filter(p => p.spotify_artist_name?.toLowerCase() === artistLower).slice(0, 4).map(toPostSummary),
      })
      break
    }
  }

  // 2. Ortak konum
  const myLocSet = new Set(
    myPosts.map(p => p.location).filter(Boolean).map(s => s.toLowerCase().trim()),
  )
  for (const post of otherPosts) {
    if (post.location && myLocSet.has(post.location.toLowerCase().trim())) {
      const locLower = post.location.toLowerCase().trim()
      reasons.push({
        reason: isEn ? `You both posted from ${post.location} 📍` : `İkiniz de ${post.location}'dan paylaşım yaptınız 📍`,
        my_posts: myPosts.filter(p => p.location?.toLowerCase().trim() === locLower).slice(0, 4).map(toPostSummary),
        other_posts: otherPosts.filter(p => p.location?.toLowerCase().trim() === locLower).slice(0, 4).map(toPostSummary),
      })
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
        const trackLower = post.spotify_track_name.toLowerCase()
        reasons.push({
          reason: isEn ? `You both shared "${post.spotify_track_name}" 🎶` : `"${post.spotify_track_name}" şarkısını ikiniz de paylaştınız 🎶`,
          my_posts: myPosts.filter(p => p.spotify_track_name?.toLowerCase() === trackLower).slice(0, 4).map(toPostSummary),
          other_posts: otherPosts.filter(p => p.spotify_track_name?.toLowerCase() === trackLower).slice(0, 4).map(toPostSummary),
        })
        break
      }
    }
  }

  // 4. Post içeriğindeki konu eşleşmeleri
  if (reasons.length < 3) {
    const topicGroups = [
      { keywords: ['valorant', 'cs2', 'pubg', 'lol', 'fortnite', 'gaming', 'maplestory', 'dota'], label: isEn ? 'You are both gaming enthusiasts 🎮' : 'Oyun tutkunusunuz 🎮' },
      { keywords: ['istanbul', 'kadıköy', 'beşiktaş', 'taksim', 'bağcılar'], label: isEn ? 'You both love Istanbul 🏙️' : 'İstanbul\'u seviyorsunuz 🏙️' },
      { keywords: ['ankara', 'izmir', 'bursa', 'antalya', 'trabzon'], label: isEn ? 'You share the same city 📌' : 'Aynı şehri paylaşıyorsunuz 📌' },
      { keywords: ['kafe', 'kahve', 'coffee', 'cafe', 'espresso', 'latte'], label: isEn ? 'You both love café culture ☕' : 'Kafe kültürünü seviyorsunuz ☕' },
      { keywords: ['seyahat', 'tatil', 'yolculuk', 'gezi', 'keşif'], label: isEn ? 'You are both travel enthusiasts ✈️' : 'İkiniz de seyahat tutkunusunuz ✈️' },
      { keywords: ['konser', 'festival', 'canlı müzik'], label: isEn ? 'You both go to music events 🎤' : 'Müzik etkinliklerine gidiyorsunuz 🎤' },
      { keywords: ['doğa', 'kamp', 'dağ', 'orman', 'yürüyüş', 'hiking'], label: isEn ? 'You both love nature 🌿' : 'Doğa seversiniz 🌿' },
      { keywords: ['spor', 'futbol', 'basketbol', 'voleybol', 'yüzme'], label: isEn ? 'You are both into sports ⚽' : 'Spora ilgi duyuyorsunuz ⚽' },
    ]

    for (const group of topicGroups) {
      if (reasons.length >= 3) break
      const myMatchPosts = myPosts.filter(p => group.keywords.some(k => (p.content || '').toLowerCase().includes(k)))
      const otherMatchPosts = otherPosts.filter(p => group.keywords.some(k => (p.content || '').toLowerCase().includes(k)))
      if (myMatchPosts.length > 0 && otherMatchPosts.length > 0) {
        reasons.push({
          reason: group.label,
          my_posts: myMatchPosts.slice(0, 4).map(toPostSummary),
          other_posts: otherMatchPosts.slice(0, 4).map(toPostSummary),
        })
      }
    }
  }

  // 5. Ortak ilgi alanları (fallback)
  const musicKeywords = ['müzik', 'music', 'şarkı', 'konser', 'festival', 'playlist', 'albüm', 'müzisyen']
  const commonInterests = findCommonInterests(myInterests, otherInterests)
  for (const interest of commonInterests) {
    if (reasons.length >= 3) break
    const interestLower = interest.toLowerCase()
    const isMusicInterest = musicKeywords.some(k => interestLower.includes(k))
    let myMatchPosts = myPosts.filter(p => (p.content || '').toLowerCase().includes(interestLower)).slice(0, 4)
    let otherMatchPosts = otherPosts.filter(p => (p.content || '').toLowerCase().includes(interestLower)).slice(0, 4)
    // Müzik ilgisi için Spotify postlarına da bak
    if (isMusicInterest) {
      if (myMatchPosts.length === 0) myMatchPosts = myPosts.filter(p => p.spotify_track_name || p.spotify_artist_name).slice(0, 4)
      if (otherMatchPosts.length === 0) otherMatchPosts = otherPosts.filter(p => p.spotify_track_name || p.spotify_artist_name).slice(0, 4)
    }
    reasons.push({
      reason: isEn ? `You share an interest in ${interest} ✨` : `${interest} ilginiz örtüşüyor ✨`,
      my_posts: myMatchPosts.map(toPostSummary),
      other_posts: otherMatchPosts.map(toPostSummary),
    })
  }

  return reasons.slice(0, 3)
}

// ─── MAIN ─────────────────────────────────────────────────────────────────────
serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })

  try {
    const { user_id, language } = await req.json()
    if (!user_id) throw new Error('user_id gerekli')
    const isEn = language === 'en'

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
      .select('id, content, spotify_track_name, spotify_artist_name, spotify_album_image, location, image_urls, video_url, video_frame_urls, photo_scene_tags, mentioned_usernames')
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
      .select('id, user_id, content, spotify_track_name, spotify_artist_name, spotify_album_image, location, image_urls, video_url, video_frame_urls, photo_scene_tags, mentioned_usernames')
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

    // Post ID → post data map (diğer kullanıcıların postları)
    const postDataMap: Record<string, any> = {}
    for (const post of (allOtherPosts || [])) postDataMap[post.id] = post

    // Post ID → post data map (benim postlarım)
    const myPostDataMap: Record<string, any> = {}
    for (const post of (myPosts || [])) myPostDataMap[post.id] = post

    // Benim beğenilerim: otherUserId → count
    const myLikesPerUser: Record<string, number> = {}
    // Benim beğendiğim postların ID seti: otherUserId → post_id[]
    const myLikedPostIdsByUser: Record<string, string[]> = {}
    for (const like of (myLikesData || [])) {
      const owner = postOwnerMap[like.post_id]
      if (owner) {
        myLikesPerUser[owner] = (myLikesPerUser[owner] || 0) + 1
        if (!myLikedPostIdsByUser[owner]) myLikedPostIdsByUser[owner] = []
        myLikedPostIdsByUser[owner].push(like.post_id)
      }
    }

    // Diğerlerinin bana beğenileri: otherUserId → count
    const likesOnMePerUser: Record<string, number> = {}
    // Diğerlerinin beğendiği benim postlarım: otherUserId → post_id[]
    const likedMyPostIdsByUser: Record<string, string[]> = {}
    for (const like of (likesOnMyPostsData || [])) {
      likesOnMePerUser[like.user_id] = (likesOnMePerUser[like.user_id] || 0) + 1
      if (!likedMyPostIdsByUser[like.user_id]) likedMyPostIdsByUser[like.user_id] = []
      likedMyPostIdsByUser[like.user_id].push(like.post_id)
    }

    // Benim yorumlarım: otherUserId → count
    const myCommentsPerUser: Record<string, number> = {}
    // Yorum yaptığım postların ID'leri: otherUserId → post_id[]
    const myCommentedPostIdsByUser: Record<string, string[]> = {}
    for (const comment of (myCommentsData || [])) {
      const owner = postOwnerMap[comment.post_id]
      if (owner) {
        myCommentsPerUser[owner] = (myCommentsPerUser[owner] || 0) + 1
        if (!myCommentedPostIdsByUser[owner]) myCommentedPostIdsByUser[owner] = []
        myCommentedPostIdsByUser[owner].push(comment.post_id)
      }
    }

    // Diğerlerinin bana yorumları: otherUserId → count
    const commentsOnMePerUser: Record<string, number> = {}
    // Diğerlerinin yorum yaptığı benim postlarım: otherUserId → post_id[]
    const commentedMyPostIdsByUser: Record<string, string[]> = {}
    for (const comment of (commentsOnMyPostsData || [])) {
      commentsOnMePerUser[comment.user_id] = (commentsOnMePerUser[comment.user_id] || 0) + 1
      if (!commentedMyPostIdsByUser[comment.user_id]) commentedMyPostIdsByUser[comment.user_id] = []
      commentedMyPostIdsByUser[comment.user_id].push(comment.post_id)
    }

    const myPostCount = myPostIds.length

    // 7. Her kullanıcı için skor + sebepler hesapla
    const results: any[] = []
    for (const otherProfile of otherProfiles) {
      const otherPosts = postsByUser[otherProfile.user_id] || []
      const profileInfo = profileInfoMap[otherProfile.user_id]
      if (!profileInfo) continue

      // En az 5 gönderi olmayan kullanıcıları eşleşmeden çıkar
      if (otherPosts.length < 5) continue

      const otherId = otherProfile.user_id

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

      // ── Match reasons (kaynak postlarla) ─────────────────────────────────
      const reasonsWithSources: ReasonWithSource[] = []

      // Engagement sebepleri
      const isMutualLike = myLikesOnOther >= 1 && othersLikesOnMe >= 1
      const isMutualComment = myCommentsOnOther >= 1 && othersCommentsOnMe >= 1
      const highLikeRate = otherPostCount >= 3 && likeRateMyToOther >= 0.5

      if (isMutualComment || (myCommentsOnOther >= 2) || (othersCommentsOnMe >= 2)) {
        const myCommentedIds = (myCommentedPostIdsByUser[otherId] || []).slice(0, 4)
        const commentedMyIds = (commentedMyPostIdsByUser[otherId] || []).slice(0, 4)
        reasonsWithSources.push({
          reason: isEn ? 'You comment on each other\'s posts 💬' : 'Birbirinizin paylaşımlarına yorum yapıyorsunuz 💬',
          my_posts: commentedMyIds.map(id => myPostDataMap[id]).filter(Boolean).map(toPostSummary),
          other_posts: myCommentedIds.map(id => postDataMap[id]).filter(Boolean).map(toPostSummary),
        })
      } else if (isMutualLike) {
        const myLikedIds = (myLikedPostIdsByUser[otherId] || []).slice(0, 4)
        const likedMyIds = (likedMyPostIdsByUser[otherId] || []).slice(0, 4)
        reasonsWithSources.push({
          reason: isEn ? 'You fuel each other\'s posts 🔥' : 'Birbirinizin paylaşımlarını harlıyorsunuz 🔥',
          my_posts: likedMyIds.map(id => myPostDataMap[id]).filter(Boolean).map(toPostSummary),
          other_posts: myLikedIds.map(id => postDataMap[id]).filter(Boolean).map(toPostSummary),
        })
      } else if (highLikeRate) {
        const myLikedIds = (myLikedPostIdsByUser[otherId] || []).slice(0, 4)
        reasonsWithSources.push({
          reason: isEn ? 'Their posts often catch your attention 🔥' : 'Paylaşımları genellikle ilgini çekiyor 🔥',
          my_posts: [],
          other_posts: myLikedIds.map(id => postDataMap[id]).filter(Boolean).map(toPostSummary),
        })
      }

      // Sosyal graf sebepleri
      if (commonSceneTags.length >= 3) {
        const mySceneTagPosts = (myPosts || []).filter(p =>
          ((p.photo_scene_tags as string[]) || []).some(t => commonSceneTags.includes(t.toLowerCase()))
        ).slice(0, 4).map(toPostSummary)
        const otherSceneTagPosts = otherPosts.filter(p =>
          ((p.photo_scene_tags as string[]) || []).some(t => commonSceneTags.includes(t.toLowerCase()))
        ).slice(0, 4).map(toPostSummary)
        reasonsWithSources.push({
          reason: isEn ? 'You share similar environments 📸' : 'Benzer ortamları paylaşıyorsunuz 📸',
          my_posts: mySceneTagPosts,
          other_posts: otherSceneTagPosts,
        })
      }

      if (myMentionsOther && otherMentionsMe) {
        const myMentionPosts = (myPosts || []).filter(p => {
          const mentions = ((p.mentioned_usernames as string[]) || []).map(m => m.toLowerCase())
          return mentions.includes(otherUsername) || (otherFirstName.length >= 4 && (p.content || '').toLowerCase().includes(otherFirstName))
        }).slice(0, 4).map(toPostSummary)
        const otherMentionPosts = otherPosts.filter(p => {
          const mentions = ((p.mentioned_usernames as string[]) || []).map(m => m.toLowerCase())
          return mentions.includes(myUsername) || (myFirstName.length >= 4 && (p.content || '').toLowerCase().includes(myFirstName))
        }).slice(0, 4).map(toPostSummary)
        reasonsWithSources.push({
          reason: isEn ? 'You appear in each other\'s posts 👥' : 'Birbirinizin paylaşımlarında görünüyorsunuz 👥',
          my_posts: myMentionPosts,
          other_posts: otherMentionPosts,
        })
      } else if (myMentionsOther) {
        const myMentionPosts = (myPosts || []).filter(p => {
          const mentions = ((p.mentioned_usernames as string[]) || []).map(m => m.toLowerCase())
          return mentions.includes(otherUsername) || (otherFirstName.length >= 4 && (p.content || '').toLowerCase().includes(otherFirstName))
        }).slice(0, 4).map(toPostSummary)
        reasonsWithSources.push({
          reason: isEn ? 'You tagged them in a post 🔗' : 'Paylaşımında etiketlemişsin 🔗',
          my_posts: myMentionPosts,
          other_posts: [],
        })
      } else if (otherMentionsMe) {
        const otherMentionPosts = otherPosts.filter(p => {
          const mentions = ((p.mentioned_usernames as string[]) || []).map(m => m.toLowerCase())
          return mentions.includes(myUsername) || (myFirstName.length >= 4 && (p.content || '').toLowerCase().includes(myFirstName))
        }).slice(0, 4).map(toPostSummary)
        reasonsWithSources.push({
          reason: isEn ? 'They tagged you in a post 🔗' : 'Seni paylaşımında etiketledi 🔗',
          my_posts: [],
          other_posts: otherMentionPosts,
        })
      }

      // Spotify top artists sebepleri
      if (commonTopArtists.length > 0) {
        const artistDisplay = otherProfile.spotify_top_artists?.find(
          (a: string) => myTopArtistSet.has(a.toLowerCase()),
        ) || commonTopArtists[0]
        const artistLower = artistDisplay.toLowerCase()
        const myArtistPosts = (myPosts || []).filter(p => p.spotify_artist_name?.toLowerCase() === artistLower).slice(0, 4).map(toPostSummary)
        const otherArtistPosts = otherPosts.filter(p => p.spotify_artist_name?.toLowerCase() === artistLower).slice(0, 4).map(toPostSummary)
        reasonsWithSources.push({
          reason: isEn ? `You both listen to ${artistDisplay} 🎵` : `Her ikiniz de ${artistDisplay} dinliyorsunuz 🎵`,
          my_posts: myArtistPosts,
          other_posts: otherArtistPosts,
        })
        if (commonTopArtists.length >= 3) {
          reasonsWithSources.push({
            reason: isEn ? `You share ${commonTopArtists.length} favorite artists 🎶` : `${commonTopArtists.length} ortak favori sanatçınız var 🎶`,
            my_posts: [],
            other_posts: [],
          })
        }
      }

      // Social style sebepleri
      const socialStyleLabels: Record<string, string> = isEn ? {
        "yalnız": "You are both independent souls — you enjoy your own company 🌙",
        "ikili": "You are both happiest with your close circle 🤝",
        "sosyal": "You both love social gatherings 🎉",
        "karma": "You both value both social and quiet moments equally ⚖️",
      } : {
        "yalnız": "İkiniz de bağımsız ruhlar — tek başına vakit geçirmeyi seviyorsunuz 🌙",
        "ikili": "İkiniz de yakın çevrenizle birlikteyken en mutlusunuz 🤝",
        "sosyal": "İkiniz de kalabalık ortamları seviyorsunuz 🎉",
        "karma": "İkiniz de hem sosyal hem de sessiz anlara değer veriyorsunuz ⚖️",
      }
      if (socialStyleMatch && socialStyleLabels[mySocialStyle]) {
        reasonsWithSources.push({
          reason: socialStyleLabels[mySocialStyle],
          my_posts: [],
          other_posts: [],
        })
      }

      // findMatchReasons sonuçları (dinliyorsunuz içerenleri filtrele)
      const extraReasons = findMatchReasons(
        myProfile.interests || [],
        myPosts || [],
        otherProfile.interests || [],
        otherPosts,
        language,
      ).filter(r => !r.reason.includes('dinliyorsunuz') && !r.reason.includes('listen to'))

      for (const r of extraReasons) {
        reasonsWithSources.push(r)
      }

      const finalReasons = reasonsWithSources.slice(0, 3)
      const matchReasons = finalReasons.map(r => r.reason)
      const matchReasonSources = finalReasons.map(r => ({
        my_posts: r.my_posts,
        other_posts: r.other_posts,
      }))

      results.push({
        user_id: otherProfile.user_id,
        similarity: score,
        profile_summary: otherProfile.profile_summary || '',
        interests: otherProfile.interests || [],
        common_interests: commonInterests,
        match_reasons: matchReasons,
        match_reason_sources: matchReasonSources,
        recent_posts: otherPosts.slice(0, 3).map(toPostSummary),
        common_spotify: (() => {
          // Find first common artist with album image
          for (const post of otherPosts) {
            if (post.spotify_artist_name && post.spotify_album_image) {
              const artistLower = post.spotify_artist_name.toLowerCase()
              const myPost = (myPosts || []).find(p => p.spotify_artist_name?.toLowerCase() === artistLower && p.spotify_album_image)
              if (myPost) {
                return { artist: post.spotify_artist_name, album_image: post.spotify_album_image, track_name: post.spotify_track_name ?? null }
              }
            }
          }
          // fallback: just common artist without image
          for (const a of commonTopArtists) {
            const otherPost = otherPosts.find(p => p.spotify_artist_name?.toLowerCase() === a && p.spotify_album_image)
            if (otherPost) return { artist: otherPost.spotify_artist_name, album_image: otherPost.spotify_album_image, track_name: null }
          }
          return null
        })(),
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
