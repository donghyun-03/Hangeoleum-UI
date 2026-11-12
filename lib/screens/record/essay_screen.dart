// AI 자기소개서 쓰기 — 경험 리포트의 'AI로 자기소개서 쓰기' 에서 진입
// ① 목표(희망 기업·직무, 없으면 관심 분야) → ② 활동 고르기(AI 추천은 미리 체크, 사용자가 바꿈) → ③ 문항·글자 수 고르고 쓰기
// 사용자가 최종 선택을 하고, AI 는 이유·보완 팁·부족한 경험을 알려 준 뒤 고른 활동으로 글을 써요.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../services/essay_service.dart';
import '../../services/star_service.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

const _jobChips = ['서비스 기획', '데이터 분석', '개발', '마케팅', '디자인', '사무 행정'];
const _stepLabels = ['목표', '활동 고르기', '자소서'];
const _limits = [300, 500, 800, 1000];

class EssayScreen extends StatefulWidget {
  const EssayScreen({super.key});

  @override
  State<EssayScreen> createState() => _EssayScreenState();
}

class _EssayScreenState extends State<EssayScreen> {
  int _step = 0;
  // TODO: 회원 정보에 희망 기업·직무가 생기면 여기에 미리 채우기
  final _company = TextEditingController();
  final _job = TextEditingController();
  String _companyType = companyTypes.last;

  // ② 활동 고르기
  Recommendation? _rec;
  final List<String> _picked = []; // 고른 순서 = 글에서 중요한 순서

  // ③ 자소서
  String _questionKey = essayQuestions.keys.first;
  final _customQuestion = TextEditingController(); // 회사 문항 직접 입력 (있으면 이걸 써요)
  int _limit = 500;
  Essay? _essay;
  ({String question, int limit, List<String> picked})? _written; // 마지막으로 쓴 조건
  final Map<String, TextEditingController> _answers = {}; // AI 질문 → 답

  bool _loading = false;
  String? _error;

  EssayTarget get _target => EssayTarget(
    company: _company.text.trim(),
    job: _job.text.trim(),
    companyType: _companyType,
    interests: context.read<AppState>().user.interests,
  );

  String get _question => _customQuestion.text.trim().isNotEmpty ? _customQuestion.text.trim() : essayQuestions[_questionKey]!;

  /// 글을 쓴 뒤 문항·글자 수·활동을 바꿨는지
  bool get _changed {
    final w = _written;
    return w != null && (w.question != _question || w.limit != _limit || w.picked.join() != _picked.join());
  }

