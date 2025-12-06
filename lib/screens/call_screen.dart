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
      appSign: "d2dab541744a6fd9318bb74be82c7789f0635d063b774e923afba4249d8a8d4a",
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