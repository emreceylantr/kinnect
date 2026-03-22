-- Add live avatar start time to profiles
ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS live_avatar_start_ms integer DEFAULT 0;
