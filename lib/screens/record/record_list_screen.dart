// 활동 기록 목록 (STAR 로 정리된 카드)
// 연필 → 기록 작성 / 경험 리포트·포트폴리오로 만들기
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../router/routes.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

class RecordListScreen extends StatelessWidget {
  const RecordListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text('활동 기록')),
      bottomNavigationBar: BottomBar(
        child: Row(children: [
          Expanded(
            child: AppButton(
              label: '경험 리포트 · 포트폴리오로 만들기',
              onPressed: () => AppNav.toComingSoon(context, '경험 리포트 · 포트폴리오'),
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
                for (final r in state.records) RecordCard(record: r, onDelete: () => state.removeRecord(r.id)),
              ],
            ),
    );
  }
}

/// STAR 기록 카드 (다른 화면에서도 재사용 가능)
class RecordCard extends StatelessWidget {
  const RecordCard({super.key, required this.record, this.onDelete});
  final ActivityRecord record;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final r = record;
    final rows = [('S', r.star.s), ('T', r.star.t), ('A', r.star.a), ('R', r.star.r)];
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            TagBadge('STEP ${r.step}', tone: BadgeTone.gray),
            const SizedBox(width: 6),
            Text('AI 정리', style: AppText.caption.copyWith(fontSize: 11)),
            const Spacer(),
            Text(r.date, style: AppText.caption.copyWith(fontSize: 11)),
          ]),
          const SizedBox(height: 8),
          Text(r.title, style: AppText.bodyBold),
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
          if (onDelete != null)
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                tooltip: '기록 삭제',
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.subtle),
              ),
            ),
        ],
      ),
    );
  }
}
