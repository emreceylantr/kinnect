-- Post insert/update should stay fast. Profile analysis is triggered from Flutter
-- after the post is created, so old database HTTP triggers only add timeout risk.
DROP TRIGGER IF EXISTS on_new_post_generate_embedding ON public.posts;
DROP FUNCTION IF EXISTS public.call_generate_embedding();

DROP TRIGGER IF EXISTS on_post_insert_analyze_profile ON public.posts;
DROP FUNCTION IF EXISTS public.trigger_analyze_user_profile();
