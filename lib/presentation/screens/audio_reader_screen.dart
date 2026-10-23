import 'dart:math' as math;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/services/tts_service.dart';

class AudioReaderScreen extends StatefulWidget {
  final String initialText;

  const AudioReaderScreen({
    super.key,
    this.initialText = '',
  });

  @override
  State<AudioReaderScreen> createState() => _AudioReaderScreenState();
}

class _AudioReaderScreenState extends State<AudioReaderScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _textController = TextEditingController();
  final TtsService _tts = TtsService.instance;
  late final AnimationController _waveController;

  double _speechRate = 0.5; // default in FlutterTts (approx 1.0x)

  @override
  void initState() {
    super.initState();
    if (widget.initialText.isNotEmpty) {
      _textController.text = widget.initialText;
    }
    _speechRate = _tts.speechRate;
    _tts.init();

    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _waveController.dispose();
    _textController.dispose();
    _tts.stop();
    super.dispose();
  }

  void _pasteFromClipboard() async {
    final data = await Clipboard.getData('text/plain');
    if (data?.text != null && data!.text!.trim().isNotEmpty) {
      HapticFeedback.lightImpact();
      setState(() {
        _textController.text = data.text!;
      });
    }
  }

  Future<void> _handlePlay() async {
    final text = _textController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter or paste text to read aloud.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    HapticFeedback.mediumImpact();
    await _tts.speak(text);
  }

  Future<void> _handlePause() async {
    HapticFeedback.lightImpact();
    await _tts.pause();
  }

  Future<void> _handleResume() async {
    HapticFeedback.lightImpact();
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    await _tts.speak(text);
  }

  Future<void> _handleStop() async {
    HapticFeedback.lightImpact();
    await _tts.stop();
  }

  void _setSpeedRate(double rate) {
    HapticFeedback.selectionClick();
    setState(() => _speechRate = rate);
    _tts.setRate(rate);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Audio Reader (TTS)',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 19),
        ),
        centerTitle: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFFF2D55).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFFFF2D55).withValues(alpha: 0.4),
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(CupertinoIcons.speaker_2_fill, color: Color(0xFFFF2D55), size: 14),
                SizedBox(width: 4),
                Text(
                  'On-Device Voice',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFFF2D55),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Wave visualizer & Playback Status Card
              ValueListenableBuilder<TtsPlaybackState>(
                valueListenable: _tts.stateNotifier,
                builder: (context, state, _) {
                  final isPlaying = state == TtsPlaybackState.playing;
                  final isPaused = state == TtsPlaybackState.paused;

                  return Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isPlaying
                            ? [const Color(0xFF2563EB), const Color(0xFF7C3AED)]
                            : isPaused
                                ? [const Color(0xFFD97706), const Color(0xFFF59E0B)]
                                : isDark
                                    ? [const Color(0xFF1E293B), const Color(0xFF334155)]
                                    : [Colors.white, const Color(0xFFF1F5F9)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: (isPlaying
                                  ? const Color(0xFF2563EB)
                                  : Colors.black)
                              .withValues(alpha: isPlaying ? 0.35 : 0.08),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Status badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: isPlaying || isPaused
                                ? Colors.white.withValues(alpha: 0.2)
                                : theme.colorScheme.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isPlaying
                                    ? CupertinoIcons.speaker_2_fill
                                    : isPaused
                                        ? CupertinoIcons.pause_fill
                                        : CupertinoIcons.waveform,
                                size: 16,
                                color: isPlaying || isPaused
                                    ? Colors.white
                                    : theme.colorScheme.primary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                isPlaying
                                    ? 'Speaking Aloud...'
                                    : isPaused
                                        ? 'Playback Paused'
                                        : 'Ready to Read',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: isPlaying || isPaused
                                      ? Colors.white
                                      : theme.colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Animated Sound Waves
                        AnimatedBuilder(
                          animation: _waveController,
                          builder: (context, _) {
                            return SizedBox(
                              height: 54,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: List.generate(24, (index) {
                                  double waveHeight = 8;
                                  if (isPlaying) {
                                    final phase = (index * 0.28) + (_waveController.value * 2 * math.pi);
                                    waveHeight = 8 + (math.sin(phase).abs() * 38);
                                  } else if (isPaused) {
                                    waveHeight = 12;
                                  }

                                  return Container(
                                    margin: const EdgeInsets.symmetric(horizontal: 2.5),
                                    width: 3.5,
                                    height: waveHeight,
                                    decoration: BoxDecoration(
                                      color: isPlaying || isPaused
                                          ? Colors.white.withValues(
                                              alpha: (0.4 + (index % 3) * 0.2).clamp(0.4, 1.0),
                                            )
                                          : theme.colorScheme.primary.withValues(alpha: 0.35),
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                  );
                                }),
                              ),
                            );
                          },
                        ),

                        const SizedBox(height: 20),

                        // Media Controls
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Stop Button
                            CupertinoButton(
                              padding: EdgeInsets.zero,
                              onPressed: isPlaying || isPaused ? _handleStop : null,
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isPlaying || isPaused
                                      ? Colors.white.withValues(alpha: 0.2)
                                      : (isDark ? Colors.white10 : Colors.black12),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  CupertinoIcons.stop_fill,
                                  color: isPlaying || isPaused
                                      ? Colors.white
                                      : Colors.grey,
                                  size: 22,
                                ),
                              ),
                            ),

                            const SizedBox(width: 24),

                            // Main Play / Pause Button
                            CupertinoButton(
                              padding: EdgeInsets.zero,
                              onPressed: isPlaying
                                  ? _handlePause
                                  : isPaused
                                      ? _handleResume
                                      : _handlePlay,
                              child: Container(
                                width: 68,
                                height: 68,
                                decoration: BoxDecoration(
                                  color: isPlaying || isPaused
                                      ? Colors.white
                                      : theme.colorScheme.primary,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.2),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  isPlaying
                                      ? CupertinoIcons.pause_fill
                                      : CupertinoIcons.play_fill,
                                  color: isPlaying || isPaused
                                      ? (isPaused ? const Color(0xFFD97706) : const Color(0xFF2563EB))
                                      : Colors.white,
                                  size: 32,
                                ),
                              ),
                            ),

                            const SizedBox(width: 24),

                            // Clear / Reset Button
                            CupertinoButton(
                              padding: EdgeInsets.zero,
                              onPressed: () {
                                _handleStop();
                                setState(() => _textController.clear());
                              },
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isPlaying || isPaused
                                      ? Colors.white.withValues(alpha: 0.2)
                                      : (isDark ? Colors.white10 : Colors.black12),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  CupertinoIcons.arrow_counterclockwise,
                                  color: isPlaying || isPaused
                                      ? Colors.white
                                      : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                  size: 20,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),

              const SizedBox(height: 20),

              // Speech Speed Controls
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              CupertinoIcons.speedometer,
                              size: 18,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Voice Reading Speed',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${(_speechRate * 2).toStringAsFixed(2)}x',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    CupertinoSlider(
                      value: _speechRate,
                      min: 0.1,
                      max: 1.0,
                      divisions: 9,
                      onChanged: _setSpeedRate,
                    ),
                    const SizedBox(height: 8),
                    // Speed Presets
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildSpeedChip('0.5x', 0.25),
                        _buildSpeedChip('0.75x', 0.375),
                        _buildSpeedChip('1.0x (Normal)', 0.5),
                        _buildSpeedChip('1.25x', 0.625),
                        _buildSpeedChip('1.5x', 0.75),
                        _buildSpeedChip('2.0x', 1.0),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Text Input Box
              Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 12, 0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Text to Read Aloud',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                          Row(
                            children: [
                              CupertinoButton(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                onPressed: _pasteFromClipboard,
                                child: const Row(
                                  children: [
                                    Icon(CupertinoIcons.doc_on_clipboard, size: 16),
                                    SizedBox(width: 4),
                                    Text('Paste', style: TextStyle(fontSize: 12)),
                                  ],
                                ),
                              ),
                              if (_textController.text.isNotEmpty)
                                CupertinoButton(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  onPressed: () {
                                    setState(() => _textController.clear());
                                  },
                                  child: const Icon(CupertinoIcons.clear_circled_solid, size: 18),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    TextField(
                      controller: _textController,
                      maxLines: 8,
                      minLines: 5,
                      style: const TextStyle(fontSize: 15, height: 1.45),
                      decoration: InputDecoration(
                        hintText: 'Enter or paste documents, notes, legal terms, articles or stories to listen hands-free...',
                        hintStyle: TextStyle(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      ),
                      onChanged: (val) => setState(() {}),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Bottom note
              Center(
                child: Text(
                  '🔒 Native On-Device Engine: Reads text instantly using your device\'s local TTS synthesizer.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.4,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSpeedChip(String label, double rate) {
    final isSelected = (_speechRate - rate).abs() < 0.05;
    return InkWell(
      onTap: () => _setSpeedRate(rate),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primary
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label.replaceAll(' (Normal)', ''),
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected
                ? Colors.white
                : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
      ),
    );
  }
}
