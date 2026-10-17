// 메인(홈)
// STEP 1 미션, STEP 2 승인된 팀 활동,
// STEP 3·4 지원한 공고를 홈에서 모아 표시합니다.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/mock_data.dart';
import '../../models/models.dart';
import '../../router/main_tabs.dart';
import '../../router/routes.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final user = state.user;
    final unread = state.unreadCount;

    final displayName = state.isInstitution
        ? user.name
        : '${user.name.length > 1 ? user.name.substring(1) : user.name}님';

    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        titleSpacing: 20,
        title: Row(
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: AppColors.green,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(
                Icons.directions_walk,
                size: 15,
                color: AppColors.paper,
              ),
            ),
            const SizedBox(width: 6),
            const Text('한걸음'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: '알림 $unread건',
            onPressed: () {
              Navigator.pushNamed(context, Routes.notifications);
            },
            icon: Badge(
              isLabelVisible: unread > 0,
              smallSize: 7,
              backgroundColor: AppColors.red,
              child: const Icon(Icons.notifications_none),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () {
                    Navigator.pushNamed(
                      context,
                      state.isInstitution
                          ? Routes.profile
                          : Routes.recordList,
                    );
                  },
                  child: Row(
                    children: [
                      Avatar(
                        name: user.name,
                        size: 34,
                        color: AppColors.dim,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          displayName,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.h2.copyWith(fontSize: 16),
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right,
                        size: 18,
                        color: AppColors.subtle,
                      ),
                    ],
                  ),
                ),
              ),
              if (!state.isInstitution) ...[
                const SizedBox(width: 12),
                AppButton(
                  label: '기록하기',
                  small: true,
                  expand: false,
                  variant: ButtonVariant.outline,
                  onPressed: () => AppNav.toRecordWrite(context),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          if (state.isInstitution)
            const _InstitutionHome()
          else
            const _YouthHome(),
        ],
      ),
    );
  }
}

/// 홈 표시용 데이터입니다.
/// 전역 모델이나 원본 Mission을 변경하지 않습니다.
class _HomeActivity {
  const _HomeActivity({
    required this.step,
    required this.title,
    required this.detail,
    required this.statusLabel,
    this.done = false,
  });

  final int step;
  final String title;
  final String detail;
  final String statusLabel;
  final bool done;
}

class _YouthHome extends StatelessWidget {
  const _YouthHome();

  List<_HomeActivity> _collectActivities(AppState state) {
    final activities = <_HomeActivity>[];

    // STEP 1: 시작했거나 완료한 미션.
    for (final mission in state.missions) {
      if (mission.status == MissionStatus.todo) continue;

      final done = mission.status == MissionStatus.done;
      final due = mission.due;

      activities.add(
        _HomeActivity(
          step: 1,
          title: mission.title,
          detail: [
            '${mission.minutes}분',
            mission.category,
            if (due != null) '~${due.month}/${due.day}',
          ].join(' · '),
          statusLabel: done ? '완료' : '진행 중',
          done: done,
        ),
      );
    }

    // STEP 2: 승인된 팀 신청만 활동으로 표시.
    // 대기·거절은 실제 참여가 아니므로 포함하지 않습니다.
    for (final post in mockTeamPosts) {
      final application = state.applicationFor(post.id);

      if (application == null ||
          application.status != ApplicationStatus.accepted) {
        continue;
      }

      activities.add(
        _HomeActivity(
          step: 2,
          title: post.title,
          detail: [
            post.category,
            '${post.weeks}주',
            '주 ${post.perWeek}회',
            post.mode,
          ].join(' · '),
          statusLabel: '참여 승인',
        ),
      );
    }

    // STEP 3·4: 지원 여부가 기록된 공고.
    // 스크랩만 한 항목은 포함하지 않습니다.
    final appliedIds = state.scraps
        .where((scrap) => scrap.applied)
        .map((scrap) => scrap.opportunityId)
        .toSet();

    for (final opportunity in mockOpportunities) {
      if (!appliedIds.contains(opportunity.id)) continue;

      if (opportunity.step != 3 && opportunity.step != 4) {
        continue;
      }

      activities.add(
        _HomeActivity(
          step: opportunity.step,
          title: opportunity.title,
          detail: [
            opportunity.org,
            if (opportunity.region.isNotEmpty) opportunity.region,
          ].join(' · '),
          statusLabel: '지원 완료',
        ),
      );
    }

    return activities;
  }

 
  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final currentStep = state.user.currentStep;
    final info = stepInfo[currentStep];

    final activities = _collectActivities(state);

    final currentActivities = activities
        .where((activity) => activity.step == currentStep)
        .toList();

    final otherActivities = activities
        .where((activity) => activity.step != currentStep)
        .toList()
      ..sort((a, b) => a.step.compareTo(b.step));

    final doneCount =
        currentActivities.where((activity) => activity.done).length;

