import 'package:flutter/material.dart';
import 'package:zego_uikit_prebuilt_call/zego_uikit_prebuilt_call.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CallScreen extends StatelessWidget {
  final String callId;
  final String otherUserName;
  final bool isVideo;

  const CallScreen({
    super.key,
    required this.callId,
    required this.otherUserName,
    this.isVideo = false,
  });

  @override
  Widget build(BuildContext context) {
    final currentUser = Supabase.instance.client.auth.currentUser;
    final userName = currentUser?.userMetadata?['full_name'] ?? currentUser?.email?.split('@')[0] ?? 'Kullanıcı';
    final userId = currentUser?.id ?? 'unknown_user';

    return ZegoUIKitPrebuiltCall(
      // --- APP ID ve APP SIGN BURAYA ---
      appID: 1191288890,
      appSign: "REDACTED_ZEGO_APP_SIGN",
      // -------------------------------

      userID: userId,
      userName: userName,
      callID: callId,

      config: isVideo
          ? ZegoUIKitPrebuiltCallConfig.oneOnOneVideoCall()
          : ZegoUIKitPrebuiltCallConfig.oneOnOneVoiceCall(),
    );
  }
}