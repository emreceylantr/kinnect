import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

// Yeni post geldiğinde analyze-user-profile'ı tetikler
serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { record } = await req.json()
    if (!record?.id || !record?.user_id) {
      return new Response(JSON.stringify({ error: 'Geçersiz kayıt' }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 400,
      })
    }

    console.log(`Yeni post: ${record.id} → kullanıcı profili güncelleniyor`)

    const supabaseUrl        = Deno.env.get('SUPABASE_URL') ?? ''
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    const supabase           = createClient(supabaseUrl, supabaseServiceKey)

    // analyze-user-profile fonksiyonunu çağır
    const response = await supabase.functions.invoke('analyze-user-profile', {
      body: { user_id: record.user_id },
    })

    if (response.error) throw response.error

    console.log(`✅ Profil güncellendi: ${JSON.stringify(response.data)}`)

    return new Response(
      JSON.stringify({ success: true, ...response.data }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 }
    )

  } catch (error) {
    console.error("generate-post-embedding hatası:", error)
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 500,
    })
  }
})