  @override
  void initState() {
    super.initState();
    for (final c in [_job, _company, _customQuestion]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    _job.dispose();
    _company.dispose();
    _customQuestion.dispose();
    for (final c in _answers.values) {
      c.dispose();
    }
    super.dispose();
  }

  // 답을 적으면 '답 넣고 다시 쓰기' 버튼이 바로 보이게 다시 그려요
  TextEditingController _answerOf(String q) => _answers.putIfAbsent(q, () => TextEditingController()..addListener(() => setState(() {})));

  /// AI 를 부르는 곳은 모두 여기를 거쳐요 (로딩·오류 표시를 한 곳에서)
  Future<void> _run(Future<void> Function() job) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await job();
    } catch (e) {
      if (mounted) setState(() => _error = 'AI가 답하지 못했어요. 잠시 뒤 다시 눌러 주세요. ($e)');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ① → ② : AI 추천을 받고, 추천한 활동을 미리 체크해 둬요
  Future<void> _recommend({bool keepPicked = false}) => _run(() async {
    final records = context.read<AppState>().records;
    final rec = await essayService.recommend(_target, records);
    if (!mounted) return;
    setState(() {
      _rec = rec;
      _step = 1;
      if (!keepPicked) {
        _picked
          ..clear()
          ..addAll(rec.recommendedIds);
      }
    });
  });

  // ③ 고른 활동으로 자소서 쓰기 (답을 넣으면 그 답까지 써요)
  Future<void> _write({bool withAnswers = false}) => _run(() async {
    final records = context.read<AppState>().records;
    final picked = [
      for (final id in _picked)
        for (final r in records)
          if (r.id == id) r,
    ];
    final answers = withAnswers ? {for (final e in _answers.entries) e.key: e.value.text} : const <String, String>{};
    final question = _question, limit = _limit, ids = [..._picked];
    final essay = await essayService.write(_target, picked, question: question, limit: limit, answers: answers);
    if (!mounted) return;
    setState(() {
      _essay = essay;
      _written = (question: question, limit: limit, picked: ids);
      for (final c in _answers.values) {
        c.dispose();
      }
      _answers.clear();
    });
  });

  void _toggle(String id) => setState(() => _picked.contains(id) ? _picked.remove(id) : _picked.add(id));

  void _move(String id, int by) => setState(() {
    final i = _picked.indexOf(id), j = i + by;
    if (i < 0 || j < 0 || j >= _picked.length) return;
    _picked
      ..removeAt(i)
      ..insert(j, id);
  });

  void _back() {
    if (_step == 0 || _loading) {
      Navigator.pop(context);
    } else {
      setState(() {
        _step--;
        _error = null;
      });
    }
  }

  /// 부족한 경험을 이 화면에서 바로 적기 (AI 가 STAR 로 정리해서 저장)
  Future<void> _addExperience(ExperienceGap? gap) async {
    final added = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.paper,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg))),
      builder: (_) => _QuickRecordSheet(gap: gap),
    );
    if (added == true && mounted) {
      showToast(context, '경험을 기록했어요. 추천을 다시 받아요.');
      await _recommend(keepPicked: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return PopScope(
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('AI 자기소개서')),
        bottomNavigationBar: BottomBar(child: _bottom(state)),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _StepHeader(step: _step),
            const SizedBox(height: 16),
            if (essayService is FallbackEssayService) const TodoBox('지금은 AI 키 없이 실행 중이라 예시로만 채워져요.'),
            ...switch (_step) {
              0 => _goalStep(),
              1 => _pickStep(state.records),
              _ => _essayStep(state),
            },
            ErrorText(_error),
          ],
        ),
      ),
    );
  }

  Widget _bottom(AppState state) {
    if (_loading) return AppButton(label: _step == 2 ? 'AI가 자소서를 쓰는 중…' : 'AI가 추천하는 중…', onPressed: null);
    final essay = _essay;
    return switch (_step) {
      0 => AppButton(label: '다음: AI 추천 받기', onPressed: _target.focus.isEmpty || state.records.isEmpty ? null : _recommend),
      1 => AppButton(label: '다음: 문항 고르기 (${_picked.length}개)', onPressed: _picked.isEmpty ? null : () => setState(() => _step = 2)),
      _ => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (essay != null && _answers.values.any((c) => c.text.trim().isNotEmpty)) ...[
            AppButton(label: '답 넣고 다시 쓰기', onPressed: () => _write(withAnswers: true)),
            const SizedBox(height: 8),
          ],
          AppButton(
            label: essay == null
                ? '자기소개서 쓰기'
                : _changed
                ? '이 조건으로 다시 쓰기'
                : '다시 쓰기',
            icon: Icons.edit_note,
            variant: essay != null && !_changed ? ButtonVariant.outline : ButtonVariant.primary,
            onPressed: _write,
          ),
        ],
      ),
    };
  }

  // ── ① 목표
  List<Widget> _goalStep() => [
    Text('어디에 낼 자기소개서인가요?', style: AppText.h2.copyWith(fontSize: 16)),
    const SizedBox(height: 4),
    Text('기업과 직무(없으면 관심 분야)에 맞춰 AI가 활동을 추천하고 문장을 다듬어요.', style: AppText.small),
    const SizedBox(height: 16),
    Text('희망 기업 (선택)', style: AppText.caption),
    const SizedBox(height: 6),
    LabeledField(controller: _company, hint: '예: 카카오, 한국전력공사'),
    const SizedBox(height: 16),
    Text('지원 직무', style: AppText.caption),
    const SizedBox(height: 6),
    LabeledField(controller: _job, hint: '예: 서비스 기획 (아직 없으면 비워 두세요)'),
    const SizedBox(height: 8),
    ChipWrap(
      children: [for (final j in _jobChips) SelectChip(label: j, selected: _job.text.trim() == j, onTap: () => _job.text = j)],
    ),
    if (_job.text.trim().isEmpty) ...[
      const SizedBox(height: 8),
      _Note(
        icon: Icons.info_outline,
        text: _target.interests.isEmpty ? '직무나 관심 분야 중 하나는 있어야 추천할 수 있어요.' : '직무를 비워 두면 관심 분야(${_target.interests.join(', ')})에 맞춰 추천해요.',
        warn: _target.interests.isEmpty,
      ),
    ],
    const SizedBox(height: 18),
    Text('회사 유형', style: AppText.caption),
    const SizedBox(height: 6),
    ChipWrap(
      children: [
        for (final c in companyTypes) SelectChip(label: c, selected: c == _companyType, onTap: () => setState(() => _companyType = c)),
      ],
    ),
    if (isBlind(_companyType)) ...[
      const SizedBox(height: 10),
      const _Note(icon: Icons.visibility_off_outlined, text: '공공기관은 블라인드 채용이에요. 학교·지역 같은 정보는 빼고 만들어요.'),
    ],
  ];

  // ── ② 활동 고르기
  List<Widget> _pickStep(List<ActivityRecord> records) {
    final rec = _rec;
    return [
      Text('넣을 활동을 골라 주세요', style: AppText.h2.copyWith(fontSize: 16)),
      const SizedBox(height: 4),
      Text('AI 추천을 미리 체크해 뒀어요. 빼거나 더 넣어도 돼요. 2~3개가 가장 좋아요.', style: AppText.small),
      const SizedBox(height: 12),
      // 부족한 경험 → 바로 기록
      if (rec != null && rec.gaps.isNotEmpty)
        AppCard(
          color: AppColors.amberLight,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('이런 경험이 있으면 더 좋아요', style: AppText.bodyBold.copyWith(fontSize: 13, color: AppColors.amber)),
              for (final g in rec.gaps) ...[
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TagBadge(g.competency, tone: BadgeTone.amber),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(g.message, style: AppText.small.copyWith(fontSize: 12.5, color: AppColors.ink)),
                    ),
                  ],
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: _loading ? null : () => _addExperience(g),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('이 경험 기록하기'),
                  ),
                ),
              ],
            ],
          ),
        ),
      for (final r in records) _recordTile(r, rec?.advice[r.id]),
      const SizedBox(height: 4),
      OutlinedButton.icon(
        onPressed: _loading ? null : () => _addExperience(null),
        icon: const Icon(Icons.add, size: 18),
        label: const Text('다른 경험 추가하기'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.muted,
          minimumSize: const Size.fromHeight(44),
          side: const BorderSide(color: AppColors.dim),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
        ),
      ),
    ];
  }

  Widget _recordTile(ActivityRecord r, RecordAdvice? a) {
    final order = _picked.indexOf(r.id);
    final on = order >= 0;
    final recommended = a?.recommended ?? false;
    return AppCard(
      margin: const EdgeInsets.only(bottom: 8),
      color: on ? AppColors.greenLight : null,
      onTap: () => _toggle(r.id),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 고른 순서 번호
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: on ? AppColors.green : AppColors.paper,
              shape: BoxShape.circle,
              border: Border.all(color: on ? AppColors.green : AppColors.dim),
            ),
            child: on
                ? Text(
                    '${order + 1}',
                    style: AppText.caption.copyWith(color: AppColors.paper, fontWeight: FontWeight.w700),
                  )
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(r.title, style: AppText.bodyBold.copyWith(fontSize: 13.5))),
                    if (recommended) const TagBadge('AI 추천'),
                  ],
                ),
                Text(r.date, style: AppText.caption),
                if (a != null && a.reason.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(a.reason, style: AppText.small.copyWith(fontSize: 12)),
                ],
                // 고른 활동에는 보완 팁을 보여 줘요 (추천 밖이면 노란색으로 더 눈에 띄게)
                if (on && a != null && a.tip.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  _Note(icon: Icons.lightbulb_outline, text: a.tip, warn: !recommended),
                ],
              ],
            ),
          ),
          if (on && _picked.length > 1)
            Column(
              children: [
                _MoveButton(icon: Icons.keyboard_arrow_up, tooltip: '${r.title} 앞으로', onTap: order == 0 ? null : () => _move(r.id, -1)),
                _MoveButton(
                  icon: Icons.keyboard_arrow_down,
                  tooltip: '${r.title} 뒤로',
                  onTap: order == _picked.length - 1 ? null : () => _move(r.id, 1),
                ),
              ],
            ),
        ],
      ),
    );
  }

  // ── ③ 자소서
  List<Widget> _essayStep(AppState state) {
    final essay = _essay;
    final titles = {for (final r in state.records) r.id: r.title};
    return [
      Text('어떤 문항에 답할까요?', style: AppText.h2.copyWith(fontSize: 16)),
      const SizedBox(height: 4),
      Text('고른 활동 ${_picked.length}개로 글 한 편을 써요.', style: AppText.small),
      const SizedBox(height: 12),
      ChipWrap(
        children: [
          for (final q in essayQuestions.keys)
            SelectChip(
              label: q,
              selected: _customQuestion.text.trim().isEmpty && q == _questionKey,
              onTap: () => setState(() {
                _questionKey = q;
                _customQuestion.clear();
              }),
            ),
        ],
      ),
      const SizedBox(height: 8),
      LabeledField(controller: _customQuestion, hint: '회사 문항이 있으면 그대로 붙여 넣어 주세요 (선택)', maxLines: 2),
      const SizedBox(height: 4),
      Text(_question, style: AppText.caption),
      const SizedBox(height: 14),
      Text('글자 수 (공백 포함)', style: AppText.caption),
      const SizedBox(height: 6),
      ChipWrap(
        children: [for (final n in _limits) SelectChip(label: '$n자', selected: n == _limit, onTap: () => setState(() => _limit = n))],
      ),
      const SizedBox(height: 16),
      if (essay == null)
        AppCard(
          color: AppColors.soft,
          child: Text('문항과 글자 수를 고르고 아래 "자기소개서 쓰기"를 눌러 주세요.', style: AppText.small),
        )
      else ...[
        if (_changed)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text('조건을 바꿨어요. 아래 글은 ${_written!.limit}자로 쓴 이전 글이에요.', style: AppText.caption.copyWith(color: AppColors.amber)),
          ),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${essay.length}/${_written!.limit}자',
                      style: AppText.caption.copyWith(color: essay.length > _written!.limit ? AppColors.red : AppColors.greenDark),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: essay.text));
                      showToast(context, '자기소개서를 복사했어요');
                    },
                    icon: const Icon(Icons.copy, size: 16),
                    label: const Text('전체 복사'),
                  ),
                ],
              ),
              if (essay.title.isNotEmpty) Text(essay.title, style: AppText.bodyBold),
              const SizedBox(height: 8),
              SelectableText(essay.body, style: AppText.body.copyWith(height: 1.7)),
              if (essay.usedIds.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [for (final id in essay.usedIds) TagBadge('근거 · ${titles[id] ?? id}', tone: BadgeTone.gray)],
                ),
              ],
            ],
          ),
        ),
        // AI 가 물어본 질문 — 답하면 숫자·역할이 들어간 글로 다시 써요
        if (essay.questions.isNotEmpty)
          AppCard(
            color: AppColors.soft,
            margin: const EdgeInsets.only(top: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('이걸 알려 주면 더 좋아져요', style: AppText.bodyBold.copyWith(fontSize: 13)),
                for (final q in essay.questions) ...[
                  const SizedBox(height: 10),
                  Text(q, style: AppText.small.copyWith(fontSize: 12.5, color: AppColors.ink)),
                  const SizedBox(height: 6),
                  LabeledField(controller: _answerOf(q), hint: '짧게 적어도 돼요'),
                ],
              ],
            ),
          ),
      ],
      const SizedBox(height: 8),
      AppButton(label: '활동 다시 고르기', variant: ButtonVariant.ghost, onPressed: () => setState(() => _step = 1)),
    ];
  }
}

