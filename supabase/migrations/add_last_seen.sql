-- Profiles tablosuna last_seen kolonu ekleme
-- Supabase SQL Editor'de çalıştırın

ALTER TABLE profiles 
ADD COLUMN IF NOT EXISTS last_seen TIMESTAMPTZ;

-- İsteğe bağlı: Mevcut kullanıcılara default değer atama
UPDATE profiles 
SET last_seen = updated_at 
WHERE last_seen IS NULL;
