import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:video_player/video_player.dart';
import '../../../core/language/app_l10n.dart';

// Result: {'video_file': File, 'start_ms': int}
class LivePhotoPickerScreen extends StatefulWidget {
  const LivePhotoPickerScreen({super.key});

  @override
  State<LivePhotoPickerScreen> createState() => _LivePhotoPickerScreenState();
}

class _LivePhotoPickerScreenState extends State<LivePhotoPickerScreen> {
  List<AssetEntity> _livePhotos = [];
  bool _loading = true;
  bool _permissionDenied = false;

  static const _bg = Color(0xFF0E0E16);
  static const _accent = Color(0xFF7C6EFA);

  @override
  void initState() {
    super.initState();
    _loadLivePhotos();
  }

  Future<void> _loadLivePhotos() async {
    final permission = await PhotoManager.requestPermissionExtend();
    if (!permission.isAuth && !permission.hasAccess) {
      if (mounted) setState(() { _loading = false; _permissionDenied = true; });
      return;
    }

    final albums = await PhotoManager.getAssetPathList(
      type: RequestType.image,
    );

    final allAssets = <AssetEntity>[];
    for (final album in albums) {
      final count = await album.assetCountAsync;
      if (count == 0) continue;
      final assets = await album.getAssetListRange(
          start: 0, end: count.clamp(0, 500));
      allAssets.addAll(assets);
    }

    // Filter live photos and deduplicate
    final seen = <String>{};
    final livePhotos = allAssets
        .where((a) => a.isLivePhoto && seen.add(a.id))
        .toList();

    // Sort newest first
    livePhotos.sort((a, b) =>
        b.createDateTime.compareTo(a.createDateTime));

    if (mounted) setState(() { _livePhotos = livePhotos; _loading = false; });
  }

  Future<void> _onAssetTap(AssetEntity asset) async {
    // originFileWithSubtype returns the .mov video component for Live Photos on iOS
    final videoFile = await asset.originFileWithSubtype;
    if (videoFile == null || !mounted) return;

    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => _LiveFramePickerScreen(videoFile: videoFile),
      ),
    );

    if (result != null && mounted) {
      Navigator.pop(context, result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        leading: const BackButton(color: Colors.white),
        title: Text(
          AppL10n.pickLivePhoto,
          style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _accent, strokeWidth: 2))
          : _permissionDenied
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.photo_library_outlined, color: Colors.white24, size: 48),
                        const SizedBox(height: 16),
                        Text(
                          AppL10n.photoPermissionDenied,
                          style: GoogleFonts.poppins(color: Colors.white54, fontSize: 14),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              : _livePhotos.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.motion_photos_on_outlined, color: Colors.white24, size: 48),
                          const SizedBox(height: 16),
                          Text(
                            AppL10n.noLivePhotos,
                            style: GoogleFonts.poppins(color: Colors.white54, fontSize: 14),
                          ),
                        ],
                      ),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.all(3),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 3,
                        mainAxisSpacing: 3,
                      ),
                      itemCount: _livePhotos.length,
                      itemBuilder: (context, index) {
                        final asset = _livePhotos[index];
                        return _LivePhotoThumbnail(
                          asset: asset,
                          onTap: () => _onAssetTap(asset),
                        );
                      },
                    ),
    );
  }
}

class _LivePhotoThumbnail extends StatefulWidget {
  final AssetEntity asset;
  final VoidCallback onTap;

  const _LivePhotoThumbnail({required this.asset, required this.onTap});

  @override
  State<_LivePhotoThumbnail> createState() => _LivePhotoThumbnailState();
}

class _LivePhotoThumbnailState extends State<_LivePhotoThumbnail> {
  Uint8List? _thumb;

  @override
  void initState() {
    super.initState();
    _loadThumb();
  }

