-- ═══════════════════════════════════════════════════════════════════════
-- Kullanıcı profili tablosu — Claude analizi + OpenAI embedding
-- ═══════════════════════════════════════════════════════════════════════

-- Eski post_embeddings verisini temizle (Gemini verileri artık kullanılmıyor)
TRUNCATE TABLE post_embeddings;

-- Yeni user_profiles tablosu
CREATE TABLE IF NOT EXISTS user_profiles (
  id                   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id              UUID NOT NULL UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
  profile_summary      TEXT,           -- Claude'un kişilik analizi
  interests            TEXT[],         -- Çıkarılan ilgi alanları listesi
  profile_embedding    vector(1536),   -- OpenAI text-embedding-3-small
  analyzed_post_count  INT DEFAULT 0,
  updated_at           TIMESTAMPTZ DEFAULT NOW(),
  created_at           TIMESTAMPTZ DEFAULT NOW()
);

-- Hızlı arama için HNSW index
CREATE INDEX IF NOT EXISTS user_profiles_embedding_idx
  ON user_profiles USING hnsw (profile_embedding vector_cosine_ops);

-- Sadece kendi profilini görebilir + herkese public okuma (eşleşme için)
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can read all profiles for matching"
  ON user_profiles FOR SELECT USING (true);

CREATE POLICY "Users can manage their own profile"
  ON user_profiles FOR ALL USING (auth.uid() = user_id);

-- ═══════════════════════════════════════════════════════════════════════
-- Profile bazlı kullanıcı eşleştirme fonksiyonu
-- ═══════════════════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION match_users_by_profile(
  query_embedding    vector(1536),
  match_threshold    float,
  match_count        int,
  exclude_user_id    uuid
)
RETURNS TABLE (
  user_id          uuid,
  profile_summary  text,
  interests        text[],
  similarity       float
)
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  SELECT
    up.user_id,
    up.profile_summary,
    up.interests,
    1 - (up.profile_embedding <=> query_embedding) AS similarity
  FROM user_profiles up
  WHERE
    up.user_id <> exclude_user_id
    AND up.profile_embedding IS NOT NULL
    AND 1 - (up.profile_embedding <=> query_embedding) > match_threshold
  ORDER BY up.profile_embedding <=> query_embedding
  LIMIT match_count;
END;
$$;
