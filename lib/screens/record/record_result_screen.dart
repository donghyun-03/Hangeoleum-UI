// AI 정리 결과 — STAR 항목을 확인·수정 후 저장
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../router/routes.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

class RecordResultScreen extends StatefulWidget {
  const RecordResultScreen({super.key, required this.draft});
  final ActivityRecord draft;

  @override
  State<RecordResultScreen> createState() => _RecordResultScreenState();
}

class _RecordResultScreenState extends State<RecordResultScreen> {
  late final _title = TextEditingController(text: widget.draft.title);
  late Star _star = widget.draft.star;
  String? _editing; // 's' | 't' | 'a' | 'r'

  static const _labels = {'s': 'S 상황', 't': 'T 목표', 'a': 'A 행동', 'r': 'R 결과'};

  @override
  void dispose() {
    _title.dispose();
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
    context.read<AppState>().saveRecord(widget.draft.copyWith(title: _title.text.trim(), star: _star));
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
          AppButton(label: '저장하기', onPressed: _save),
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
        ],
      ),
    );
  }
}
