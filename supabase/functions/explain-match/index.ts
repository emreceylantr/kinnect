import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
    if (req.method === 'OPTIONS') {
        return new Response('ok', { headers: corsHeaders })
    }

    try {
        const { user1_name, user2_name, match_pairs } = await req.json()

        const googleApiKey = Deno.env.get('GOOGLE_API_KEY')
        if (!googleApiKey) {
            throw new Error('GOOGLE_API_KEY is not set')
        }

        const prompt = `
      Sen kıdemli bir "Eşleşme Analisti" ve "İnsan İlişkileri Uzmanı"sın. Sana iki kullanıcının birbirine benzer bulunan paylaşımlarını getirdim. 
      Bu verileri kullanarak bu iki kişinin neden birbirine uygun olduğunu BÜTÜNSEL bir bakış açısıyla açıkla.
      
      Veri Kümesi (Eşleşen Çiftler):
      ${match_pairs.map((pair: string) => `- ${pair}`).join("\n")}
      
      ANALİZ KURALLARI:
      1. Sadece tek bir postta boğulma, genel bir tema bulmaya çalış (Örn: "ikiniz de doğayı ve açık hava aktivitelerini seviyorsunuz").
      2. Eğer verilerde çok bariz bir benzerlik varsa (örn: ikisi de balık tutuyorsa) bunu mutlaka vurgula.
      3. Dilin inanılmaz samimi, neşeli ve arkadaş canlısı olsun.
      4. "İçerik yok", "Vektör", "Embed", "AI" gibi teknik terimleri asla kullanma.
      5. "Seninle ${user2_name} arasında harika bir bağ görüyorum!" gibi doğrudan hitap et.
      6. Cevabın en fazla 3 cümle olsun ve mutlaka somut bir benzerliğe dayanmalı.
      
      Eşleşme Analizi (Kullanıcıya özel not):
    `;

        const url = `https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=${googleApiKey}`;
        const response = await fetch(url, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                contents: [{
                    parts: [{ text: prompt }]
                }],
                // Güvenlik ayarlarını biraz gevşelterek reddedilme olasılığını azaltıyoruz
                safetySettings: [
                    { category: "HARM_CATEGORY_HARASSMENT", threshold: "BLOCK_NONE" },
                    { category: "HARM_CATEGORY_HATE_SPEECH", threshold: "BLOCK_NONE" },
                    { category: "HARM_CATEGORY_SEXUALLY_EXPLICIT", threshold: "BLOCK_ONLY_HIGH" },
                    { category: "HARM_CATEGORY_DANGEROUS_CONTENT", threshold: "BLOCK_ONLY_HIGH" }
                ]
            })
        });

        const data = await response.json();
        const explanation = data.candidates?.[0]?.content?.parts?.[0]?.text || "İkinizin paylaşımlarında harika bir ortak ruh yakaladım; paylaşımlarınızdaki bu samimi atmosfer üzerine sohbet etmeye ne dersiniz?";

        return new Response(JSON.stringify({ explanation: explanation.trim() }), {
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
            status: 200,
        })
    } catch (error) {
        return new Response(JSON.stringify({ error: error.message }), {
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
            status: 500,
        })
    }
})
