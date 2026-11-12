// AI 정리 결과 — STAR 항목을 확인·수정 후 저장
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../router/routes.dart';
import '../../services/star_service.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

class RecordResultScreen extends StatefulWidget {
  const RecordResultScreen({super.key, required this.draft, this.questions = const []});
  final ActivityRecord draft;

  /// AI 가 "이걸 알려 주면 더 좋아져요" 하고 물어본 질문 (최대 2개)
  final List<String> questions;

  @override
  State<RecordResultScreen> createState() => _RecordResultScreenState();
}

class _RecordResultScreenState extends State<RecordResultScreen> {
  late final _title = TextEditingController(text: widget.draft.title);
  late Star _star = widget.draft.star;
  String? _editing; // 's' | 't' | 'a' | 'r'
  late String _raw = widget.draft.raw; // 답이 붙으면 늘어나는 원문
  late List<String> _questions = widget.questions;
  final Map<String, TextEditingController> _answers = {};
  bool _loading = false;
  String? _error;

  TextEditingController _answerOf(String q) => _answers.putIfAbsent(q, TextEditingController.new);

  // 질문에 답한 내용을 붙여 AI 에게 다시 정리받아요
  Future<void> _improve() async {
    final answers = {for (final q in _questions) q: _answerOf(q).text};
    if (answers.values.every((v) => v.trim().isEmpty)) {
      setState(() => _error = '질문 하나에라도 답을 적어 주세요.');
      return;
    }
    final memo = memoWithAnswers(_raw, answers);
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await starService.makeStar(memo);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _raw = memo;
        if (r.star != null) _star = r.star!;
        // 사용자가 제목을 안 고쳤을 때만 새 제목으로 바꿔요
        if (r.title != null && _title.text == widget.draft.title) _title.text = r.title!;
        _editing = null;
        for (final c in _answers.values) {
          c.dispose();
        }
        _answers.clear();
        _questions = r.improveQuestions;
      });
      showToast(context, '답을 넣어 다시 정리했어요');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'AI가 정리하지 못했어요. 잠시 뒤 다시 눌러 주세요. ($e)';
      });
    }
  }

  static const _labels = {'s': 'S 상황', 't': 'T 목표', 'a': 'A 행동', 'r': 'R 결과'};

  @override
  void dispose() {
    _title.dispose();
    for (final c in _answers.values) {
      c.dispose();
    }
    super.dispose();
  }

  String _get(String k) => switch (k) { 's' => _star.s, 't' => _star.t, 'a' => _star.a, _ => _star.r };

  void _set(String k, String v) => _star = switch (k) {
        's' => _star.copyWith(s: v),
        't' => _star.copyWith(t: v),
        'a' => _star.copyWith(a: v),
        _ => _star.copyWith(r: v),
      };

  void _save() {
    context.read<AppState>().saveRecord(widget.draft.copyWith(title: _title.text.trim(), star: _star, raw: _raw));
    showToast(context, '기록을 저장했어요');
    // 활동 기록 목록에서 왔으면 거기로, 홈에서 바로 왔으면 활동 기록을 새로 열기
    final nav = Navigator.of(context);
    var foundList = false;
    nav.popUntil((r) {
      if (r.settings.name == Routes.recordList) foundList = true;
      return foundList || r.isFirst;
    });
    if (!foundList) nav.pushNamed(Routes.recordList);
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.draft;
    return Scaffold(
      appBar: AppBar(title: const Text('AI가 정리했어요')),
      bottomNavigationBar: BottomBar(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          AppButton(label: '저장하기', onPressed: _loading ? null : _save),
          const SizedBox(height: 8),
          AppButton(label: '다시 정리하기', variant: ButtonVariant.ghost, onPressed: () => Navigator.pop(context)),
        ]),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          AppCard(
            color: AppColors.soft,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('내가 적은 내용을 정리했어요', style: AppText.bodyBold.copyWith(fontSize: 13)),
              Text('확인하고 고친 뒤에 저장하세요.', style: AppText.small.copyWith(fontSize: 12)),
            ]),
          ),
          AppCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              TagBadge('STEP ${d.step}', tone: BadgeTone.gray),
              const SizedBox(height: 8),
              LabeledField(controller: _title),
              for (final k in _labels.keys) ...[
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(child: Text(_labels[k]!, style: AppText.bodyBold.copyWith(fontSize: 12, color: AppColors.green))),
                  GestureDetector(
                    onTap: () => setState(() => _editing = _editing == k ? null : k),
                    child: Text(_editing == k ? '완료' : '수정', style: AppText.caption),
                  ),
                ]),
                const SizedBox(height: 4),
                if (_editing == k)
                  LabeledField(initialValue: _get(k), maxLines: 4, onChanged: (v) => _set(k, v))
                else
                  Text(_get(k), style: AppText.small.copyWith(fontSize: 13)),
              ],
              if (d.attachments.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text('첨부 ${d.attachments.length}개', style: AppText.bodyBold.copyWith(fontSize: 12, color: AppColors.muted)),
                for (final a in d.attachments)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(children: [
                      Icon(a.type == AttachmentType.github ? Icons.code : Icons.insert_drive_file_outlined, size: 14, color: AppColors.subtle),
                      const SizedBox(width: 6),
                      Expanded(child: Text(a.name, style: AppText.caption.copyWith(color: AppColors.muted), overflow: TextOverflow.ellipsis)),
                    ]),
                  ),
              ],
            ]),
          ),
          // AI 가 물어본 질문 — 답하면 숫자·역할이 들어간 STAR 로 다시 정리
          if (_questions.isNotEmpty)
            AppCard(
              color: AppColors.soft,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('이걸 알려 주면 더 좋아져요', style: AppText.bodyBold.copyWith(fontSize: 13)),
                Text('숫자나 맡은 역할이 들어가면 자소서에 쓰기 좋아요.', style: AppText.small.copyWith(fontSize: 12)),
                for (final q in _questions) ...[
                  const SizedBox(height: 12),
                  Text(q, style: AppText.body.copyWith(fontSize: 13)),
                  const SizedBox(height: 6),
                  LabeledField(controller: _answerOf(q), hint: '짧게 적어도 돼요', maxLines: 2),
                ],
                ErrorText(_error),
                const SizedBox(height: 12),
                AppButton(
                  label: _loading ? 'AI가 다시 정리하는 중…' : '답 넣고 다시 정리하기',
                  variant: ButtonVariant.outline,
                  onPressed: _loading ? null : _improve,
                ),
              ]),
            ),
        ],
      ),
    );
  }
}