class _StepHeader extends StatelessWidget {
  const _StepHeader({required this.step});
  final int step;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final (i, label) in _stepLabels.indexed) ...[
          if (i > 0) Expanded(child: Container(height: 1, color: i <= step ? AppColors.green : AppColors.line)),
          Column(
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: i <= step ? AppColors.green : AppColors.soft,
                child: Text(
                  '${i + 1}',
                  style: AppText.caption.copyWith(color: i <= step ? AppColors.paper : AppColors.subtle, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 4),
              Text(label, style: AppText.caption.copyWith(color: i == step ? AppColors.ink : AppColors.subtle)),
            ],
          ),
        ],
      ],
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.icon, required this.text, this.warn = false});
  final IconData icon;
  final String text;
  final bool warn;

  @override
  Widget build(BuildContext context) {
    final fg = warn ? AppColors.amber : AppColors.greenDark;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: fg),
        const SizedBox(width: 6),
        Expanded(
          child: Text(text, style: AppText.small.copyWith(fontSize: 12, color: fg)),
        ),
      ],
    );
  }
}

class _MoveButton extends StatelessWidget {
  const _MoveButton({required this.icon, required this.tooltip, required this.onTap});
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: tooltip,
    onPressed: onTap,
    icon: Icon(icon, size: 20),
    color: AppColors.muted,
    visualDensity: VisualDensity.compact,
    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
    padding: EdgeInsets.zero,
  );
}

