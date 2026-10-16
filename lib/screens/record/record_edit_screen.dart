// 기록 수정 — 저장된 기록의 제목 · STAR 를 항목별로 고쳐서 저장
// 오른쪽 위 휴지통 → 기록 삭제
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

class RecordEditScreen extends StatefulWidget {
  const RecordEditScreen({super.key, required this.record});
  final ActivityRecord record;

  @override
  State<RecordEditScreen> createState() => _RecordEditScreenState();
}

class _RecordEditScreenState extends State<RecordEditScreen> {
  late final _title = TextEditingController(text: widget.record.title);
  late Star _star = widget.record.star;
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
    final title = _title.text.trim();
    context.read<AppState>().saveRecord(
          widget.record.copyWith(title: title.isEmpty ? widget.record.title : title, star: _star),
        );
    showToast(context, '기록을 수정했어요');
    Navigator.pop(context);
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('기록을 삭제할까요?'),
        content: Text(widget.record.title, style: AppText.small),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제', style: TextStyle(color: AppColors.red)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    context.read<AppState>().removeRecord(widget.record.id);
    showToast(context, '기록을 삭제했어요');
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('기록 수정하기'),
        actions: [
          IconButton(
            tooltip: '기록 삭제',
            onPressed: _delete,
            icon: const Icon(Icons.delete_outline, color: AppColors.subtle),
          ),
        ],
      ),
      bottomNavigationBar: BottomBar(child: AppButton(label: '저장하기', onPressed: _save)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ── STAR 항목별 수정 (AI 정리 결과 화면과 같은 방식)
          AppCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget.record.date, style: AppText.caption.copyWith(fontSize: 11)),
              const SizedBox(height: 8),
              LabeledField(label: '제목', controller: _title),
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
            ]),
          ),
        ],
      ),
    );
  }
}
