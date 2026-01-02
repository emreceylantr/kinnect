-- Kinnect Spark Mode - Device Registry
-- BLE ile yakındaki kullanıcıları algılama için cihaz kayıt tablosu

-- spark_devices tablosu
CREATE TABLE IF NOT EXISTS spark_devices (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  device_token VARCHAR(8) NOT NULL, -- Short unique token for BLE advertising
  platform VARCHAR(10), -- 'ios' or 'android'
  is_active BOOLEAN DEFAULT false, -- Spark mode currently enabled?
  last_seen_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  UNIQUE(user_id),
  UNIQUE(device_token)
);

-- Indexes for fast lookup
CREATE INDEX IF NOT EXISTS idx_spark_devices_token ON spark_devices(device_token);
CREATE INDEX IF NOT EXISTS idx_spark_devices_active ON spark_devices(is_active) WHERE is_active = true;

-- RLS Policies
ALTER TABLE spark_devices ENABLE ROW LEVEL SECURITY;

-- Users can read active devices (for discovery)
CREATE POLICY "Anyone can read active spark devices" ON spark_devices
  FOR SELECT USING (is_active = true);

-- Users can only modify their own device
CREATE POLICY "Users can manage their own spark device" ON spark_devices
  FOR ALL USING (auth.uid() = user_id);

-- Function to generate unique device token
CREATE OR REPLACE FUNCTION generate_device_token()
RETURNS VARCHAR(8) AS $$
DECLARE
  chars TEXT := 'abcdefghijklmnopqrstuvwxyz0123456789';
  result VARCHAR(8) := '';
  i INT;
BEGIN
  FOR i IN 1..8 LOOP
    result := result || substr(chars, floor(random() * length(chars) + 1)::int, 1);
  END LOOP;
  RETURN result;
END;
$$ LANGUAGE plpgsql;

-- Upsert function for registering device
CREATE OR REPLACE FUNCTION register_spark_device(p_user_id UUID, p_platform VARCHAR)
RETURNS VARCHAR(8) AS $$
DECLARE
  v_token VARCHAR(8);
BEGIN
  -- Check if user already has a device
  SELECT device_token INTO v_token FROM spark_devices WHERE user_id = p_user_id;
  
  IF v_token IS NOT NULL THEN
    -- Update existing
    UPDATE spark_devices 
    SET is_active = true, 
        last_seen_at = now(), 
        platform = p_platform
    WHERE user_id = p_user_id;
    RETURN v_token;
  ELSE
    -- Generate new token
    v_token := generate_device_token();
    
    -- Insert new record
    INSERT INTO spark_devices (user_id, device_token, platform, is_active)
    VALUES (p_user_id, v_token, p_platform, true);
    
    RETURN v_token;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to deactivate spark mode
CREATE OR REPLACE FUNCTION deactivate_spark_device(p_user_id UUID)
RETURNS VOID AS $$
BEGIN
  UPDATE spark_devices 
  SET is_active = false 
  WHERE user_id = p_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to lookup user by device token
CREATE OR REPLACE FUNCTION get_user_by_spark_token(p_token VARCHAR)
RETURNS TABLE (
  user_id UUID,
  username VARCHAR,
  full_name VARCHAR,
  avatar_url TEXT
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    p.id as user_id,
    p.username,
    p.full_name,
    p.avatar_url
  FROM spark_devices sd
  JOIN profiles p ON p.id = sd.user_id
  WHERE sd.device_token = p_token
    AND sd.is_active = true;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
