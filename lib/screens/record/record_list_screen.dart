// 활동 기록 목록 (STAR 로 정리된 카드)
// 연필 → 기록 작성 / 카드의 수정 → 기록 수정(삭제는 그 안에서) / 경험 리포트·포트폴리오로 만들기
// 검색창: 제목 · 원문 · STAR 내용으로 찾기
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../router/routes.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import 'record_edit_screen.dart';

class RecordListScreen extends StatefulWidget {
  const RecordListScreen({super.key});

  @override
  State<RecordListScreen> createState() => _RecordListScreenState();
}

class _RecordListScreenState extends State<RecordListScreen> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// 'YYYY-MM-DD' → 정렬용 숫자 (예: 2026-10-16 → 20261016)
  static int _dateKey(String date) {
    final parts = date.split('-');
    if (parts.length != 3) return 0;
    return parts.fold(0, (sum, p) => sum * 100 + (int.tryParse(p) ?? 0));
  }

  /// 제목 · 원문 · STAR 에 검색어가 들어 있는지
  static bool _matches(ActivityRecord r, String q) =>
      [r.title, r.raw, r.star.s, r.star.t, r.star.a, r.star.r].any((t) => t.toLowerCase().contains(q));

  void _openEdit(ActivityRecord r) =>
      Navigator.push(context, MaterialPageRoute<void>(builder: (_) => RecordEditScreen(record: r)));

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    // 날짜 순(오래된 기록 → 최근 기록)으로 정렬
    final sorted = [...state.records]..sort((a, b) => _dateKey(a.date).compareTo(_dateKey(b.date)));
    final q = _search.text.trim().toLowerCase();
    final shown = q.isEmpty ? sorted : sorted.where((r) => _matches(r, q)).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('활동 기록')),
      bottomNavigationBar: BottomBar(
        child: Row(children: [
          // 좁은 폰에서는 글자가 넘치지 않게 버튼을 살짝 줄여서 보여 줌
          Expanded(
            child: LayoutBuilder(
              builder: (context, box) => FittedBox(
                fit: BoxFit.scaleDown,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: box.maxWidth),
                  child: AppButton(
                    label: '경험 리포트·포트폴리오로 만들기',
                    expand: false,
                    onPressed: () => AppNav.toComingSoon(context, '경험 리포트 · 포트폴리오'),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.outlined(
            tooltip: '기록 작성',
            style: IconButton.styleFrom(side: const BorderSide(color: AppColors.green), fixedSize: const Size(50, 50)),
            onPressed: () => AppNav.toRecordWrite(context),
            icon: const Icon(Icons.edit_outlined, color: AppColors.green),
          ),
        ]),
      ),
      body: state.records.isEmpty
          ? const EmptyState(icon: Icons.edit_note, title: '아직 기록이 없어요', desc: '오늘 한 일을 짧게라도 남겨 보세요.')
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                SearchField(
                  controller: _search,
                  hint: '제목이나 내용으로 기록 찾기',
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 14),
                if (shown.isEmpty)
                  const EmptyState(icon: Icons.search_off, title: '찾는 기록이 없어요', desc: '다른 단어로 검색해 보세요.')
                else
                  for (var i = 0; i < shown.length; i++)
                    RecordCard(
                      record: shown[i],
                      // 검색 중에는 순서 번호를 숨김
                      order: q.isEmpty ? '${i + 1}/${shown.length}' : null,
                      onEdit: () => _openEdit(shown[i]),
                    ),
              ],
            ),
    );
  }
}

/// STAR 기록 카드 (다른 화면에서도 재사용 가능)
class RecordCard extends StatelessWidget {
  const RecordCard({super.key, required this.record, this.order, this.onEdit});
  final ActivityRecord record;

  /// 목록 안 순서 (예: 1/3). 없으면 안 보임
  final String? order;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final r = record;
    final rows = [('S', r.star.s), ('T', r.star.t), ('A', r.star.a), ('R', r.star.r)];
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(child: Text(r.title, style: AppText.bodyBold)),
            if (order != null) ...[
              const SizedBox(width: 8),
              Text(order!, style: AppText.caption.copyWith(fontSize: 11)),
            ],
          ]),
          Text(r.date, style: AppText.caption.copyWith(fontSize: 11)),
          const SizedBox(height: 6),
          for (final (k, v) in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox(width: 16, child: Text(k, style: AppText.bodyBold.copyWith(fontSize: 12, color: AppColors.green))),
                Expanded(child: Text(v, style: AppText.small.copyWith(fontSize: 12))),
              ]),
            ),
          if (r.attachments.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final a in r.attachments)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: AppColors.soft, borderRadius: BorderRadius.circular(6)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(a.type == AttachmentType.github ? Icons.code : Icons.attach_file, size: 13, color: AppColors.muted),
                    const SizedBox(width: 4),
                    Text(a.name, style: AppText.caption.copyWith(fontSize: 11, color: AppColors.muted)),
                  ]),
                ),
            ]),
          ],
          if (onEdit != null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onEdit,
                style: TextButton.styleFrom(foregroundColor: AppColors.muted, visualDensity: VisualDensity.compact),
                icon: const Icon(Icons.edit_outlined, size: 15),
                label: Text('수정', style: AppText.caption.copyWith(color: AppColors.muted)),
              ),
            ),
        ],
      ),
    );
  }
}
