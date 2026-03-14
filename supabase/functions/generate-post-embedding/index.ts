import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

// CORS headers for Edge Functions
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  // Handle CORS preflight options
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // 1. Get Params from request
    const { record } = await req.json()
    console.log("Incoming Record:", JSON.stringify(record));

    // Safety check
    if (!record || !record.id) {
      return new Response(JSON.stringify({ error: 'No record provided', received: record }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 400,
      })
    }

    const postId = record.id
    const userId = record.user_id
    const content = record.content || ""
    const imageUrl = record.image_url // Assuming the primary image URL
    console.log(`Extracted Details - ID: ${postId}, Image: ${imageUrl}`);

    // 2. Initialize Supabase Admin Client to bypass RLS and insert into post_embeddings
    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    const supabase = createClient(supabaseUrl, supabaseServiceKey)

    // 3. Connect to Google Gemini
    const googleApiKey = Deno.env.get('GOOGLE_API_KEY')
    if (!googleApiKey) {
      throw new Error('GOOGLE_API_KEY is not set in Edge Function secrets')
    }

    console.log(`Processing Post ID: ${postId} with Gemini`);

    let aiSummary = content;
    let visionDescription = "";

    // 4. Image Analysis with Gemini 1.5 Flash
    if (imageUrl) {
      console.log(`Analyzing Image with Gemini: ${imageUrl}`);
      try {
        // First, fetch the image to send to Gemini
        const imgResp = await fetch(imageUrl);
        if (!imgResp.ok) {
          throw new Error(`Failed to fetch image: ${imgResp.statusText}`);
        }
        const imgData = await imgResp.arrayBuffer();

        // CORRECT base64 encoding for ArrayBuffer
        const uint8 = new Uint8Array(imgData);
        let binaryString = "";
        for (let i = 0; i < uint8.length; i++) {
          binaryString += String.fromCharCode(uint8[i]);
        }
        const base64Img = btoa(binaryString);

        const visionUrl = `https://generativelanguage.googleapis.com/v1beta/models/gemini-flash-latest:generateContent?key=${googleApiKey}`;
        const visionResponse = await fetch(visionUrl, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            contents: [{
              parts: [
                {
                  text: `GÖREV: Fotoğrafı analiz et.
                KURALLAR:
                - Kullanıcının notunu (${content}) tekrar etme.
                - Fotoğraftaki nesneleri, ortamı ve insanların ne yaptığını anlat.
                - Max 3 cümle.` },
                { inline_data: { mime_type: "image/jpeg", data: base64Img } }
              ]
            }]
          })
        });

        const visionData = await visionResponse.json();

        if (visionData.candidates && visionData.candidates[0]?.content?.parts?.[0]?.text) {
          visionDescription = visionData.candidates[0].content.parts[0].text;
          console.log(`Gemini Vision Result: ${visionDescription}`);
          aiSummary = `Görsel: ${visionDescription}. Not: ${content}`;
        } else {
          const errorMsg = visionData.error?.message || visionData.feedback?.reason || JSON.stringify(visionData);
          console.error("Gemini Vision failed:", errorMsg);
          aiSummary = `Vision Hatası: ${errorMsg.substring(0, 200)} | Not: ${content}`;
        }
      } catch (err) {
        console.error("Gemini Vision process failed:", err);
        aiSummary = `Vision Catch: ${err.message} | Not: ${content}`;
      }
    }

    // 5. Generate Vector Embeddings
    console.log("Generating Gemini Embedding...");
    if (!aiSummary || aiSummary.trim() === "") {
      aiSummary = "İçerik yok.";
    }

    const embedUrl = `https://generativelanguage.googleapis.com/v1beta/models/gemini-embedding-001:embedContent?key=${googleApiKey}`;
    const embedResponse = await fetch(embedUrl, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        model: "models/gemini-embedding-001",
        content: { parts: [{ text: aiSummary }] },
        outputDimensionality: 768
      })
    });

    const embedData = await embedResponse.json();
    if (embedData.error) throw new Error(`Embedding failed: ${embedData.error.message}`);

    const embeddingVector = embedData.embedding.values;

    // 6. Save to Supabase Vector DB (Manual upsert)
    console.log("Saving to Supabase post_embeddings table...");

    // First, remove existing entry if any
    await supabase
      .from('post_embeddings')
      .delete()
      .eq('post_id', postId);

    // Then, insert new entry
    const { error: dbError } = await supabase
      .from('post_embeddings')
      .insert({
        post_id: postId,
        user_id: userId,
        embedding: embeddingVector,
        content_summary: aiSummary
      });

    if (dbError) throw dbError;

    return new Response(
      JSON.stringify({
        success: true,
        aiSummary,
        dimensions: embeddingVector.length,
        received_record: record
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 }
    );
  } catch (error) {
    console.error("Error in generate-post-embedding:", error)

    return new Response(JSON.stringify({ error: error.message }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 500,
    })
  }
})
