// Kinnect - E-posta ile giriş ekranı

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../main/home_screen.dart';
import 'create_profile_screen.dart';
import 'forgot_password_screen.dart';
import '../../services/auth_service.dart';

// 🎨 TEMA
const Color kBgDark = Color(0xFF06060A);
const Color kCardDark = Color(0xFF12121A);
const Color kAccentPurple = Color(0xFF7C3AED);
const Color kAccentViolet = Color(0xFF8B5CF6);

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;

  final AuthService _authService = AuthService();
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();

      await _authService.signInWithEmail(email, password);

      final user = Supabase.instance.client.auth.currentUser;
      final userId = user?.id;

      if (userId == null) {
        throw 'Giriş yapıldı ama kullanıcı bilgisi alınamadı.';
      }

      final profileData = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (!mounted) return;

      if (profileData != null) {
        final bool is2FaEnabled = profileData['is_2fa_enabled'] ?? false;
        final String? phone = profileData['phone'];

        if (is2FaEnabled && phone != null && phone.isNotEmpty) {
          await Supabase.instance.client.auth.signInWithOtp(phone: phone);
          setState(() => _isLoading = false);
          _showOtpDialog(phone);
          return;
        }

        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (route) => false,
        );
      } else {
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
              backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted && _isLoading) setState(() => _isLoading = false);
    }
  }

  void _showOtpDialog(String phone) {
    final otpController = TextEditingController();
    bool isVerifying = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: kCardDark,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24)),
              title: Text(
                "Güvenlik Doğrulaması",
                style: GoogleFonts.spaceGrotesk(
                    color: Colors.white, fontWeight: FontWeight.bold),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "Hesabınızda 2FA aktif. ($phone) numarasına gelen 6 haneli kodu giriniz.",
                    style:
                        GoogleFonts.inter(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: otpController,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    style: GoogleFonts.spaceGrotesk(
                        color: Colors.white, fontSize: 24, letterSpacing: 8),
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      hintText: "000000",
                      hintStyle:
                          TextStyle(color: Colors.white.withOpacity(0.2)),
                      counterText: "",
                      filled: true,
                      fillColor: kBgDark,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide:
                            const BorderSide(color: kAccentPurple, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isVerifying ? null : () => Navigator.pop(context),
                  child: Text("İptal",
                      style: GoogleFonts.inter(color: Colors.white54)),
                ),
                GestureDetector(
                  onTap: isVerifying
                      ? null
                      : () async {
                          final code = otpController.text.trim();
                          if (code.length != 6) return;

                          setStateDialog(() => isVerifying = true);

                          try {
                            final response =
                                await Supabase.instance.client.auth.verifyOTP(
                              phone: phone,
                              token: code,
                              type: OtpType.sms,
                            );

                            if (response.session != null && mounted) {
                              Navigator.pop(context);
                              Navigator.of(context).pushAndRemoveUntil(
                                MaterialPageRoute(
                                    builder: (_) => const HomeScreen()),
                                (route) => false,
                              );
                            }
                          } catch (e) {
                            setStateDialog(() => isVerifying = false);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text("Hatalı kod: $e"),
                                  backgroundColor: Colors.red),
                            );
                          }
                        },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [kAccentPurple, kAccentViolet]),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: isVerifying
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : Text("Doğrula",
                            style: GoogleFonts.inter(
                                color: Colors.white,
                                fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgDark,
      body: Stack(
        children: [
          // Glow
          Positioned(
            top: -150,
            left: -100,
            right: -100,
            child: AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                return Container(
                  height: 400,
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      radius: 0.6 + _pulseController.value * 0.1,
                      colors: [
                        kAccentPurple.withOpacity(0.2),
                        Colors.transparent,
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // AppBar
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color: Colors.white.withOpacity(0.1)),
                          ),
                          child: const Icon(Icons.arrow_back_ios_new_rounded,
                              color: Colors.white, size: 18),
                        ),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 30),

                          // Header
                          Text(
                            "Tekrar\nHoş Geldin",
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 38,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            "Kaldığın yerden devam et.",
                            style: GoogleFonts.inter(
                                fontSize: 15,
                                color: Colors.white.withOpacity(0.5)),
                          ),

                          const SizedBox(height: 50),

                          // E-posta
                          _buildTextField(
                            controller: _emailController,
                            label: "E-posta Adresi",
                            icon: FontAwesomeIcons.envelope,
                            validator: (value) =>
                                (value == null || value.isEmpty)
                                    ? 'E-posta gerekli'
                                    : null,
                          ),
                          const SizedBox(height: 18),

                          // Şifre
                          _buildTextField(
                            controller: _passwordController,
                            label: "Şifre",
                            icon: FontAwesomeIcons.lock,
                            isPassword: true,
                            validator: (value) =>
                                (value == null || value.isEmpty)
                                    ? 'Şifre gerekli'
                                    : null,
                          ),

                          // Şifremi unuttum
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () {
                                Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) =>
                                            const ForgotPasswordScreen()));
                              },
                              child: Text(
                                "Şifreni mi unuttun?",
                                style: GoogleFonts.inter(
                                    color: kAccentPurple,
                                    fontWeight: FontWeight.w500),
                              ),
                            ),
                          ),

                          const SizedBox(height: 30),

                          // Giriş butonu
                          GestureDetector(
                            onTap: _isLoading ? null : _signIn,
                            child: Container(
                              width: double.infinity,
                              height: 58,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                    colors: [kAccentPurple, kAccentViolet]),
                                borderRadius: BorderRadius.circular(18),
                                boxShadow: [
                                  BoxShadow(
                                    color: kAccentPurple.withOpacity(0.4),
                                    blurRadius: 20,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: _isLoading
                                    ? const CircularProgressIndicator(
                                        color: Colors.white, strokeWidth: 2.5)
                                    : Text(
                                        "Giriş Yap",
                                        style: GoogleFonts.inter(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
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
      style: GoogleFonts.inter(color: Colors.white),
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.inter(color: Colors.white.withOpacity(0.4)),
        prefixIcon: Padding(
          padding: const EdgeInsets.all(14),
          child: FaIcon(icon, color: kAccentPurple, size: 18),
        ),
        suffixIcon: isPassword
            ? IconButton(
                icon: FaIcon(
                  _obscurePassword
                      ? FontAwesomeIcons.eyeSlash
                      : FontAwesomeIcons.eye,
                  color: Colors.white38,
                  size: 18,
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              )
            : null,
        filled: true,
        fillColor: kCardDark,
        contentPadding:
            const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: kAccentPurple, width: 1.5),
        ),
        errorStyle: GoogleFonts.inter(color: Colors.redAccent, fontSize: 12),
      ),
    );
  }
}
