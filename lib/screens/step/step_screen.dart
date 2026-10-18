// STEP 탭 — 상단 STEP 1~4 선택 + 정렬(추천·마감·이름)
// 각 STEP 내용은 같은 폴더의 step1_missions / step2_connect / step3_challenge / step4_job 에서 구현합니다.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/mock_data.dart';
import '../../router/main_tabs.dart';
import '../../router/routes.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import 'step1_missions.dart';
import 'step2_connect.dart';
import 'step3_challenge.dart';
import 'step4_job.dart';
import 'step_sort.dart';

class StepScreen extends StatefulWidget {
  const StepScreen({super.key});

  @override
  State<StepScreen> createState() => _StepScreenState();
}

class _StepScreenState extends State<StepScreen> {
  StepSort _sort = StepSort.recommend;

  @override
  Widget build(BuildContext context) {
    final tabs = context.watch<MainTabs>();
    final appState = context.watch<AppState>();
    final isInstitution = appState.isInstitution;
    final appliedCount = appState.appliedScraps.where((x) => x.stage?.inProgress ?? true).length;
    final step = tabs.step;
    final info = stepInfo[step]!;

    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        titleSpacing: 20,
        title: const Text('STEP', style: TextStyle(fontSize: 18)),
        actions: [
          for (var n = 1; n <= 4; n++)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => tabs.selectStep(n),
                child: Tooltip(
                  message: 'STEP $n',
                  child: CircleAvatar(
                    radius: 13,
                    backgroundColor: step == n ? AppColors.black : AppColors.soft,
                    child: Text('$n', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: step == n ? AppColors.paper : AppColors.subtle)),
                  ),
                ),
              ),
            ),
          const SizedBox(width: 14),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('STEP $step', style: AppText.bodyBold.copyWith(fontSize: 11, color: AppColors.green)),
                Text(info.title, style: AppText.h1.copyWith(fontSize: 20)),
                Text(info.desc, style: AppText.small.copyWith(fontSize: 12)),
              ]),
            ),
            // 기관 계정: STEP 3·4 에 프로그램 글쓰기
            if (isInstitution && step >= 3)
              AppButton(
                label: '글쓰기',
                icon: Icons.edit_outlined,
                small: true,
                expand: false,
                onPressed: () => Navigator.pushNamed(context, Routes.programRegister),
              )
            // 청년 계정: STEP 4 오른쪽 위 '지원현황' → 취업 지원현황
            else if (!isInstitution && step == 4)
              _ApplyStatusButton(count: appliedCount),
          ]),
          const SizedBox(height: 14),
          ChipWrap(children: [
            for (final s in StepSort.values)
              SelectChip(label: s.label, selected: _sort == s, onTap: () => setState(() => _sort = s)),
          ]),
          const SizedBox(height: 14),
          switch (step) {
            1 => Step1Missions(sort: _sort),
            2 => Step2Connect(sort: _sort),
            3 => Step3Challenge(sort: _sort),
            _ => Step4Job(sort: _sort),
          },
        ],
      ),
    );
  }
}

class _ApplyStatusButton extends StatelessWidget {
  const _ApplyStatusButton({required this.count});

  /// 진행 중인 지원 수 (배지)
  final int count;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () => Navigator.pushNamed(context, Routes.applicationStatus),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.green,
        side: const BorderSide(color: AppColors.green),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        minimumSize: const Size(0, 34),
        textStyle: const TextStyle(fontFamily: 'Pretendard', fontSize: 12.5, fontWeight: FontWeight.w700),
      ),
      icon: const Icon(Icons.assignment_turned_in_outlined, size: 16),
      label: Text(count > 0 ? '지원현황 $count' : '지원현황'),
    );
  }
}
