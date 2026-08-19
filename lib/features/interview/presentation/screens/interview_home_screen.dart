import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/services/speech/mic_permission.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../data/models/interview_models.dart';
import '../../providers/interview_history_provider.dart';
import '../../../../core/utils/responsive.dart';

class InterviewHomeScreen extends ConsumerStatefulWidget {
  const InterviewHomeScreen({super.key});

  @override
  ConsumerState<InterviewHomeScreen> createState() =>
      _InterviewHomeScreenState();
}

class _InterviewHomeScreenState extends ConsumerState<InterviewHomeScreen> {
  InterviewMode _selectedMode = InterviewMode.mixed;
  int _questionCount = 5;
  String? _customCvContent;
  String? _customCvFileName;

  static const _counts = [3, 5, 7, 10];

  Future<void> _requestMicPermission() async {
    await MicPermissions.request();
    // Invalidate the cached status so the banner re-evaluates
    ref.invalidate(micPermissionProvider);
  }

  Future<void> _pickCustomDocument() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['md', 'txt', 'pdf', 'doc', 'docx', 'json'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.single;
        final bytes = file.bytes;
        if (bytes != null && bytes.isNotEmpty) {
          String text;
          try {
            text = utf8.decode(bytes);
          } catch (_) {
            text = String.fromCharCodes(bytes);
          }

          // Strip non-printable binary control characters
          text = text.replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F]'), '');

          if (text.trim().isEmpty) {
            if (mounted) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('The selected file appears to be empty.')));
            }
            return;
          }

          setState(() {
            _customCvContent = text;
            _customCvFileName = file.name;
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Loaded "${file.name}" for interview context'),
                duration: const Duration(seconds: 2),
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load file: $e')));
      }
    }
  }

  Future<void> _showPasteTextModal() async {
    final controller = TextEditingController(text: _customCvContent ?? '');
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Paste CV or Project README'),
        content: Form(
          key: formKey,
          child: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Paste your resume, project README, or candidate bio below:',
                  style: TextStyle(fontSize: 13, color: AppColors.textMedium),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: controller,
                  maxLines: 8,
                  minLines: 4,
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: '# Project Overview\n\n## Architecture\nFlutter, Node.js, Gemini API...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: AppColors.cardBorder,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter some context text';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context, controller.text.trim());
              }
            },
            child: const Text('Save Context'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      final words = result.split(RegExp(r'\s+')).length;
      setState(() {
        _customCvContent = result;
        _customCvFileName = 'Pasted Text ($words words)';
      });
    }
  }

  void _resetCustomDocument() {
    setState(() {
      _customCvContent = null;
      _customCvFileName = null;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reverted to default sample CV (assets/cv.md)'), duration: Duration(seconds: 2)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const Positioned(
            top: -80,
            left: -60,
            child: AmbientOrb(color: AppColors.primary, size: 280),
          ),
          const Positioned(
            bottom: 60,
            right: -80,
            child: AmbientOrb(color: AppColors.amber, size: 220),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= Breakpoints.twoColumn;
                return isWide
                    ? _wideLayout(context, constraints.maxWidth)
                    : _mobileLayout(context);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _wideLayout(BuildContext context, double availableWidth) {
    final history = ref.watch(interviewHistoryProvider);

    return SingleChildScrollView(
      // Side margins grow on wide windows so the two-column body stops
      // widening while the backdrop stays full-bleed.
      padding: centeredPagePadding(
        availableWidth,
        minHorizontal: 48,
        top: 32,
        bottom: 48,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 280,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Header(),
                const SizedBox(height: 16),
                _PermissionBanner(onGrant: _requestMicPermission),
                const SizedBox(height: 16),
                GlassCard(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'How it works',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 14),
                      _HowItWorksStep(
                        number: '1',
                        text:
                            'AI reads your CV and prepares personalised questions',
                      ),
                      _HowItWorksStep(
                        number: '2',
                        text: 'Speak your answers — just like a real interview',
                      ),
                      _HowItWorksStep(
                        number: '3',
                        text:
                            'Get scored on content quality and delivery after each answer',
                      ),
                      _HowItWorksStep(
                        number: '4',
                        text: 'Receive a full debrief at the end',
                        isLast: true,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 32),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ContextDocumentSection(
                  fileName: _customCvFileName,
                  content: _customCvContent,
                  onUpload: _pickCustomDocument,
                  onPaste: _showPasteTextModal,
                  onReset: _resetCustomDocument,
                ),
                const SizedBox(height: 24),
                _ModeSection(
                  selectedMode: _selectedMode,
                  onSelect: (m) => setState(() => _selectedMode = m),
                ),
                const SizedBox(height: 28),
                _CountSection(
                  counts: _counts,
                  selected: _questionCount,
                  onSelect: (c) => setState(() => _questionCount = c),
                ),
                const SizedBox(height: 36),
                _StartButton(
                  mode: _selectedMode,
                  count: _questionCount,
                  customCvContent: _customCvContent,
                  customCvFileName: _customCvFileName,
                ),
                if (history.isNotEmpty) ...[
                  const SizedBox(height: 32),
                  _RecentSessionsSection(sessions: history),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _mobileLayout(BuildContext context) {
    final history = ref.watch(interviewHistoryProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(),
          const SizedBox(height: 16),
          _PermissionBanner(onGrant: _requestMicPermission),
          const SizedBox(height: 16),
          _ContextDocumentSection(
            fileName: _customCvFileName,
            content: _customCvContent,
            onUpload: _pickCustomDocument,
            onPaste: _showPasteTextModal,
            onReset: _resetCustomDocument,
          ),
          const SizedBox(height: 20),
          _ModeSection(
            selectedMode: _selectedMode,
            onSelect: (m) => setState(() => _selectedMode = m),
          ),
          const SizedBox(height: 24),
          _CountSection(
            counts: _counts,
            selected: _questionCount,
            onSelect: (c) => setState(() => _questionCount = c),
          ),
          const SizedBox(height: 32),
          _StartButton(
            mode: _selectedMode,
            count: _questionCount,
            customCvContent: _customCvContent,
            customCvFileName: _customCvFileName,
          ),
          if (history.isNotEmpty) ...[
            const SizedBox(height: 32),
            _RecentSessionsSection(sessions: history),
          ],
        ],
      ),
    );
  }
}

// ── Permission banner ─────────────────────────────────────────────────────────
//
// Watches micPermissionProvider (autoDispose FutureProvider) and shows a
// non-blocking warning when microphone access is not yet granted.
// Shown as a no-op empty box when permission is granted or still loading,
// so it has zero visual footprint in the happy path.

class _PermissionBanner extends ConsumerWidget {
  final VoidCallback onGrant;

  const _PermissionBanner({required this.onGrant});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permAsync = ref.watch(micPermissionProvider);

    return permAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (status) {
        if (status == MicPermission.granted) return const SizedBox.shrink();

        // Only offer the Settings route where there is a settings app to
        // open; elsewhere the retry prompt is the only useful action.
        final isPermanent =
            status == MicPermission.permanentlyDenied &&
            MicPermissions.canOpenSettings;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.amber.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.amber.withValues(alpha: 0.35)),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.mic_off_rounded,
                size: 16,
                color: AppColors.amber,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isPermanent
                      ? 'Microphone access was denied. Enable it in Settings to use voice answers.'
                      : 'Microphone access is needed for voice answers.',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.amber,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: isPermanent ? MicPermissions.openSettings : onGrant,
                child: Text(
                  isPermanent ? 'Settings' : 'Grant',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.amber,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Recent sessions ───────────────────────────────────────────────────────────

class _RecentSessionsSection extends StatelessWidget {
  final List<CompletedInterview> sessions;

  const _RecentSessionsSection({required this.sessions});

  @override
  Widget build(BuildContext context) {
    final recent = sessions.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'RECENT SESSIONS',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.textMedium,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 10),
        ...recent.map((s) => _SessionRow(session: s)),
      ],
    );
  }
}

class _SessionRow extends StatelessWidget {
  final CompletedInterview session;

  const _SessionRow({required this.session});

  @override
  Widget build(BuildContext context) {
    final color = AppColors.scoreColor(session.evaluation.overallScore);

    return GestureDetector(
      onTap: () => context.push(AppRoutes.interviewResults, extra: session),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: AppColors.glassCard(radius: 10),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 0.12),
              ),
              child: Center(
                child: Text(
                  '${session.evaluation.overallScore}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    session.mode.label,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark,
                    ),
                  ),
                  Text(
                    '${session.turns.length} questions · '
                    '${DateFormat('MMM d').format(session.timestamp)}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textMedium,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: AppColors.outline,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.15),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.3),
                ),
              ),
              child: const Icon(
                Icons.work_outline_rounded,
                size: 18,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Interview Prep',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.textDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        const Text(
          'AI mock interviews personalised to your CV. Sharpen your answers, improve your delivery.',
          style: TextStyle(
            fontSize: 14,
            color: AppColors.textMedium,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

// ── Mode selection ────────────────────────────────────────────────────────────

class _ModeSection extends StatelessWidget {
  final InterviewMode selectedMode;
  final ValueChanged<InterviewMode> onSelect;

  const _ModeSection({required this.selectedMode, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'INTERVIEW TYPE',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.textMedium,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 12),
        ...InterviewMode.values.map(
          (mode) => _ModeCard(
            mode: mode,
            isSelected: selectedMode == mode,
            onTap: () => onSelect(mode),
          ),
        ),
      ],
    );
  }
}

class _ModeCard extends StatelessWidget {
  final InterviewMode mode;
  final bool isSelected;
  final VoidCallback onTap;

  const _ModeCard({
    required this.mode,
    required this.isSelected,
    required this.onTap,
  });

  static const _icons = {
    InterviewMode.technical: Icons.code_rounded,
    InterviewMode.behavioral: Icons.psychology_outlined,
    InterviewMode.mixed: Icons.shuffle_rounded,
  };

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.1)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? AppColors.primary.withValues(alpha: 0.5)
                : AppColors.cardBorder,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected
                    ? AppColors.primary.withValues(alpha: 0.15)
                    : AppColors.surfaceHigh,
              ),
              child: Icon(
                _icons[mode]!,
                size: 18,
                color: isSelected ? AppColors.primary : AppColors.outline,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    mode.label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    mode.description,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMedium,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle_rounded,
                size: 18,
                color: AppColors.primary,
              ),
          ],
        ),
      ),
    );
  }
}