    final otherCount =
        otherActivities.where((activity) => !activity.done).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          color: AppColors.soft,
          onTap: () {
            context.read<MainTabs>().go(
                  MainTab.step,
                  step: currentStep,
                );
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('지금 나의 단계', style: AppText.caption),
              Text(
                'STEP $currentStep · ${info?.title ?? ''}',
                style: AppText.h2.copyWith(fontSize: 17),
              ),
              if (info != null)
                Text(
                  info.desc,
                  style: AppText.small.copyWith(fontSize: 12),
                ),
              const SizedBox(height: 10),

              // STEP 1만 실제 완료 상태가 존재합니다.
              // STEP 2~4는 완료 여부를 임의로 만들지 않습니다.
              Text(
                currentStep == 1
                    ? '활동 $doneCount/${currentActivities.length} 완료'
                    : '활동 ${currentActivities.length}개',
                style: AppText.bodyBold.copyWith(
                  fontSize: 13,
                  color: AppColors.ink,
                ),
              ),

              if (currentStep == 1) ...[
                const SizedBox(height: 10),
                ProgressLine(
                  value: doneCount,
                  total: currentActivities.isEmpty
                      ? 1
                      : currentActivities.length,
                ),
              ],
            ],
          ),
        ),

        // 별도 '진행 중인 미션' 제목 없이 바로 표시.
        const SizedBox(height: 8),
        _ActivityList(
          activities: currentActivities,
          emptyMessage: '현재 STEP에 표시할 활동이 없어요.',
        ),

        // 활동 수정 버튼은 잠시 숨깁니다.
        /*
        AppButton(
          label: '활동 수정',
          icon: Icons.edit_outlined,
          variant: ButtonVariant.ghost,
          onPressed: () {
            Navigator.pushNamed(context, Routes.missionEdit);
          },
        ),
        */

        const SizedBox(height: 24),
        Row(
          children: [
            Text(
              '그 외 진행 중 $otherCount',
              style: AppText.bodyBold,
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Divider(color: AppColors.line),
            ),
          ],
        ),
        const SizedBox(height: 12),

        _ActivityList(
          activities: otherActivities,
          showStep: true,
          emptyMessage: '다른 STEP에 표시할 활동이 없어요.',
        ),

        
      ],
    );
  }
}

class _ActivityList extends StatelessWidget {
  const _ActivityList({
    required this.activities,
    required this.emptyMessage,
    this.showStep = false,
  });

  final List<_HomeActivity> activities;
  final String emptyMessage;
  final bool showStep;

  @override
  Widget build(BuildContext context) {
    if (activities.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Text(emptyMessage, style: AppText.small),
      );
    }

    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 4,
      ),
      child: Column(
        children: [
          for (var index = 0; index < activities.length; index++) ...[
            if (index > 0) const Divider(),
            _ActivityRow(
              activity: activities[index],
              showStep: showStep,
            ),
          ],
        ],
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({
    required this.activity,
    required this.showStep,
  });

  final _HomeActivity activity;
  final bool showStep;

  @override
  Widget build(BuildContext context) {
    final detail = [
      if (showStep) 'STEP ${activity.step}',
      if (activity.detail.isNotEmpty) activity.detail,
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Icon(
            activity.done
                ? Icons.check_circle_outline
                : Icons.radio_button_unchecked,
            size: 20,
            color: activity.done ? AppColors.dim : AppColors.green,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity.title,
                  style: AppText.body.copyWith(
                    fontSize: 13.5,
                    color: activity.done
                        ? AppColors.subtle
                        : AppColors.ink,
                  ),
                ),
                if (detail.isNotEmpty)
                  Text(detail, style: AppText.caption),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TagBadge(
            activity.statusLabel,
            tone: activity.done ? BadgeTone.gray : BadgeTone.green,
          ),
        ],
      ),
    );
  }
}

class _InstitutionHome extends StatelessWidget {
  const _InstitutionHome();

  @override
  Widget build(BuildContext context) {
    final programs = context.watch<AppState>().programs;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('활동기관', style: AppText.caption),
              const SizedBox(height: 4),
              Text(
                '등록한 프로그램 ${programs.length}개',
                style: AppText.h2.copyWith(fontSize: 17),
              ),
              const SizedBox(height: 10),
              AppButton(
                label: '프로그램 등록',
                icon: Icons.add,
                small: true,
                expand: false,
                onPressed: () {
                  Navigator.pushNamed(
                    context,
                    Routes.programRegister,
                  );
                },
              ),
            ],
          ),
        ),
        for (final program in programs)
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TagBadge(
                  'STEP ${program.step} · ${kindLabel[program.kind]}',
                  tone: BadgeTone.gray,
                ),
                const SizedBox(height: 6),
                Text(program.title, style: AppText.bodyBold),
                Text(
                  [
                    if (program.region.isNotEmpty) program.region,
                    '마감 ${program.deadline}',
                  ].join(' · '),
                  style: AppText.caption,
                ),
              ],
            ),
          ),
        const TodoBox('기관 홈: 신청자 수, 검수 상태 등 정해지면 추가'),
      ],
    );
  }
}
