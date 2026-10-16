// STEP 1 · 작은 성취 — 미션 목록, (+) 로 시작
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import 'step_sort.dart';

class Step1Missions extends StatelessWidget {
  const Step1Missions({super.key, required this.sort});
  final StepSort sort;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final list = [...state.missions];
    if (sort == StepSort.name) list.sort((a, b) => a.title.compareTo(b.title));
    if (sort == StepSort.deadline) list.sort((a, b) => a.minutes.compareTo(b.minutes)); // 미션은 마감 대신 소요 시간순

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('미션 ${list.length}개', style: AppText.bodyBold.copyWith(fontSize: 12.5)),
      const SizedBox(height: 8),
      AppCard(
        padding: const EdgeInsets.fromLTRB(16, 2, 4, 2),
        child: Column(children: [
          for (var i = 0; i < list.length; i++) ...[
            if (i > 0) const Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(list[i].title,
                        style: AppText.body.copyWith(fontSize: 13.5, color: list[i].status == MissionStatus.done ? AppColors.subtle : AppColors.ink)),
                    Text('${list[i].minutes}분 · ${list[i].category}', style: AppText.caption),
                  ]),
                ),
                if (list[i].status == MissionStatus.todo)
                  IconButton(
                    tooltip: '${list[i].title} 시작',
                    onPressed: () {
                      state.startMission(list[i].id);
                      showToast(context, '미션을 시작했어요');
                    },
                    icon: const Icon(Icons.add_circle_outline, color: AppColors.green),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    child: TagBadge(list[i].status == MissionStatus.done ? '완료' : '진행 중',
                        tone: list[i].status == MissionStatus.done ? BadgeTone.gray : BadgeTone.green),
                  ),
              ]),
            ),
          ],
        ]),
      ),
    ]);
  }
}
