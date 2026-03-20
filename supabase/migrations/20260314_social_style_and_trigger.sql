-- Add social_style column to user_profiles
ALTER TABLE user_profiles
  ADD COLUMN IF NOT EXISTS social_style text;

-- Enable pg_net extension (required for HTTP calls from triggers)
CREATE EXTENSION IF NOT EXISTS pg_net;

-- Function: call analyze-user-profile edge function when a post is inserted
CREATE OR REPLACE FUNCTION trigger_analyze_user_profile()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  edge_url text;
  service_key text;
BEGIN
  edge_url := current_setting('app.supabase_url', true) || '/functions/v1/analyze-user-profile';
  service_key := current_setting('app.service_role_key', true);

  -- Fire-and-forget: don't block the INSERT
  PERFORM net.http_post(
    url     := edge_url,
    headers := jsonb_build_object(
      'Content-Type',  'application/json',
      'Authorization', 'Bearer ' || service_key
    ),
    body    := jsonb_build_object('user_id', NEW.user_id)
  );

  RETURN NEW;
END;
$$;

-- Trigger: runs AFTER INSERT on posts (once per row, async via pg_net)
DROP TRIGGER IF EXISTS on_post_insert_analyze_profile ON posts;
CREATE TRIGGER on_post_insert_analyze_profile
  AFTER INSERT ON posts
  FOR EACH ROW
  EXECUTE FUNCTION trigger_analyze_user_profile();
