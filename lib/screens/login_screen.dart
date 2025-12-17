import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'home_screen.dart';
import 'create_profile_screen.dart';
import 'forgot_password_screen.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;

  final AuthService _authService = AuthService();

  // --- GİRİŞ YAP FONKSİYONU (GÜNCELLENDİ 🔥) ---
  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();

      // 1. E-posta ve şifre ile giriş yap
      await _authService.signInWithEmail(email, password);

      final user = Supabase.instance.client.auth.currentUser;
      final userId = user?.id;

      if (userId == null) {
        throw 'Giriş yapıldı ama kullanıcı bilgisi alınamadı.';
      }

      // 2. Kullanıcının profilini ve 2FA durumunu çek
      final profileData = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (!mounted) return;

      if (profileData != null) {
        final bool is2FaEnabled = profileData['is_2fa_enabled'] ?? false;
        final String? phone = profileData['phone'];

        // 🔥 2FA KONTROLÜ BAŞLANGIÇ 🔥
        if (is2FaEnabled && phone != null && phone.isNotEmpty) {
          // Eğer 2FA açıksa:
          // A. Kullanıcıya SMS gönder
          await Supabase.instance.client.auth.signInWithOtp(phone: phone);

          setState(() => _isLoading = false); // Loading'i durdur ki dialog açılsın

          // B. Kod girme pencresini aç
          _showOtpDialog(phone);

          return; // 🛑 Fonksiyonu burada durdur, gerisini Dialog halledecek.
        }
        // 🔥 2FA KONTROLÜ BİTİŞ 🔥

        // Eğer 2FA kapalıysa normal akışa devam et:
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
              (route) => false,
        );
      } else {
        // Profil yoksa oluşturmaya git
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const CreateProfileScreen()),
              (route) => false,
        );
      }

    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.message.contains("Email not confirmed")
                  ? "Lütfen e-posta adresinizi onaylayın."
                  : "Giriş Hatası: ${e.message}",
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Bir hata oluştu: $e"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      // Sadece 2FA devreye girmediyse loading'i kapat (2FA girerse dialog içinde kapanır)
      if (mounted && _isLoading) setState(() => _isLoading = false);
    }
  }

  // --- 🔥 YENİ EKLENEN 2FA KOD DOĞRULAMA PENCERESİ ---
  void _showOtpDialog(String phone) {
    final otpController = TextEditingController();
    bool isVerifying = false;

    showDialog(
      context: context,
      barrierDismissible: false, // Boşluğa basınca kapanmasın
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1A1A1A),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text(
                "Güvenlik Doğrulaması",
                style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "Hesabınızda 2 Adımlı Doğrulama aktif. Telefonunuza ($phone) gelen 6 haneli kodu giriniz.",
                    style: GoogleFonts.poppins(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: otpController,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    style: const TextStyle(color: Colors.white, fontSize: 18, letterSpacing: 4),
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      hintText: "000000",
                      hintStyle: const TextStyle(color: Colors.white24),
                      counterText: "",
                      filled: true,
                      fillColor: const Color(0xFF2A2A2A),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF6C63FF), width: 1.5),
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isVerifying ? null : () => Navigator.pop(context),
                  child: const Text("İptal", style: TextStyle(color: Colors.redAccent)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6C63FF),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: isVerifying
                      ? null
                      : () async {
                    final code = otpController.text.trim();
                    if (code.length != 6) return;

                    setStateDialog(() => isVerifying = true);

                    try {
                      // Kodu Doğrula
                      final response = await Supabase.instance.client.auth.verifyOTP(
                        phone: phone,
                        token: code,
                        type: OtpType.sms,
                      );

                      if (response.session != null && mounted) {
                        Navigator.pop(context); // Dialogu kapat

                        // Ana Sayfaya Yönlendir
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(builder: (_) => const HomeScreen()),
                              (route) => false,
                        );
                      }
                    } catch (e) {
                      setStateDialog(() => isVerifying = false);
                      ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("Hatalı kod: $e"), backgroundColor: Colors.red)
                      );
                    }
                  },
                  child: isVerifying
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text("Doğrula", style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const FaIcon(
                FontAwesomeIcons.chevronLeft,
                color: Colors.white,
                size: 18,
              ),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Tekrar Hoş Geldin",
                  style: GoogleFonts.poppins(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  "Kaldığın yerden devam et.",
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.white54,
                  ),
                ),
                const SizedBox(height: 40),

                // E-POSTA ALANI
                _buildTextField(
                  controller: _emailController,
                  label: "E-posta Adresi",
                  icon: FontAwesomeIcons.envelope,
                  validator: (value) =>
                  (value == null || value.isEmpty) ? 'E-posta gerekli' : null,
                ),
                const SizedBox(height: 20),

                // ŞİFRE ALANI
                _buildTextField(
                  controller: _passwordController,
                  label: "Şifre",
                  icon: FontAwesomeIcons.lock,
                  isPassword: true,
                  validator: (value) =>
                  (value == null || value.isEmpty) ? 'Şifre gerekli' : null,
                ),

                // Şifremi Unuttum Linki
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ForgotPasswordScreen(),
                        ),
                      );
                    },
                    child: Text(
                      "Şifreni mi unuttun?",
                      style: GoogleFonts.poppins(color: const Color(0xFF6C63FF)),
                    ),
                  ),
                ),

                const SizedBox(height: 30),

                // GİRİŞ YAP BUTONU
                Container(
                  width: double.infinity,
                  height: 60,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6C63FF), Color(0xFF4834D4)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF6C63FF).withOpacity(0.4),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      )
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _signIn,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(
                      "Giriş Yap",
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isPassword = false,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword ? _obscurePassword : false,
      style: GoogleFonts.poppins(color: Colors.white),
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.poppins(color: Colors.white54),
        prefixIcon: Padding(
          padding: const EdgeInsets.all(12),
          child: FaIcon(
            icon,
            color: const Color(0xFF6C63FF),
            size: 20,
          ),
        ),
        suffixIcon: isPassword
            ? IconButton(
          icon: FaIcon(
            _obscurePassword
                ? FontAwesomeIcons.eyeSlash
                : FontAwesomeIcons.eye,
            color: Colors.white54,
            size: 20,
          ),
          onPressed: () =>
              setState(() => _obscurePassword = !_obscurePassword),
        )
            : null,
        filled: true,
        fillColor: const Color(0xFF151515),
        contentPadding:
        const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide:
          const BorderSide(color: Color(0xFF6C63FF), width: 1.5),
        ),
        errorStyle: const TextStyle(color: Colors.redAccent),
      ),
    );
  }
}