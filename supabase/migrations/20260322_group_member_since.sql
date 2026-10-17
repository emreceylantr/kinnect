-- Kinnect: Group member join timestamps (yeni üyeler eski mesajları görmesin)
ALTER TABLE chat_rooms
  ADD COLUMN IF NOT EXISTS member_since jsonb DEFAULT '{}'::jsonb;
