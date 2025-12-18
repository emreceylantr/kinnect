// Supabase Edge Function: Push Notification Gönderimi
// Basitleştirilmiş versiyon - HTTP API ile FCM

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface PushPayload {
    target_user_id: string
    title: string
    body: string
    type?: string
    target_id?: string
}

serve(async (req) => {
    if (req.method === 'OPTIONS') {
        return new Response('ok', { headers: corsHeaders })
    }

    try {
        const payload: PushPayload = await req.json()
        const { target_user_id, title, body, type, target_id } = payload

        console.log('🔔 Push isteği alındı:', { target_user_id, title, body })

        // Supabase client
        const supabaseUrl = Deno.env.get('SUPABASE_URL')!
        const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
        const supabase = createClient(supabaseUrl, supabaseKey)

        // Hedef kullanıcının FCM token'ını al
        const { data: profile, error } = await supabase
            .from('profiles')
            .select('fcm_token')
            .eq('id', target_user_id)
            .single()

        console.log('👤 Profil:', profile, 'Hata:', error)

        if (error || !profile?.fcm_token) {
            console.log('❌ FCM token bulunamadı')
            return new Response(
                JSON.stringify({ error: 'FCM token bulunamadı', details: error }),
                { status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
            )
        }

        // Firebase HTTP v1 API için OAuth token al
        const serviceAccountJson = Deno.env.get('FIREBASE_SERVICE_ACCOUNT')
        if (!serviceAccountJson) {
            console.log('❌ FIREBASE_SERVICE_ACCOUNT secret bulunamadı')
            return new Response(
                JSON.stringify({ error: 'FIREBASE_SERVICE_ACCOUNT secret eksik' }),
                { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
            )
        }

        let serviceAccount
        try {
            serviceAccount = JSON.parse(serviceAccountJson)
        } catch (e) {
            console.log('❌ Service account JSON parse hatası:', e)
            return new Response(
                JSON.stringify({ error: 'Service account JSON parse hatası' }),
                { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
            )
        }

        // JWT oluştur
        const now = Math.floor(Date.now() / 1000)
        const header = { alg: 'RS256', typ: 'JWT' }
        const claim = {
            iss: serviceAccount.client_email,
            sub: serviceAccount.client_email,
            aud: 'https://oauth2.googleapis.com/token',
            iat: now,
            exp: now + 3600,
            scope: 'https://www.googleapis.com/auth/firebase.messaging'
        }

        // Base64 encode
        const b64Header = btoa(JSON.stringify(header)).replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_')
        const b64Claim = btoa(JSON.stringify(claim)).replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_')
        const unsignedToken = `${b64Header}.${b64Claim}`

        // RSA imzalama
        const privateKeyPem = serviceAccount.private_key
        const pemContents = privateKeyPem.replace(/-----BEGIN PRIVATE KEY-----/, '').replace(/-----END PRIVATE KEY-----/, '').replace(/\s/g, '')
        const binaryDer = Uint8Array.from(atob(pemContents), c => c.charCodeAt(0))

        const cryptoKey = await crypto.subtle.importKey(
            'pkcs8',
            binaryDer.buffer,
            { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
            false,
            ['sign']
        )

        const signature = await crypto.subtle.sign(
            'RSASSA-PKCS1-v1_5',
            cryptoKey,
            new TextEncoder().encode(unsignedToken)
        )

        const b64Signature = btoa(String.fromCharCode(...new Uint8Array(signature)))
            .replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_')

        const jwt = `${unsignedToken}.${b64Signature}`

        // Access token al
        const tokenResponse = await fetch('https://oauth2.googleapis.com/token', {
            method: 'POST',
            headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
            body: `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=${jwt}`
        })

        const tokenData = await tokenResponse.json()
        console.log('🔑 Token response:', tokenData.access_token ? 'Alındı' : 'Hata', tokenData.error || '')

        if (!tokenData.access_token) {
            return new Response(
                JSON.stringify({ error: 'OAuth token alınamadı', details: tokenData }),
                { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
            )
        }

        // FCM'e push gönder
        const projectId = serviceAccount.project_id || 'kinnect-8fc6b'
        const fcmResponse = await fetch(
            `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
            {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'Authorization': `Bearer ${tokenData.access_token}`,
                },
                body: JSON.stringify({
                    message: {
                        token: profile.fcm_token,
                        notification: {
                            title: title,
                            body: body,
                        },
                        data: {
                            type: type || '',
                            target_id: target_id || '',
                        },
                        apns: {
                            payload: {
                                aps: {
                                    sound: 'default',
                                    badge: 1,
                                }
                            }
                        }
                    }
                }),
            }
        )

        const fcmResult = await fcmResponse.json()
        console.log('📤 FCM Response:', fcmResult)

        return new Response(
            JSON.stringify({ success: true, result: fcmResult }),
            { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )

    } catch (error) {
        console.log('❌ Genel hata:', error.message)
        return new Response(
            JSON.stringify({ error: error.message }),
            { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
    }
})
