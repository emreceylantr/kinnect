// Kinnect - Video Düzenleme Ekranı (Kırpma + Kapak Seçimi)

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

import '../../../core/language/app_l10n.dart';
import '../../../core/theme/app_colors.dart';

class VideoEditResult {
  final File trimmedFile;
  final double thumbnailSeconds;

  const VideoEditResult({
    required this.trimmedFile,
    required this.thumbnailSeconds,
  });
}

class VideoEditScreen extends StatefulWidget {
  final String videoPath;
  final double videoDurationSeconds;

  const VideoEditScreen({
    super.key,
    required this.videoPath,
    required this.videoDurationSeconds,
  });

  @override
  State<VideoEditScreen> createState() => _VideoEditScreenState();
}

class _VideoEditScreenState extends State<VideoEditScreen> {
  static const double _maxTrim = 7.0;
  static const _trimChannel = MethodChannel('com.kinnect.video_trimmer');

  VideoPlayerController? _controller;
  bool _isPlaying = false;
  bool _playerReady = false;
  bool _isProcessing = false;

  late double _startSeconds;
  late double _endSeconds;
  late double _thumbSeconds;

  Uint8List? _thumbPreview;
  Timer? _thumbDebounce;
  Timer? _loopTimer;

  @override
  void initState() {
    super.initState();
    _startSeconds = 0;
    _endSeconds = widget.videoDurationSeconds.clamp(0, _maxTrim);
    _thumbSeconds = 0;
    _initPlayer();
    _scheduleThumbnailUpdate();
  }

  Future<void> _initPlayer() async {
    final ctrl = VideoPlayerController.file(File(widget.videoPath));
    await ctrl.initialize();
    ctrl.setLooping(false);
    await ctrl.seekTo(Duration(milliseconds: (_startSeconds * 1000).toInt()));
    ctrl.addListener(_onVideoProgress);
    if (mounted) {
      setState(() {
        _controller = ctrl;
        _playerReady = true;
      });
    }
  }

  void _onVideoProgress() {
    if (_controller == null || !_controller!.value.isInitialized) return;
    final posMs = _controller!.value.position.inMilliseconds;
    final endMs = (_endSeconds * 1000).toInt();
    if (posMs >= endMs) {
      _controller!.seekTo(Duration(milliseconds: (_startSeconds * 1000).toInt()));
      if (!_isPlaying) _controller!.pause();
    }
  }

  void _togglePlay() {
    if (_controller == null) return;
    if (_isPlaying) {
      _controller!.pause();
    } else {
      _controller!.seekTo(Duration(milliseconds: (_startSeconds * 1000).toInt()));
      _controller!.play();
    }
    setState(() => _isPlaying = !_isPlaying);
  }

  void _scheduleThumbnailUpdate() {
    _thumbDebounce?.cancel();
    _thumbDebounce = Timer(const Duration(milliseconds: 300), () async {
      final data = await VideoThumbnail.thumbnailData(
        video: widget.videoPath,
        timeMs: (_thumbSeconds * 1000).toInt(),
        imageFormat: ImageFormat.JPEG,
        maxHeight: 300,
        quality: 75,
      );
      if (mounted) setState(() => _thumbPreview = data);
    });
  }