/// 부족한 경험을 바로 적는 창 → AI 가 STAR 로 정리해서 활동 기록에 저장
class _QuickRecordSheet extends StatefulWidget {
  const _QuickRecordSheet({this.gap});
  final ExperienceGap? gap;

  @override
  State<_QuickRecordSheet> createState() => _QuickRecordSheetState();
}

class _QuickRecordSheetState extends State<_QuickRecordSheet> {
  final _text = TextEditingController();
  bool _loading = false;
  String? _question;
  String? _error;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final text = _text.text.trim();
    if (text.length < 5) {
      setState(() => _error = '어떤 경험인지 조금만 더 적어 주세요.');
      return;
    }
    final state = context.read<AppState>();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await starService.makeStar(text);
      if (!mounted) return;
      if (r.needMoreInfo || r.star == null) {
        setState(() {
          _loading = false;
          _question = r.followUpQuestion ?? '무엇을 했는지 조금만 더 적어 주세요.';
        });
        return;
      }
      final now = DateTime.now();
      final first = text.split('\n').first;
      state.saveRecord(
        ActivityRecord(
          id: 'rec-${now.microsecondsSinceEpoch}',
          step: state.user.currentStep,
          title: r.title ?? (first.length > 24 ? first.substring(0, 24) : first),
          // YYYY-MM-DD (예: 2026-10-16)
          date: '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
          raw: text,
          star: r.star!,
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'AI가 정리하지 못했어요. 잠시 뒤 다시 눌러 주세요. ($e)';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final gap = widget.gap;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(gap == null ? '경험 추가하기' : '${gap.competency} 경험 기록하기', style: AppText.h2.copyWith(fontSize: 16)),
          const SizedBox(height: 4),
          Text(gap?.message ?? '자소서에 쓰고 싶은 경험을 편하게 적어 주세요.', style: AppText.small),
          if (_question != null) ...[const SizedBox(height: 10), _Note(icon: Icons.help_outline, text: 'AI가 궁금해해요: $_question')],
          const SizedBox(height: 12),
          LabeledField(controller: _text, hint: '예) 4명이 팀으로 공모전에 나가 내가 화면 설계를 맡음. 30팀 중 3등.', maxLines: 5),
          ErrorText(_error),
          const SizedBox(height: 12),
          AppButton(label: _loading ? 'AI가 정리하는 중…' : 'AI로 정리해서 추가', onPressed: _loading ? null : _save),
        ],
      ),
    );
  }
}
