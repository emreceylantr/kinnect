import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

serve(async () => {
  const url = Deno.env.get('SUPABASE_DB_URL') ?? ''
  if (!url) return new Response('no db url', { status: 500 })

  const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''

  const { Client } = await import("https://deno.land/x/postgres@v0.17.0/mod.ts")
  const client = new Client(url)
  await client.connect()

  // Add social_style column
  await client.queryArray(`
    ALTER TABLE user_profiles
      ADD COLUMN IF NOT EXISTS social_style text;
  `)

  // Drop DB HTTP triggers — analyze-user-profile is called from Flutter after post creation.
  await client.queryArray(`DROP TRIGGER IF EXISTS on_post_insert_analyze_profile ON posts;`)
  await client.queryArray(`DROP FUNCTION IF EXISTS trigger_analyze_user_profile();`)
  await client.queryArray(`DROP TRIGGER IF EXISTS on_new_post_generate_embedding ON posts;`)
  await client.queryArray(`DROP FUNCTION IF EXISTS call_generate_embedding();`)

  // Add photo_scene_tags and mentioned_usernames columns to posts
  await client.queryArray(`
    ALTER TABLE posts ADD COLUMN IF NOT EXISTS photo_scene_tags text[] DEFAULT '{}';
  `)

  await client.queryArray(`
    ALTER TABLE posts ADD COLUMN IF NOT EXISTS mentioned_usernames text[] DEFAULT '{}';
  `)

  await client.queryArray(`
    ALTER TABLE posts ADD COLUMN IF NOT EXISTS video_url text;
  `)

  await client.queryArray(`
    ALTER TABLE posts ADD COLUMN IF NOT EXISTS video_frame_urls text[] DEFAULT '{}';
  `)

  await client.queryArray(`
    ALTER TABLE user_profiles ADD COLUMN IF NOT EXISTS quiz_answers jsonb;
  `)

  await client.end()
  return new Response('migration ok: social_style + trigger + photo_scene_tags + mentioned_usernames + video + quiz_answers', { status: 200 })
})
