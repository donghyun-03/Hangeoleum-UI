// [추가 기능 3] 공고 스크랩 · 취업 지원 현황 — 하단 탭
// STEP 3·4 공고 카드의 북마크로 스크랩 → 여기서 지원했는지 / 안 했는지 관리
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/mock_data.dart';
import '../../models/models.dart';
import '../../router/main_tabs.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

enum _Filter { all, todo, applied }

class ScrapScreen extends StatefulWidget {
  const ScrapScreen({super.key});

  @override
  State<ScrapScreen> createState() => _ScrapScreenState();
}

class _ScrapScreenState extends State<ScrapScreen> {
  _Filter _filter = _Filter.all;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    // TODO(API): 공고 상세는 서버에서 opportunityId 로 조회
    final items = [
      for (final s in state.scraps)
        if (findOpportunity(s.opportunityId) case final o?) (s, o),
    ];
    final applied = items.where((x) => x.$1.applied).length;
    final shown = items.where((x) => switch (_filter) {
          _Filter.all => true,
          _Filter.todo => !x.$1.applied,
          _Filter.applied => x.$1.applied,
        });

    return Scaffold(
      appBar: AppBar(title: const Text('공고 스크랩'), centerTitle: false, titleSpacing: 20),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          AppCard(
            child: StatRow(center: true, items: [
              (items.length, '스크랩'),
              (items.length - applied, '지원 전'),
              (applied, '지원 완료'),
            ]),
          ),
          const SizedBox(height: 4),
          ChipWrap(children: [
            for (final (f, label) in [(_Filter.all, '전체'), (_Filter.todo, '지원 전'), (_Filter.applied, '지원 완료')])
              SelectChip(label: label, selected: _filter == f, onTap: () => setState(() => _filter = f)),
          ]),
          const SizedBox(height: 14),
          if (shown.isEmpty)
            const EmptyState(icon: Icons.bookmark_border, title: '스크랩한 공고가 없어요', desc: 'STEP 3·4 공고의 북마크를 눌러 스크랩해 보세요.'),
          for (final (s, o) in shown) _ScrapCard(scrap: s, o: o),
          if (items.isNotEmpty)
            Center(
              child: TextButton(
                onPressed: () => context.read<MainTabs>().go(MainTab.step, step: 4),
                child: Text('공고 더 보러 가기 ›', style: AppText.caption.copyWith(fontSize: 12)),
              ),
            ),
        ],
      ),
    );
  }
}

class _ScrapCard extends StatelessWidget {
  const _ScrapCard({required this.scrap, required this.o});
  final Scrap scrap;
  final Opportunity o;

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Wrap(spacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                TagBadge('STEP ${o.step}', tone: BadgeTone.gray),
                Text(o.step == 4 ? o.field : kindLabel[o.kind]!, style: AppText.caption.copyWith(fontSize: 11)),
                TagBadge('D-${o.dday}', tone: o.dday <= 7 ? BadgeTone.red : BadgeTone.gray),
              ]),
              const SizedBox(height: 4),
              Text(o.title, style: AppText.bodyBold, maxLines: 2, overflow: TextOverflow.ellipsis),
              Text('${o.org} · ${o.region} · 스크랩 ${scrap.scrappedAt.month}/${scrap.scrappedAt.day}', style: AppText.caption.copyWith(fontSize: 12)),
            ]),
          ),
          IconButton(
            tooltip: '스크랩 취소',
            onPressed: () {
              state.toggleScrap(o.id);
              showToast(context, '스크랩을 취소했어요');
            },
            icon: const Icon(Icons.bookmark, color: AppColors.green),
          ),
        ]),
        const SizedBox(height: 12),
        // 지원 여부
        Row(children: [
          for (final (v, label) in [(false, '아직 안 했어요'), (true, '지원했어요')]) ...[
            if (v) const SizedBox(width: 8),
            Expanded(
              child: Material(
                color: scrap.applied == v ? (v ? AppColors.green : AppColors.soft) : AppColors.paper,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  side: BorderSide(color: scrap.applied == v ? (v ? AppColors.green : AppColors.dim) : AppColors.line),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  onTap: () => state.setApplied(o.id, v),
                  child: SizedBox(
                    height: 38,
                    child: Center(
                      child: Text(label,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: scrap.applied == v ? (v ? AppColors.paper : AppColors.ink) : AppColors.subtle,
                          )),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ]),
      ]),
    );
  }
}
