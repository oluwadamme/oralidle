import 'dart:async';
import 'dart:developer' show log;
import 'dart:io' show File;
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../core/widgets/pressable.dart';
import '../../../../core/widgets/surface_card.dart';
import '../../../../core/widgets/waveform_loader.dart';

class RecordingPlayerCard extends StatefulWidget {
  final String audioPath;
  final int? fallbackDurationSeconds;

  const RecordingPlayerCard({
    super.key,
    required this.audioPath,
    this.fallbackDurationSeconds,
  });

  @override
  State<RecordingPlayerCard> createState() => _RecordingPlayerCardState();
}

class _RecordingPlayerCardState extends State<RecordingPlayerCard> {
  late final AudioPlayer _player;
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  PlayerState _playerState = PlayerState.stopped;
  bool _isReady = false;
  bool _hasError = false;
  bool _isSeeking = false;
  double _seekValue = 0.0;

  @override
  void initState() {
    super.initState();
    if (widget.fallbackDurationSeconds != null &&
        widget.fallbackDurationSeconds! > 0) {
      _duration = Duration(seconds: widget.fallbackDurationSeconds!);
    }
    _player = AudioPlayer();
    unawaited(_player.setVolume(1.0));
    _subscriptions.addAll([
      _player.onPositionChanged.listen(_onPosition),
      _player.onDurationChanged.listen(_onDuration),
      _player.onPlayerStateChanged.listen(_onState),
      _player.onPlayerComplete.listen(_onComplete),
    ]);
    _loadSource();
  }

  void _onPosition(Duration pos) {
    if (mounted && !_isSeeking) {
      setState(() => _position = pos);
    }
  }

  void _onDuration(Duration dur) {
    if (mounted && dur > Duration.zero) {
      setState(() => _duration = dur);
    }
  }

  void _onState(PlayerState s) {
    if (mounted) setState(() => _playerState = s);
  }

  void _onComplete(void _) {
    unawaited(_player.seek(Duration.zero));
    if (mounted) {
      setState(() {
        _playerState = PlayerState.stopped;
        _position = Duration.zero;
      });
    }
  }

  Future<void> _loadSource() async {
    try {
      final path = widget.audioPath.trim();
      if (path.isEmpty) {
        if (mounted) setState(() => _hasError = true);
        return;
      }

      if (path.startsWith('data:')) {
        await _player.setSource(UrlSource(path));
      } else if (!kIsWeb) {
        final file = File(path);
        if (!await file.exists()) {
          if (mounted) setState(() => _hasError = true);
          return;
        }
        await _player.setSource(DeviceFileSource(path));
      } else {
        await _player.setSource(UrlSource(path));
      }

      if (mounted) setState(() => _isReady = true);
    } catch (e) {
      log('RecordingPlayerCard: loadSource error: $e');
      if (mounted) setState(() => _hasError = true);
    }
  }

  Future<void> _togglePlay() async {
    try {
      await _player.setVolume(1.0);
      if (_playerState == PlayerState.playing) {
        await _player.pause();
      } else if (_playerState == PlayerState.paused) {
        await _player.resume();
      } else {
        final path = widget.audioPath.trim();
        if (path.startsWith('data:')) {
          await _player.play(UrlSource(path));
        } else if (!kIsWeb) {
          await _player.play(DeviceFileSource(path));
        } else {
          await _player.play(UrlSource(path));
        }
      }
    } catch (e) {
      log('RecordingPlayerCard: togglePlay error: $e');
    }
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  void dispose() {
    for (final sub in _subscriptions) {
      unawaited(sub.cancel());
    }
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return const SizedBox.shrink();
    }

    final isPlaying = _playerState == PlayerState.playing;
    final maxMs = _duration.inMilliseconds;
    final progress = maxMs > 0
        ? (_position.inMilliseconds / maxMs).clamp(0.0, 1.0)
        : 0.0;

    return SurfaceCard(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.raised2,
                ),
                child: const Icon(
                  LucideIcons.volume2,
                  size: 16,
                  color: AppColors.accent,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'YOUR RECORDING',
                style: context.overline.copyWith(
                  fontWeight: AppFontWeight.w700,
                  color: AppColors.ink,
                  letterSpacing: 0.8,
                ),
              ),
              const Spacer(),
              if (!_isReady)
                const WaveformLoader.compact(
                  height: 14,
                  barCount: 3,
                  barWidth: 2,
                  barSpacing: 1.5,
                  color: AppColors.inkMuted,
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Pressable(
                onTap: _isReady ? _togglePlay : null,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isReady ? AppColors.action : AppColors.raised2,
                    border: Border.all(
                      color: _isReady ? AppColors.action : AppColors.borderControl,
                    ),
                  ),
                  child: Icon(
                    isPlaying ? LucideIcons.pause : LucideIcons.play,
                    color: _isReady ? AppColors.onAction : AppColors.inkMuted,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 4,
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 6,
                        ),
                        overlayShape: const RoundSliderOverlayShape(
                          overlayRadius: 14,
                        ),
                        activeTrackColor: AppColors.accent,
                        inactiveTrackColor: AppColors.line,
                        thumbColor: AppColors.accent,
                        overlayColor: AppColors.accent.withValues(alpha: 0.15),
                      ),
                      child: Slider(
                        value: _isSeeking ? _seekValue : progress,
                        onChangeStart: (double v) => setState(() {
                          _isSeeking = true;
                          _seekValue = v;
                        }),
                        onChanged: (double v) => setState(() => _seekValue = v),
                        onChangeEnd: (double v) {
                          setState(() => _isSeeking = false);
                          if (maxMs > 0) {
                            _player.seek(
                              Duration(milliseconds: (v * maxMs).round()),
                            );
                          }
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _formatDuration(_position),
                            style: context.overline.copyWith(
                              color: AppColors.inkMuted,
                            ),
                          ),
                          Text(
                            _formatDuration(_duration),
                            style: context.overline.copyWith(
                              color: AppColors.inkMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
