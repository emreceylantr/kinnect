import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';

class PostReportDialog extends StatelessWidget {
  final Function(String reason, String? description) onReportSubmit;

  const PostReportDialog({super.key, required this.onReportSubmit});

  static void show(BuildContext context,
      {required Function(String reason, String? description) onReportSubmit}) {
    showDialog(
      context: context,
      builder: (ctx) => PostReportDialog(onReportSubmit: onReportSubmit),
    );
  }

  @override
  Widget build(BuildContext context) {
    final reasons = [
      "Spam veya Yanıltıcı",
      "Çıplaklık veya Cinsellik",
      "Nefret Söylemi",
      "Şiddet veya Tehlikeli",
      "Zorbalık veya Taciz",
      "Diğer"
    ];

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
            color: AppColors.bgCardLight,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
                color: Colors.white.withValues(alpha: 0.08), width: 1),
            boxShadow: [
              BoxShadow(
                  color: AppColors.bgBlack.withValues(alpha: 0.5),
                  blurRadius: 20,
                  spreadRadius: 5)
            ]),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Şikayet Et",
                style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text("Bu gönderiyi neden bildiriyorsun?",
                style:
                    GoogleFonts.poppins(color: Colors.white54, fontSize: 11)),
            const SizedBox(height: 20),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  children: List.generate(reasons.length, (index) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: InkWell(
                        onTap: () {
                          Navigator.pop(context);
                          _showReportDetailsDialog(context, reasons[index]);
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.03),
                              borderRadius: BorderRadius.circular(12)),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(reasons[index],
                                  style: GoogleFonts.poppins(
                                      color: Colors.white70, fontSize: 12.5)),
                              const Icon(Icons.arrow_forward_ios_rounded,
                                  color: Colors.white24, size: 12),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12))),
                child: Text("Vazgeç",
                    style: GoogleFonts.poppins(
                        color: Colors.white38, fontSize: 13)),
              ),
            )
          ],
        ),
      ),
    );
  }

  void _showReportDetailsDialog(BuildContext context, String reason) {
    final TextEditingController detailsController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
              color: AppColors.bgCardLight,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.08), width: 1),
              boxShadow: [
                BoxShadow(
                    color: AppColors.bgBlack.withValues(alpha: 0.5),
                    blurRadius: 20,
                    spreadRadius: 5)
              ]),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                  child: Text("Ek Açıklama",
                      style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600))),
              const SizedBox(height: 15),
              Text("Seçilen: $reason",
                  style: GoogleFonts.poppins(
                      color: AppColors.accentOrange, fontSize: 12)),
              const SizedBox(height: 5),
              Text("Detay eklemek istersen aşağıya yazabilirsin.",
                  style:
                      GoogleFonts.poppins(color: Colors.white54, fontSize: 12)),
              const SizedBox(height: 15),
              TextField(
                controller: detailsController,
                style: GoogleFonts.poppins(color: Colors.white, fontSize: 14),
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: "Buraya yaz...",
                  hintStyle:
                      GoogleFonts.poppins(color: Colors.white24, fontSize: 14),
                  filled: true,
                  fillColor: Colors.black26,
                  contentPadding: const EdgeInsets.all(12),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12))),
                      child: Text("Vazgeç",
                          style: GoogleFonts.poppins(
                              color: Colors.white38, fontSize: 13)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        onReportSubmit(reason, detailsController.text.trim());
                      },
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          elevation: 0),
                      child: Text("Gönder",
                          style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13)),
                    ),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}