  Future<void> _onConfirm() async {
    setState(() => _isProcessing = true);
    _controller?.pause();
    try {
      final trimDuration = (_endSeconds - _startSeconds).clamp(1.0, 60.0);
      final String? outputPath = await _trimChannel.invokeMethod<String>('trim', {
        'path': widget.videoPath,
        'startSeconds': _startSeconds,
        'durationSeconds': trimDuration,
      });

      if (outputPath == null) {
        throw Exception('Kırpma başarısız oldu (çıktı yok)');
      }

      final file = File(outputPath);
      if (!file.existsSync()) {
        throw Exception('Çıktı dosyası bulunamadı');
      }

      if (mounted) {
        Navigator.pop(
          context,
          VideoEditResult(trimmedFile: file, thumbnailSeconds: _thumbSeconds),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${AppL10n.videoProcessError}: $e'),
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 6),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _controller?.removeListener(_onVideoProgress);
    _controller?.dispose();
    _thumbDebounce?.cancel();
    _loopTimer?.cancel();
    super.dispose();
  }

  String _fmt(double sec) {
    final s = sec.toInt();
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }

  String _fmtDecimal(double sec) => '${sec.toStringAsFixed(1)}${AppL10n.secSuffix}';

  void _onRangeChanged(RangeValues vals) {
    double start = vals.start;
    double end = vals.end;
    // Max 20 saniye kısıtla
    if (end - start > _maxTrim) {
      end = start + _maxTrim;
      if (end > widget.videoDurationSeconds) {
        end = widget.videoDurationSeconds;
        start = (end - _maxTrim).clamp(0, end);
      }
    }
    if (end - start < 1) return; // Minimum 1 saniye
    setState(() {
      _startSeconds = start;
      _endSeconds = end;
      // Thumbnail süre de kırpma aralığında kalsın
      _thumbSeconds = _thumbSeconds.clamp(_startSeconds, _endSeconds);
    });
    _controller?.pause();
    _controller?.seekTo(Duration(milliseconds: (start * 1000).toInt()));
    setState(() => _isPlaying = false);
  }

  @override
  Widget build(BuildContext context) {
    final duration = widget.videoDurationSeconds;
    final trimDuration = _endSeconds - _startSeconds;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: Text(AppL10n.cancel,
              style: GoogleFonts.poppins(color: Colors.white70, fontSize: 15)),
        ),
        leadingWidth: 80,
        title: Text(AppL10n.videoEditTitle,
            style: GoogleFonts.poppins(
                color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16)),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _isProcessing ? null : _onConfirm,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _isProcessing
                      ? [Colors.grey, Colors.grey]
                      : [const Color(0xFF6C63FF), const Color(0xFF8A80FF)],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: _isProcessing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : Text(AppL10n.ok,
                      style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14)),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Video Preview ──
            _buildVideoPreview(),

            const SizedBox(height: 24),

            // ── Trim Bölümü ──
            _buildSectionHeader(
              icon: Icons.content_cut_rounded,
              title: AppL10n.trimSection,
              subtitle: AppL10n.maxSecondsSelect(_maxTrim.toInt()),
            ),
            const SizedBox(height: 12),
            _buildTrimBar(duration, trimDuration),

            const SizedBox(height: 28),

            // ── Kapak Seçimi ──
            _buildSectionHeader(
              icon: Icons.image_outlined,
              title: AppL10n.coverSelectTitle,
              subtitle: AppL10n.coverSelectSubtitle,
            ),
            const SizedBox(height: 12),
            _buildThumbnailPicker(duration),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.primary, size: 18),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 15)),
            Text(subtitle,
                style: GoogleFonts.poppins(
                    color: Colors.white38, fontSize: 11)),
          ],
        ),
      ],
    );
  }

  Widget _buildVideoPreview() {
    return GestureDetector(
      onTap: _togglePlay,
      child: Container(
        height: 280,
        decoration: BoxDecoration(
          color: const Color(0xFF111111),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white12),
        ),
        clipBehavior: Clip.hardEdge,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (_playerReady && _controller != null)
              SizedBox.expand(
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: SizedBox(
                    width: _controller!.value.size.width,
                    height: _controller!.value.size.height,
                    child: VideoPlayer(_controller!),
                  ),
                ),
              ),
            // Play/Pause overlay
            AnimatedOpacity(
              opacity: _isPlaying ? 0 : 1,
              duration: const Duration(milliseconds: 200),
              child: Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.play_arrow, color: Colors.white, size: 34),
              ),
            ),
            // Trim info badge
            Positioned(
              bottom: 10,
              left: 12,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${_fmt(_startSeconds)} - ${_fmt(_endSeconds)}  •  ${_fmtDecimal(_endSeconds - _startSeconds)}',
                  style: GoogleFonts.poppins(
                      color: Colors.white, fontSize: 11),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrimBar(double duration, double trimDuration) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: [
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppColors.primary,
              inactiveTrackColor: Colors.white24,
              thumbColor: Colors.white,
              overlayColor: AppColors.primary.withOpacity(0.2),
              thumbShape:
                  const RoundSliderThumbShape(enabledThumbRadius: 10),
              trackHeight: 4,
              rangeThumbShape:
                  const RoundRangeSliderThumbShape(enabledThumbRadius: 10),
              rangeTrackShape: const RoundedRectRangeSliderTrackShape(),
            ),
            child: RangeSlider(
              values: RangeValues(_startSeconds, _endSeconds),
              min: 0,
              max: duration,
              onChanged: _onRangeChanged,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _timeChip(_fmt(_startSeconds), AppL10n.startTime),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _fmtDecimal(trimDuration),
                  style: GoogleFonts.poppins(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13),
                ),
              ),
              _timeChip(_fmt(_endSeconds), AppL10n.endTime),
            ],
          ),
        ],
      ),
    );
  }

  Widget _timeChip(String time, String label) {
    return Column(
      children: [
        Text(time,
            style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 14)),
        Text(label,
            style: GoogleFonts.poppins(
                color: Colors.white38, fontSize: 10)),
      ],
    );
  }

  Widget _buildThumbnailPicker(double duration) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Thumbnail preview
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.grey.shade900,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.primary, width: 2),
                ),
                clipBehavior: Clip.hardEdge,
                child: _thumbPreview != null
                    ? Image.memory(_thumbPreview!, fit: BoxFit.cover)
                    : const Center(
                        child: Icon(Icons.image_outlined,
                            color: Colors.white38, size: 32)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppL10n.coverFrame,
                      style: GoogleFonts.poppins(
                          color: Colors.white, fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _fmtDecimal(_thumbSeconds),
                      style: GoogleFonts.poppins(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                          fontSize: 16),
                    ),
                    Text(
                      AppL10n.slideToSelectFrame,
                      style: GoogleFonts.poppins(
                          color: Colors.white38, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppColors.primary,
              inactiveTrackColor: Colors.white24,
              thumbColor: Colors.white,
              overlayColor: AppColors.primary.withOpacity(0.2),
              thumbShape:
                  const RoundSliderThumbShape(enabledThumbRadius: 10),
              trackHeight: 3,
            ),
            child: Slider(
              value: _thumbSeconds,
              min: 0,
              max: duration,
              onChanged: (val) {
                setState(() => _thumbSeconds = val);
                _scheduleThumbnailUpdate();
              },
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_fmt(0),
                  style: GoogleFonts.poppins(
                      color: Colors.white38, fontSize: 11)),
              Text(_fmt(duration),
                  style: GoogleFonts.poppins(
                      color: Colors.white38, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }
}
