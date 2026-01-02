-- Messages tablosu için RLS Policy
-- Supabase SQL Editor'de çalıştırın

-- 1. Mesajları güncelleyebilme izni
DROP POLICY IF EXISTS "Users can update messages in their rooms" ON messages;

CREATE POLICY "Users can update messages in their rooms"
ON messages
FOR UPDATE
USING (
  receiver_id = auth.uid() OR sender_id = auth.uid()
)
WITH CHECK (
  receiver_id = auth.uid() OR sender_id = auth.uid()
);

-- 2. RLS'nin aktif olduğundan emin ol
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;
