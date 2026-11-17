// 홈 화면의 AI 추천 활동 UI입니다.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/home_recommendation_data.dart';
import '../../models/models.dart';
import '../../router/main_tabs.dart';
import '../../router/routes.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../common.dart';

// ───────────────────────── AI 추천 활동 ─────────────────────────

void _announceAdded(
  BuildContext context,
  String title,
  VoidCallback onUndo,
) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text("'$title'을(를) 활동에 추가했어요"),
        action: SnackBarAction(label: '실행 취소', onPressed: onUndo),
      ),
    );
}

void _openRecommendation(
  BuildContext context,
  HomeRecommendation recommendation,
) {
  switch (recommendation.type) {
    case HomeRecommendationType.mission:
      context.read<MainTabs>().go(MainTab.step, step: 1);
      break;
    case HomeRecommendationType.team:
      context.read<MainTabs>().go(MainTab.step, step: 2);
      break;
    case HomeRecommendationType.opportunity:
      AppNav.toProgramDetail(context, recommendation.targetId);
      break;
  }
}

void _addRecommendation(
  BuildContext context,
  AppState state,
  HomeRecommendation recommendation,
) {
  switch (recommendation.type) {
    case HomeRecommendationType.mission:
      state.startMission(recommendation.targetId);
      _announceAdded(
        context,
        recommendation.title,
        () => state.stopActivity(
          step: 1,
          activityId: recommendation.targetId,
        ),
      );
      break;
    case HomeRecommendationType.team:
      AppNav.toTeamApply(context, recommendation.targetId);
      break;
    case HomeRecommendationType.opportunity:
      state.addHomeOpportunity(
        id: recommendation.targetId,
        step: recommendation.step,
      );
      _announceAdded(
        context,
        recommendation.title,
        () => state.removeHomeOpportunity(
          id: recommendation.targetId,
          step: recommendation.step,
        ),
      );
      break;
  }
}

/// 옆으로 밀어 보는 추천 카드 목록.
class RecommendedSection extends StatelessWidget {
  const RecommendedSection({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final items = buildHomeRecommendations(state);

    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Text('지금 추천할 활동이 없어요.', style: AppText.small),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // 다음 카드가 살짝 보이도록 카드 폭을 줄입니다.
        final cardWidth = constraints.maxWidth * 0.92;

        return SizedBox(
          height: 172,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final rec = items[index];

              return SizedBox(
                key: ValueKey(rec.id),
                width: cardWidth,
                child: _RecommendationCard(
                  rec: rec,
                  onDetail: () => _openRecommendation(context, rec),
                  onAdd: () => _addRecommendation(context, state, rec),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _RecommendationCard extends StatelessWidget {
  const _RecommendationCard({
    required this.rec,
    required this.onDetail,
    required this.onAdd,
  });

  final HomeRecommendation rec;
  final VoidCallback onDetail;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final isTeam = rec.type == HomeRecommendationType.team;

    return AppCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            rec.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.bodyBold.copyWith(fontSize: 13.5),
          ),
          const SizedBox(height: 5),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(rec.detail, style: AppText.caption),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 1,
                ),
                decoration: BoxDecoration(
                  color: AppColors.line,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'STEP ${rec.step}',
                  style: AppText.caption.copyWith(
                    fontSize: 10,
                    color: AppColors.muted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Text(
            rec.reason,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.small.copyWith(
              fontSize: 11.5,
              color: AppColors.muted,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: OutlinedButton(
                    onPressed: onDetail,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.ink,
                      side: const BorderSide(color: AppColors.dim),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      textStyle: const TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    child: const Text('자세히 보기'),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: FilledButton.icon(
                    onPressed: onAdd,
                    icon: Icon(
                      isTeam ? Icons.group_add_outlined : Icons.add,
                      size: 16,
                    ),
                    label: Text(
                      isTeam ? '팀 신청' : '활동에 추가',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.green,
                      foregroundColor: AppColors.paper,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      textStyle: const TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}