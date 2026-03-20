ALTER TABLE user_profiles
  ADD COLUMN IF NOT EXISTS spotify_top_artists text[] DEFAULT ARRAY[]::text[],
  ADD COLUMN IF NOT EXISTS spotify_top_tracks  text[] DEFAULT ARRAY[]::text[],
  ADD COLUMN IF NOT EXISTS spotify_synced_at   timestamptz;
