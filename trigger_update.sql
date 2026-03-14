-- Trigger'ı UPDATE işlemini de kapsayacak şekilde güncelle
DROP TRIGGER IF EXISTS on_new_post_generate_embedding ON public.posts;

CREATE TRIGGER on_new_post_generate_embedding
  AFTER INSERT OR UPDATE ON public.posts
  FOR EACH ROW
  EXECUTE FUNCTION public.call_generate_embedding();

-- Tüm postları tetiklemek için no-op update yap
UPDATE public.posts SET content = content;
