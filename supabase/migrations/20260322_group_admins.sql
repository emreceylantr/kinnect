-- Kinnect: Group Admins support
ALTER TABLE chat_rooms
  ADD COLUMN IF NOT EXISTS group_admins uuid[] DEFAULT ARRAY[]::uuid[];
