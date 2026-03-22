import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../core/language/app_l10n.dart';
import '../../data/services/location_service.dart';

class LocationPickerSheet extends StatefulWidget {
  final Function(String) onLocationSelected;

  const LocationPickerSheet({super.key, required this.onLocationSelected});

  @override
  State<LocationPickerSheet> createState() => _LocationPickerSheetState();
}

class _LocationPickerSheetState extends State<LocationPickerSheet> {
  bool _isGettingLocation = false;
  final TextEditingController _manualController = TextEditingController();

  Future<void> _handleAutoLocation() async {
    setState(() => _isGettingLocation = true);
    final location = await LocationService().getCurrentLocationName();
    setState(() => _isGettingLocation = false);

    if (location != null) {
      widget.onLocationSelected(location);
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(AppL10n.locationPermissionError)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            AppL10n.addLocation,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          ListTile(
            leading: const Icon(Icons.my_location, color: AppColors.primary),
            title: Text(AppL10n.useCurrentLocation,
                style: GoogleFonts.poppins(color: Colors.white)),
            subtitle: Text(AppL10n.autoDetects,
                style:
                    GoogleFonts.poppins(color: Colors.white54, fontSize: 12)),
            trailing: _isGettingLocation
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : null,
            onTap: _isGettingLocation ? null : _handleAutoLocation,
          ),
          const Divider(color: Colors.white10),
          ListTile(
            leading:
                const Icon(Icons.edit_location_alt, color: Colors.orangeAccent),
            title: Text(AppL10n.enterManualLocation,
                style: GoogleFonts.poppins(color: Colors.white)),
            onTap: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: AppColors.bgCard,
                  title: Text(AppL10n.enterLocation,
                      style: GoogleFonts.poppins(color: Colors.white)),
                  content: TextField(
                    controller: _manualController,
                    autofocus: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: AppL10n.locationPlaceholder,
                      hintStyle: TextStyle(color: Colors.white24),
                    ),
                  ),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: Text(AppL10n.cancel)),
                    TextButton(
                      onPressed: () {
                        if (_manualController.text.trim().isNotEmpty) {
                          widget.onLocationSelected(
                              _manualController.text.trim());
                          Navigator.pop(ctx);
                          Navigator.pop(context);
                        }
                      },
                      child: Text(AppL10n.addLabel),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
