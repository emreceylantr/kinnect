// Supabase Edge Function: Push Notification Gönderimi
// Firebase Cloud Messaging API v1 kullanıyor

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

// Google OAuth2 Access Token alma
async function getAccessToken(): Promise<string> {
    const serviceAccount = JSON.parse(Deno.env.get('FIREBASE_SERVICE_ACCOUNT') || '{}')

    const now = Math.floor(Date.now() / 1000)
    const payload = {
        iss: serviceAccount.client_email,
        sub: serviceAccount.client_email,
        aud: 'https://oauth2.googleapis.com/token',
        iat: now,
        exp: now + 3600,
        scope: 'https://www.googleapis.com/auth/firebase.messaging'
    }

    // JWT oluştur
    const encoder = new TextEncoder()
    const header = btoa(JSON.stringify({ alg: 'RS256', typ: 'JWT' }))
    const payloadB64 = btoa(JSON.stringify(payload))

    const key = await crypto.subtle.importKey(
        'pkcs8',
        pemToBinary(serviceAccount.private_key),
        { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
        false,
        ['sign']
    )

    const signature = await crypto.subtle.sign(
        'RSASSA-PKCS1-v1_5',
        key,
        encoder.encode(`${header}.${payloadB64}`)
    )

    const jwt = `${header}.${payloadB64}.${btoa(String.fromCharCode(...new Uint8Array(signature)))}`

    // Access token al
    const tokenResponse = await fetch('https://oauth2.googleapis.com/token', {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body: `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=${jwt}`
    })

    const tokenData = await tokenResponse.json()
    return tokenData.access_token
}

function pemToBinary(pem: string): ArrayBuffer {
    const b64 = pem.replace(/-----BEGIN PRIVATE KEY-----/, '')
        .replace(/-----END PRIVATE KEY-----/, '')
        .replace(/\s/g, '')
    const binary = atob(b64)
    const bytes = new Uint8Array(binary.length)
    for (let i = 0; i < binary.length; i++) {
        bytes[i] = binary.charCodeAt(i)
    }
    return bytes.buffer
}

serve(async (req) => {
    if (req.method === 'OPTIONS') {
        return new Response('ok', { headers: corsHeaders })
    }

    try {
        const payload: PushPayload = await req.json()
        const { target_user_id, title, body, type, target_id } = payload

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

        if (error || !profile?.fcm_token) {
            return new Response(
                JSON.stringify({ error: 'FCM token bulunamadı', details: error }),
                { status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
            )
        }

        // Firebase'e push gönder (v1 API)
        const projectId = Deno.env.get('FIREBASE_PROJECT_ID') || 'kinnect-8fc6b'
        const accessToken = await getAccessToken()

        const fcmResponse = await fetch(
            `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
            {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'Authorization': `Bearer ${accessToken}`,
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

        return new Response(
            JSON.stringify({ success: true, result: fcmResult }),
            { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )

    } catch (error) {
        return new Response(
            JSON.stringify({ error: error.message }),
            { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
    }
})
