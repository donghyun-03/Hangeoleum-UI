// STEP 4 · 취업 — 내 경험 요약 + 채용 공고 (북마크로 스크랩)
// [추가 기능 5] 필터 (지역 · 고용형태 · 경력 · 직무)
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/mock_data.dart';
import '../../models/models.dart';
import '../../router/routes.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/opportunity_card.dart';
import 'step_sort.dart';

final _jobs = mockOpportunities.where((o) => o.step == 4).toList();

/// 필터 그룹: (키, 라벨, 선택지, 공고에서 값 꺼내는 함수)
final _groups = <(String, String, List<String>, String? Function(Opportunity))>[
  ('region', '지역', ['서울', '경기', '인천', '온라인'], (o) => o.region),
  ('employment', '고용형태', ['정규직', '계약직', '인턴'], (o) => o.employment),
  ('career', '경력', ['신입', '경력무관'], (o) => o.career),
  ('field', '직무', _jobs.map((j) => j.field).toSet().toList(), (o) => o.field),
];

class Step4Job extends StatefulWidget {
  const Step4Job({super.key, required this.sort});
  final StepSort sort;

  @override
  State<Step4Job> createState() => _Step4JobState();
}

class _Step4JobState extends State<Step4Job> {
  bool _open = false;
  final Map<String, Set<String>> _f = {for (final g in _groups) g.$1: <String>{}};

  int get _count => _f.values.fold(0, (n, s) => n + s.length);

  void _toggle(String key, String v) {
    setState(() {
      if (!_f[key]!.remove(v)) _f[key]!.add(v);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final list = sortOpportunities(
      _jobs.where((j) => _groups.every((g) => _f[g.$1]!.isEmpty || _f[g.$1]!.contains(g.$4(j)))).toList(),
      widget.sort,
    );

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text('내 경험 요약', style: AppText.bodyBold.copyWith(fontSize: 12.5))),
            GestureDetector(
              onTap: () => Navigator.pushNamed(context, Routes.recordList),
              child: Text('전체 보기 ›', style: AppText.caption),
            ),
          ]),
          const SizedBox(height: 10),
          StatRow(items: [
            (state.missions.where((m) => m.status == MissionStatus.done).length, '완료한 미션'),
            (state.records.length, '활동 기록'),
            (0, '정리한 포트폴리오'),
          ]),
        ]),
      ),

      // ── [추가 기능 5] 필터
      Row(children: [
        Expanded(child: Text('채용 공고 ${list.length}건', style: AppText.bodyBold.copyWith(fontSize: 12.5))),
        if (_count > 0)
          TextButton(
            onPressed: () => setState(() => _f.updateAll((k, v) => <String>{})),
            child: const Text('초기화', style: TextStyle(fontSize: 12, color: AppColors.green)),
          ),
        IconButton(
          tooltip: '필터',
          onPressed: () => setState(() => _open = !_open),
          icon: Icon(Icons.tune, color: _open || _count > 0 ? AppColors.green : AppColors.ink),
        ),
      ]),
      if (_open)
        AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (final (key, label, options, _) in _groups) ...[
              Text(label, style: AppText.bodyBold.copyWith(fontSize: 12, color: AppColors.muted)),
              const SizedBox(height: 6),
              ChipWrap(children: [
                for (final o in options) SelectChip(label: o, selected: _f[key]!.contains(o), onTap: () => _toggle(key, o)),
              ]),
              const SizedBox(height: 12),
            ],
            AppButton(label: '${list.length}건 보기', small: true, onPressed: () => setState(() => _open = false)),
          ]),
        )
      else if (_count > 0)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: ChipWrap(children: [
            for (final (key, _, _, _) in _groups)
              for (final v in _f[key]!) SelectChip(label: '$v ✕', selected: true, onTap: () => _toggle(key, v)),
          ]),
        ),
      if (list.isEmpty) const EmptyState(icon: Icons.filter_alt_off_outlined, title: '조건에 맞는 공고가 없어요', desc: '필터를 줄여 보세요.'),
      for (final o in list) OpportunityCard(o: o, onTap: () => AppNav.toComingSoon(context, o.title)),
    ]);
  }
}
