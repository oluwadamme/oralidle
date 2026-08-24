import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../topic_selection/data/models/topic.dart';
import '../../data/models/recording_session.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/widgets/surface_card.dart';
import '../../../../core/widgets/pressable.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../core/theme/app_spacing.dart';

class PreparationScreen extends StatefulWidget {
  final Topic topic;
  const PreparationScreen({super.key, required this.topic});

  @override
  State<PreparationScreen> createState() => _PreparationScreenState();
}

class _PreparationScreenState extends State<PreparationScreen> {
  late int _remaining;
  Timer? _timer;
  bool _pickingFile = false;

  @override
  void initState() {
    super.initState();
    _remaining = AppConstants.prepCountdownSeconds;
    _startCountdown();
  }

  void _startCountdown() {
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _remaining--);
      if (_remaining <= 0) {
        t.cancel();
        _goToRecord();
      }
    });
  }

  void _goToRecord() {
    if (!mounted) return;
    context.pushReplacement(AppRoutes.record, extra: widget.topic);
  }

  Future<void> _pickAudioFile() async {
    _timer?.cancel();
    setState(() => _pickingFile = true);

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp3', 'wav', 'm4a', 'aac', 'ogg', 'flac', 'webm'],
        withData: true,
      );

      if (!mounted) return;

      if (result == null || result.files.isEmpty) {
        setState(() {
          _pickingFile = false;
          _remaining = AppConstants.prepCountdownSeconds;
        });
        _startCountdown();
        return;
      }

      final file = result.files.first;
      final bytes = file.bytes;

      if (bytes == null) {
        _showError('Could not read the file. Please try again.');
        setState(() {
          _pickingFile = false;
          _remaining = AppConstants.prepCountdownSeconds;
        });
        _startCountdown();
        return;
      }

      if (bytes.lengthInBytes > 20 * 1024 * 1024) {
        _showError('File is too large. Please use an audio file under 20 MB.');
        setState(() {
          _pickingFile = false;
          _remaining = AppConstants.prepCountdownSeconds;
        });
        _startCountdown();
        return;
      }

      final session = RecordingSession(
        topicId: widget.topic.id,
        topicTitle: widget.topic.title,
        topicCategory: widget.topic.category,
        transcript: '',
        durationSeconds: 0,
        audioBytes: bytes,
        audioMimeType: _mimeType(file.extension),
        audioFileName: file.name,
      );

      context.pushReplacement(AppRoutes.processing, extra: session);
    } catch (_) {
      if (!mounted) return;
      _showError('Could not open the file picker. Please try again.');
      setState(() {
        _pickingFile = false;
        _remaining = AppConstants.prepCountdownSeconds;
      });
      _startCountdown();
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.critical),
    );
  }

  String _mimeType(String? ext) {
    switch (ext?.toLowerCase()) {
      case 'mp3':
        return 'audio/mp3';
      case 'm4a':
      case 'mp4':
        return 'audio/mp4';
      case 'wav':
        return 'audio/wav';
      case 'ogg':
        return 'audio/ogg';
      case 'aac':
        return 'audio/aac';
      case 'flac':
        return 'audio/flac';
      case 'webm':
        return 'audio/webm';
      default:
        return 'audio/mpeg';
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = _remaining / AppConstants.prepCountdownSeconds;

    return Scaffold(
      body: Stack(
        children: [
          SafeArea(
            child: ResponsiveContainer(
              extraPadding: const EdgeInsets.symmetric(vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Header row ──────────────────────────────────────────
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(
                          LucideIcons.x,
                          color: AppColors.inkMuted,
                        ),
                        onPressed: () => context.go(AppRoutes.topics),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () {
                          _timer?.cancel();
                          _goToRecord();
                        },
                        child: const Text(
                          'Skip →',
                          style: TextStyle(
                            color: AppColors.ink,
                            fontWeight: AppFontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // ── Category chip ────────────────────────────────────────
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.raised2,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.line),
                      ),
                      child: Text(
                        widget.topic.category,
                        style: context.overline.copyWith(
                          color: AppColors.ink,
                          fontWeight: AppFontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // ── Topic title ──────────────────────────────────────────
                  Text(
                    widget.topic.title,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: AppFontWeight.w800,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Hint card ────────────────────────────────────────────
                  SurfaceCard(
                    padding: const EdgeInsets.all(14),
                    radius: 14,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          LucideIcons.lightbulb,
                          color: AppColors.caution,
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            widget.topic.hint,
                            style: context.body.copyWith(
                              height: 1.4,
                              color: AppColors.ink,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Tips list ────────────────────────────────────────────
                  const _TipsList(),
                  const Spacer(),

                  // ── Countdown ring ───────────────────────────────────────
                  Center(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 104,
                          height: 104,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.sunken,
                              width: 2,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 96,
                          height: 96,
                          child: CircularProgressIndicator(
                            value: progress,
                            strokeWidth: 6,
                            strokeCap: StrokeCap.round,
                            backgroundColor: AppColors.line,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              AppColors.voiceLow,
                            ),
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '$_remaining',
                              style: context.display.copyWith(
                                color: AppColors.ink,
                                fontWeight: AppFontWeight.w800,
                              ),
                            ),
                            Text(
                              'seconds',
                              style: context.overline.copyWith(
                                color: AppColors.inkMuted,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  // ── Start button ─────────────────────────────────────────
                  Pressable(
                    onTap: _pickingFile
                        ? null
                        : () {
                            _timer?.cancel();
                            _goToRecord();
                          },
                    child: Container(
                      height: 52,
                      decoration: BoxDecoration(
                        color: AppColors.action,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            LucideIcons.mic,
                            color: AppColors.onAction,
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Text(
                            "I'm Ready — Start Now",
                            style: context.cardTitle.copyWith(
                              color: AppColors.onAction,
                              fontWeight: AppFontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ── Upload button ────────────────────────────────────────
                  Pressable(
                    onTap: _pickingFile ? null : _pickAudioFile,
                    child: Container(
                      height: 52,
                      decoration: BoxDecoration(
                        color: AppColors.raised,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.borderControl),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _pickingFile
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      AppColors.ink,
                                    ),
                                  ),
                                )
                              : const Icon(
                                  LucideIcons.upload,
                                  color: AppColors.ink,
                                  size: 20,
                                ),
                          const SizedBox(width: 8),
                          Text(
                            _pickingFile
                                ? 'Opening file picker…'
                                : 'Upload Audio File',
                            style: context.cardTitle.copyWith(
                              color: AppColors.ink,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'MP3 · WAV · M4A · AAC · OGG · FLAC  ·  Max 20 MB',
                    textAlign: TextAlign.center,
                    style: context.overline.copyWith(color: AppColors.inkMuted),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TipsList extends StatelessWidget {
  const _TipsList();

  @override
  Widget build(BuildContext context) {
    const tips = [
      'Speak for 1–2 minutes',
      'Start with a clear opening statement',
      'Use 2–3 supporting points',
      'Finish with a concise conclusion',
    ];
    return Column(
      children: tips
          .map(
            (tip) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 3),
                    child: Icon(
                      LucideIcons.circleCheck,
                      size: IconSize.sm,
                      color: AppColors.positive,
                    ),
                  ),
                  const SizedBox(width: Space.md),
                  // Expanded so a long tip wraps instead of overflowing the
                  // row on narrow windows.
                  Expanded(
                    child: Text(
                      tip,
                      style: context.body.copyWith(color: AppColors.ink),
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}