// ── Question count ────────────────────────────────────────────────────────────

class _CountSection extends StatelessWidget {
  final List<int> counts;
  final int selected;
  final ValueChanged<int> onSelect;

  const _CountSection({
    required this.counts,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'NUMBER OF QUESTIONS',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.textMedium,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: counts
              .map(
                (c) => Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: c != counts.last ? 10 : 0),
                    child: _CountPill(
                      count: c,
                      isSelected: selected == c,
                      onTap: () => onSelect(c),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

class _CountPill extends StatelessWidget {
  final int count;
  final bool isSelected;
  final VoidCallback onTap;

  const _CountPill({
    required this.count,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.12)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? AppColors.primary.withValues(alpha: 0.5)
                : AppColors.cardBorder,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Text(
          '$count',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: isSelected ? AppColors.primary : AppColors.textMedium,
          ),
        ),
      ),
    );
  }
}

// ── Start button ──────────────────────────────────────────────────────────────

class _StartButton extends StatelessWidget {
  final InterviewMode mode;
  final int count;
  final String? customCvContent;
  final String? customCvFileName;

  const _StartButton({required this.mode, required this.count, this.customCvContent, this.customCvFileName});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push(
        AppRoutes.interviewSession,
        extra: InterviewSetup(
          mode: mode,
          questionCount: count,
          customCvContent: customCvContent,
          customCvFileName: customCvFileName,
        ),
      ),
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.primaryLight, AppColors.primary],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.35),
              blurRadius: 18,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.play_arrow_rounded,
              color: AppColors.onPrimary,
              size: 22,
            ),
            SizedBox(width: 8),
            Text(
              'Start Interview',
              style: TextStyle(
                color: AppColors.onPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Context Document Selector Card ────────────────────────────────────────────

class _ContextDocumentSection extends StatelessWidget {
  final String? fileName;
  final String? content;
  final VoidCallback onUpload;
  final VoidCallback onPaste;
  final VoidCallback onReset;

  const _ContextDocumentSection({
    required this.fileName,
    required this.content,
    required this.onUpload,
    required this.onPaste,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    final hasCustom = content != null && content!.trim().isNotEmpty;
    final wordCount = hasCustom ? content!.trim().split(RegExp(r'\s+')).length : 0;

    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.primary.withValues(alpha: 0.12)),
                child: const Icon(Icons.description_rounded, size: 18, color: AppColors.primary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Interview Context (CV or Project README)',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textDark),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hasCustom
                          ? 'Questions will be generated based on your uploaded document'
                          : 'Currently using default sample CV (assets/cv.md)',
                      style: const TextStyle(fontSize: 12, color: AppColors.textMedium),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Token recommendation hint banner
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
            ),
            child: const Row(
              children: [
                Icon(Icons.lightbulb_rounded, size: 16, color: AppColors.primary),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Markdown (.md) or plain text (.txt) files are recommended for reduced token usage and optimal question tailoring.',
                    style: TextStyle(fontSize: 12, color: AppColors.textDark, height: 1.35),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          if (hasCustom) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.good.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.good.withValues(alpha: 0.25)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, size: 18, color: AppColors.good),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          fileName ?? 'Custom Document',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textDark),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$wordCount words parsed',
                          style: const TextStyle(fontSize: 11, color: AppColors.textMedium),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18),
                    tooltip: 'Reset to default CV',
                    onPressed: onReset,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],

          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onUpload,
                  icon: const Icon(Icons.upload_file_rounded, size: 16),
                  label: Text(hasCustom ? 'Change File' : 'Upload File', style: const TextStyle(fontSize: 12)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onPaste,
                  icon: const Icon(Icons.edit_note_rounded, size: 16),
                  label: const Text('Paste Text', style: TextStyle(fontSize: 12)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── How it works steps ────────────────────────────────────────────────────────

class _HowItWorksStep extends StatelessWidget {
  final String number;
  final String text;
  final bool isLast;

  const _HowItWorksStep({
    required this.number,
    required this.text,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withValues(alpha: 0.12),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.3),
              ),
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textMedium,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