  Future<void> _loadThumb() async {
    final data = await widget.asset.thumbnailDataWithSize(
      const ThumbnailSize(300, 300),
    );
    if (mounted) setState(() => _thumb = data);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _thumb != null
              ? Image.memory(_thumb!, fit: BoxFit.cover)
              : Container(color: const Color(0xFF16161F)),
          // Live badge
          Positioned(
            left: 6,
            bottom: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.white24, width: 0.5),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.motion_photos_on, color: Colors.white, size: 10),
                  const SizedBox(width: 3),
                  Text(
                    'LIVE',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Frame picker: shows VideoPlayer with a scrubber to pick keyframe
class _LiveFramePickerScreen extends StatefulWidget {
  final File videoFile;

  const _LiveFramePickerScreen({required this.videoFile});

  @override
  State<_LiveFramePickerScreen> createState() => _LiveFramePickerScreenState();
}

class _LiveFramePickerScreenState extends State<_LiveFramePickerScreen> {
  VideoPlayerController? _controller;
  bool _initialized = false;
  double _sliderValue = 0;
Duration _totalDuration = Duration.zero;
  bool _isDragging = false;
  bool _isPlaying = true;

  static const _bg = Color(0xFF0A0A12);
  static const _accent = Color(0xFF7C6EFA);

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  Future<void> _initVideo() async {
    final ctrl = VideoPlayerController.file(widget.videoFile);
    await ctrl.initialize();
    ctrl.setLooping(true);
    ctrl.play();

    if (mounted) {
      setState(() {
        _controller = ctrl;
        _initialized = true;
        _totalDuration = ctrl.value.duration;
      });

      // Only update slider from video when user is NOT dragging
      ctrl.addListener(() {
        if (!mounted || _isDragging) return;
        final pos = ctrl.value.position.inMilliseconds.toDouble();
        final total = ctrl.value.duration.inMilliseconds.toDouble();
        if (total > 0) setState(() => _sliderValue = pos.clamp(0, total));
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _onDragStart(double ms) {
    _isDragging = true;
    _controller?.pause();
    setState(() { _sliderValue = ms; _isPlaying = false; });
  }

  void _onDragUpdate(double ms) {
    setState(() => _sliderValue = ms);
    // Seek without awaiting for smooth scrubbing feedback
    _controller?.seekTo(Duration(milliseconds: ms.round()));
  }

  void _onDragEnd(double ms) {
    _controller?.seekTo(Duration(milliseconds: ms.round()));
    setState(() { _sliderValue = ms; _isDragging = false; });
  }

  void _togglePlay() {
    final ctrl = _controller;
    if (ctrl == null) return;
    if (ctrl.value.isPlaying) {
      ctrl.pause();
      setState(() => _isPlaying = false);
    } else {
      ctrl.play();
      setState(() => _isPlaying = true);
    }
  }

  void _confirm() {
    // Use _sliderValue as the keyframe (last position user stopped at)
    Navigator.pop(context, {
      'video_file': widget.videoFile,
      'start_ms': _sliderValue.round(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final totalMs = _totalDuration.inMilliseconds.toDouble();

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        leading: const BackButton(color: Colors.white),
        title: Text(
          AppL10n.pickKeyFrame,
          style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: TextButton(
              onPressed: _initialized ? _confirm : null,
              child: Text(
                AppL10n.use,
                style: GoogleFonts.poppins(
                  color: _accent,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ],
      ),
      body: _initialized
          ? Column(
              children: [
                // Video preview — tap to play/pause
                Expanded(
                  child: GestureDetector(
                    onTap: _togglePlay,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Center(
                          child: AspectRatio(
                            aspectRatio: _controller!.value.aspectRatio,
                            child: VideoPlayer(_controller!),
                          ),
                        ),
                        // Play icon overlay when paused
                        if (!_isPlaying)
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.black45,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.play_arrow_rounded,
                                color: Colors.white, size: 40),
                          ),
                      ],
                    ),
                  ),
                ),
                // Scrubber section
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
                  child: Column(
                    children: [
                      // Time row + play/pause button
                      Row(
                        children: [
                          // Play/pause
                          GestureDetector(
                            onTap: _togglePlay,
                            child: Icon(
                              _isPlaying
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              color: Colors.white70,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            _formatMs(_sliderValue.round()),
                            style: GoogleFonts.poppins(color: Colors.white54, fontSize: 12),
                          ),
                          const Spacer(),
                          Text(
                            _formatMs(totalMs.round()),
                            style: GoogleFonts.poppins(color: Colors.white54, fontSize: 12),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      // Slider
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: _accent,
                          inactiveTrackColor: Colors.white12,
                          thumbColor: Colors.white,
                          overlayColor: _accent.withValues(alpha: 0.2),
                          trackHeight: 3,
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
                        ),
                        child: Slider(
                          min: 0,
                          max: totalMs > 0 ? totalMs : 1,
                          value: _sliderValue.clamp(0, totalMs > 0 ? totalMs : 1),
                          onChangeStart: _onDragStart,
                          onChanged: _onDragUpdate,
                          onChangeEnd: _onDragEnd,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Keyframe indicator
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.fiber_manual_record, color: _accent, size: 8),
                          const SizedBox(width: 6),
                          Text(
                            AppL10n.keyFrameHint,
                            style: GoogleFonts.poppins(color: Colors.white38, fontSize: 11),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            )
          : const Center(
              child: CircularProgressIndicator(color: _accent, strokeWidth: 2),
            ),
    );
  }

  String _formatMs(int ms) {
    final s = (ms / 1000).floor();
    final tenths = ((ms % 1000) / 100).floor();
    return '$s.${tenths}s';
  }
}
