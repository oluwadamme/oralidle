import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../topic_selection/data/models/topic.dart';
import '../../data/models/recording_session.dart';
import '../../../../core/constants/app_constants.dart';

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
        // User cancelled — restart countdown
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

      // Gemini inline audio limit is 20 MB
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
        audioFileBytes: bytes,
        audioFileMimeType: _mimeType(file.extension),
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
      SnackBar(content: Text(message), backgroundColor: AppColors.poor),
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
    final color = widget.topic.category.categoryColor;
    final progress = _remaining / AppConstants.prepCountdownSeconds;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Get Ready'),
        actions: [
          TextButton(
            onPressed: () {
              _timer?.cancel();
              _goToRecord();
            },
            child: const Text('Skip →'),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  widget.topic.category,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                widget.topic.title,
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium
                    ?.copyWith(fontWeight: FontWeight.w800, height: 1.2),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.lightbulb_outline, color: Colors.amber, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.topic.hint,
                        style: const TextStyle(fontSize: 14, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const _TipsList(),
              const Spacer(),
              Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 100,
                      height: 100,
                      child: CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 6,
                        backgroundColor: Colors.grey.shade200,
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$_remaining',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            color: color,
                          ),
                        ),
                        Text('seconds', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _pickingFile
                    ? null
                    : () {
                        _timer?.cancel();
                        _goToRecord();
                      },
                icon: const Icon(Icons.mic_rounded),
                label: const Text("I'm Ready — Start Now"),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _pickingFile ? null : _pickAudioFile,
                icon: _pickingFile
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.upload_file_rounded),
                label: Text(_pickingFile ? 'Opening file picker…' : 'Upload Audio File'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Supported: MP3, WAV, M4A, AAC, OGG, FLAC · Max 20 MB',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
            ],
          ),
        ),
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
          .map((tip) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_outline_rounded,
                        size: 16, color: AppColors.good),
                    const SizedBox(width: 8),
                    Text(tip, style: const TextStyle(fontSize: 14)),
                  ],
                ),
              ))
          .toList(),
    );
  }
}
