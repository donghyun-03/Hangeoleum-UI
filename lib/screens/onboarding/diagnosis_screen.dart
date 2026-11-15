import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/diagnosis_data.dart';
import '../../models/diagnosis_profile.dart';
import '../../router/main_tabs.dart';
import '../../router/routes.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

class DiagnosisScreen extends StatefulWidget {
  const DiagnosisScreen({super.key});

  @override
  State<DiagnosisScreen> createState() => _DiagnosisScreenState();
}

class _DiagnosisScreenState extends State<DiagnosisScreen> {
  final Map<String, String> _answers = {};
  final List<(bool fromMe, String text)> _msgs = [];
  final ScrollController _scroll = ScrollController();

  double _topFadeStrength = 0.0;
  bool _isTyping = true;

  List<SlotQuestion> get _visible => visibleQuestions(_answers);
  int get _idx => _answers.length;
  int get _total => _visible.length;
  bool get _done => _idx >= _total;

  SlotQuestion? get _current {
    final questions = _visible;
    if (_idx >= questions.length) return null;
    return questions[_idx];
  }

  double get _progressRatio {
    if (_total == 0) return 0.0;
    if (_done) return 1.0;
    return (_idx / _total).clamp(0.0, 1.0);
  }

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _playInitialMessages();
  }

  Future<void> _playInitialMessages() async {
    final first = kDiagnosisQuestions.first;
    await _enqueueAiMessages([
      '안녕하세요! 저는 한걸음 도우미예요.\n정답은 없으니 편하게 이야기해 주세요.',
      if (first.introText != null) first.introText!,
      first.questionText,
    ]);
  }

  Future<void> _enqueueAiMessages(List<String> messages) async {
    if (!mounted) return;
    setState(() => _isTyping = true);

    for (int i = 0; i < messages.length; i++) {
      final msg = messages[i];
      final prevLen = i == 0 ? 10 : messages[i - 1].length;
      final delayMs = i == 0 ? 550 : (750 + prevLen * 16).clamp(800, 1250);

      await Future.delayed(Duration(milliseconds: delayMs));
      if (!mounted) return;

      setState(() {
        _msgs.add((false, msg));
      });
      _scrollToBottom();
    }

    await Future.delayed(const Duration(milliseconds: 350));
    if (!mounted) return;
    setState(() => _isTyping = false);
    _scrollToBottom();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final nextStrength = (_scroll.offset / 32.0).clamp(0.0, 1.0);
    if ((nextStrength - _topFadeStrength).abs() > 0.02) {
      setState(() {
        _topFadeStrength = nextStrength;
      });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients && _scroll.position.maxScrollExtent > 0) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _answer(String option) async {
    if (_done || _isTyping) return;

    final question = _current;
    if (question == null) return;

    setState(() {
      _answers[question.slotKey] = option;
      _msgs.add((true, option));
      _isTyping = true;
    });
    _scrollToBottom();

    final nextAiMsgs = <String>[];
    final response = question.getResponseMessage(option);
    if (response != null) {
      nextAiMsgs.add(response);
    }

    if (_done) {
      nextAiMsgs.add('이야기 나눠줘서 고마워요! 나에게 맞는 첫 걸음을 준비했어요. 🌱');
    } else {
      final nextQuestion = _current;

      if (nextQuestion != null) {
        if (nextQuestion.introText != null) {
          nextAiMsgs.add(nextQuestion.introText!);
        }
        nextAiMsgs.add(nextQuestion.questionText);
      }
    }

    await _enqueueAiMessages(nextAiMsgs);
  }

  void _finish() {
    final profile = DiagnosisProfile(
      Map.of(_answers),
      completedAt: DateTime.now(),
    );

    final state = context.read<AppState>();
    state.saveDiagnosis(profile);
    state.updateUser((u) => u.copyWith(
          diagnosed: true,
          currentStep: 1,
          interests: profile.interests.isEmpty
              ? u.interests
              : profile.interests,
        ));

    context.read<MainTabs>().go(MainTab.home);
    AppNav.resetTo(context, Routes.main);
  }

  @override
  Widget build(BuildContext context) {
    final percent = (_progressRatio * 100).round();
    final showBottomCta = _done && !_isTyping;

    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        title: const Text('알아보기'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                _done ? '완료' : '$percent%',
                style: AppText.caption.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(6),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOutCubic,
              tween: Tween<double>(end: _progressRatio),
              builder: (context, animatedValue, _) {
                return ProgressLine(
                  value: (animatedValue * 100).round(),
                  total: 100,
                );
              },
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ShaderMask(
                shaderCallback: (Rect bounds) {
                  return LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.paper.withValues(alpha: 1.0 - _topFadeStrength),
                      AppColors.paper,
                      AppColors.paper,
                    ],
                    // 상단 페이드 영역을 얇게(8%) 줄여 자연스럽게 처리
                    stops: const [0.0, 0.08, 1.0],
                  ).createShader(bounds);
                },
                blendMode: BlendMode.dstIn,
                child: ListView(
                  controller: _scroll,
                  // 억지 하단 여백 제거 → 말풍선이 쌓이는 만큼만 자연스럽게 스크롤
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
                  children: [
                    Text('한걸음', style: AppText.caption),
                    const SizedBox(height: 12),

                    for (int i = 0; i < _msgs.length; i++)
                      _AnimatedBubble(
                        key: ValueKey('msg_$i'),
                        text: _msgs[i].$2,
                        fromMe: _msgs[i].$1,
                      ),

                    const SizedBox(height: 14),

                    if (!_done && !_isTyping && _current != null)
                      TweenAnimationBuilder<double>(
                        duration: const Duration(milliseconds: 260),
                        curve: Curves.easeOut,
                        tween: Tween<double>(begin: 0.0, end: 1.0),
                        builder: (context, value, child) {
                          return Opacity(
                            opacity: value,
                            child: Transform.translate(
                              offset: Offset(0, (1 - value) * 6),
                              child: child,
                            ),
                          );
                        },
                        child: ChipWrap(
                          children: [
                            for (final option in _current!.options)
                              SelectChip(
                                label: option,
                                selected: false,
                                dark: true,
                                onTap: () => _answer(option),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),

            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              child: showBottomCta
                  ? Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                      decoration: BoxDecoration(
                        color: AppColors.paper,
                        border: Border(
                          top: BorderSide(color: AppColors.soft, width: 1),
                        ),
                      ),
                      child: AppButton(
                        label: '진단 완료 · 시작하기',
                        onPressed: _finish,
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnimatedBubble extends StatelessWidget {
  const _AnimatedBubble({
    super.key,
    required this.text,
    required this.fromMe,
  });

  final String text;
  final bool fromMe;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      tween: Tween<double>(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 8),
            child: child,
          ),
        );
      },
      child: Align(
        alignment: fromMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          constraints: const BoxConstraints(maxWidth: 300),
          padding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 10,
          ),
          decoration: BoxDecoration(
            color: fromMe ? AppColors.black : AppColors.soft,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(fromMe ? 14 : 4),
              topRight: Radius.circular(fromMe ? 4 : 14),
              bottomLeft: const Radius.circular(14),
              bottomRight: const Radius.circular(14),
            ),
          ),
          child: Text(
            text,
            style: AppText.body.copyWith(
              fontSize: 13.5,
              color: fromMe ? AppColors.paper : AppColors.ink,
            ),
          ),
        ),
      ),
    );
  }
}