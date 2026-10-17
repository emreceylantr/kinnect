-- Kinnect: Group Chat Support
-- Adds group chat fields to chat_rooms and makes receiver_id nullable in messages

-- 1. Add group fields to chat_rooms
ALTER TABLE chat_rooms
  ADD COLUMN IF NOT EXISTS is_group boolean DEFAULT false,
  ADD COLUMN IF NOT EXISTS group_name text,
  ADD COLUMN IF NOT EXISTS group_avatar_url text,
  ADD COLUMN IF NOT EXISTS created_by uuid REFERENCES auth.users(id) ON DELETE SET NULL;

-- 2. Make receiver_id nullable in messages (group messages have no single receiver)
ALTER TABLE messages
  ALTER COLUMN receiver_id DROP NOT NULL;

-- 3. Index for group chat lookups
CREATE INDEX IF NOT EXISTS idx_chat_rooms_is_group ON chat_rooms(is_group);
