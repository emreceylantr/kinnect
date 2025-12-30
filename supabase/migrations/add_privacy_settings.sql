-- Profiles tablosuna gizlilik ayarları kolonları ekleme
-- Supabase SQL Editor'de çalıştırın

-- Son görülme gizlilik ayarı
ALTER TABLE profiles 
ADD COLUMN IF NOT EXISTS show_last_seen BOOLEAN DEFAULT true;

-- Okundu bilgisi gizlilik ayarı
ALTER TABLE profiles 
ADD COLUMN IF NOT EXISTS show_read_receipts BOOLEAN DEFAULT true;
