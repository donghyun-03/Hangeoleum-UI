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
              child: Image.asset('assets/images/logo.png', width: 80, height: 80, fit: BoxFit.contain, semanticLabel: '앱 로고',),
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
  child: Align(
    alignment: Alignment.centerLeft,
    child: InkWell(
      onTap: () {
        Navigator.pushNamed(context, Routes.profile);
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
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
),

              if (!state.isInstitution) ...[
                const SizedBox(width: 12),
                AppButton(
                  label: '활동 기록',
                  small: true,
                  expand: false,
                  variant: ButtonVariant.outline,
                  onPressed: () {
                    Navigator.pushNamed(context, Routes.recordList);
                  },
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
class _HomeActivity {
  const _HomeActivity({
    required this.id,
    required this.step,
    required this.title,
    required this.detail,
    required this.statusLabel,
    required this.onToggleDone,
    this.done = false,
  });

  final String id;
  final int step;
  final String title;
  final String detail;
  final String statusLabel;
  final bool done;
  final VoidCallback onToggleDone;
}



class _YouthHome extends StatelessWidget {
  const _YouthHome();

    List<_HomeActivity> _collectActivities(AppState state) {
    final activities = <_HomeActivity>[];

    // STEP 1: 기존 미션 상태로 완료 여부를 관리합니다.
    for (final mission in state.missions) {
      if (mission.status == MissionStatus.todo) continue;

      final done = mission.status == MissionStatus.done;
      final due = mission.due;

      activities.add(
        _HomeActivity(
          id: mission.id,
          step: 1,
          title: mission.title,
          detail: [
            '${mission.minutes}분',
            mission.category,
            if (due != null) '~${due.month}/${due.day}',
          ].join(' · '),
          statusLabel: done ? '완료' : '진행 중',
          done: done,
          onToggleDone: () {
            state.updateMission(
              mission.id,
              (currentMission) {
                if (currentMission.status == MissionStatus.todo) {
                  return currentMission;
                }

                return currentMission.copyWith(
                  status: currentMission.status == MissionStatus.done
                      ? MissionStatus.doing
                      : MissionStatus.done,
                );
              },
            );
          },
        ),
      );
    }

    // STEP 2: 신청한 프로젝트가 승인되면 홈에 표시합니다.
    // 승인 여부와 활동 완료 여부는 별도로 관리합니다.
    for (final post in mockTeamPosts) {
      final application = state.applicationFor(post.id);

      if (application == null ||
          application.status != ApplicationStatus.accepted) {
        continue;
      }

      final done = state.isHomeActivityDone(
        step: 2,
        activityId: post.id,
      );

      activities.add(
        _HomeActivity(
          id: post.id,
          step: 2,
          title: post.title,
          detail: [
            post.category,
            '${post.weeks}주',
            '주 ${post.perWeek}회',
            post.mode,
          ].join(' · '),
          statusLabel: done ? '완료' : '진행 중',
          done: done,
          onToggleDone: () {
            state.toggleHomeActivityDone(
              step: 2,
              activityId: post.id,
            );
          },
        ),
      );
    }

    // STEP 3·4 홈 추가 조건:
    // 지금은 기존의 "지원한 공고" 표시 방식을 유지합니다.
    // TODO: 상세 화면의 + 버튼 구현 시, 이 필터만
    // "홈에 추가한 프로그램 ID 목록"을 읽도록 변경합니다.
    // 아래의 완료 상태 조회/토글 로직은 그대로 사용할 수 있습니다.
    final appliedIds = state.scraps
        .where((scrap) => scrap.applied)
        .map((scrap) => scrap.opportunityId)
        .toSet();

    for (final opportunity in mockOpportunities) {
      if (!appliedIds.contains(opportunity.id)) continue;

      if (opportunity.step != 3 && opportunity.step != 4) {
        continue;
      }

      final done = state.isHomeActivityDone(
        step: opportunity.step,
        activityId: opportunity.id,
      );

      activities.add(
        _HomeActivity(
          id: opportunity.id,
          step: opportunity.step,
          title: opportunity.title,
          detail: [
            opportunity.org,
            if (opportunity.region.isNotEmpty) opportunity.region,
          ].join(' · '),
          statusLabel: done ? '완료' : '진행 중',
          done: done,
          onToggleDone: () {
            state.toggleHomeActivityDone(
              step: opportunity.step,
              activityId: opportunity.id,
            );
          },
        ),
      );
    }

    // STEP 1은 todo로 변경되어 위의 미션 수집 단계에서 제외됩니다.
    // STEP 2~4는 활동을 그만둔 경우 참여 활동 목록에서 제외합니다.
    return activities.where((activity) {
      return !state.isActivityStopped(
        step: activity.step,
        activityId: activity.id,
      );
    }).toList();

  }


  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final currentStep = state.user.currentStep;
    final info = stepInfo[currentStep];

    final activities = _collectActivities(state);

    // 현재 STEP: 진행 중 활동을 먼저, 완료 활동을 나중에 표시합니다.
    final currentActivities = [
      ...activities.where(
        (activity) => activity.step == currentStep && !activity.done,
      ),
      ...activities.where(
        (activity) => activity.step == currentStep && activity.done,
      ),
    ];

    // 현재 STEP이 아닌 활동 중 미완료 활동만 표시합니다.
    // STEP이 바뀌면 이전 단계의 미완료 활동이 여기에 포함됩니다.
    final otherActivities = activities
        .where(
          (activity) => activity.step != currentStep && !activity.done,
        )
        .toList()
      ..sort((a, b) {
        final stepOrder = a.step.compareTo(b.step);

        return stepOrder != 0
            ? stepOrder
            : a.title.compareTo(b.title);
      });

    final doneCount = currentActivities
        .where((activity) => activity.done)
        .length;

    // 기존 AppState.advanceHomeStep()과 동일한 최소 완료 기준입니다.
    final requiredCount = currentStep == 1 ? 3 : 1;

    // 최소 완료 개수를 충족하고 다음 STEP이 있을 때만 활성화합니다.
    final canGoNext = currentStep >= 1 &&
        currentStep < 4 &&
        doneCount >= requiredCount;

    final otherCount = otherActivities.length;

    final nextStepTooltip = currentStep >= 4
        ? '마지막 단계입니다'
        : canGoNext
            ? 'STEP ${currentStep + 1}로 이동'
            : '활동을 $requiredCount개 완료하면 이동할 수 있어요';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 요약과 현재 활동을 하나의 카드에 표시합니다.
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 상단: 지금 나의 단계와 완료 현황.
              Material(
                color: AppColors.soft,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(AppRadius.md),
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () {
                    context.read<MainTabs>().go(
                          MainTab.step,
                          step: currentStep,
                        );
                  },
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '지금 나의 단계',
                          style: AppText.caption,
                        ),
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
                        // 완료 문구와 선은 왼쪽에,
                        // 다음 버튼은 오른쪽에서 선의 중앙에 맞춰 표시합니다.
                        Stack(
                          children: [
                            Padding(
                              // 버튼 아래쪽이 영역 밖으로 벗어나지 않도록 공간을 확보합니다.
                              // 버튼 40 / 2 - 진행률 선 6 / 2 = 17
                              padding: const EdgeInsets.only(
                                right: 52, // 버튼 40 + 선과 버튼 사이 간격 12
                                bottom: 17,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '활동 $doneCount/$requiredCount 완료',
                                    style: AppText.bodyBold.copyWith(
                                      fontSize: 13,
                                      color: AppColors.ink,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  SizedBox(
                                    height: 6,
                                    child: ProgressLine(
                                      value: doneCount > requiredCount
                                          ? requiredCount
                                          : doneCount,
                                      total: requiredCount,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: _NextStepButton(
                                isActive: canGoNext,
                                size: 40,
                                tooltip: nextStepTooltip,
                                onTap: () {
                                  final advanced = context
                                      .read<AppState>()
                                      .advanceHomeStep(
                                        expectedStep: currentStep,
                                        completedCount: doneCount,
                                      );

                                  if (!advanced) return;

                                  context.read<MainTabs>().selectStep(
                                        currentStep + 1,
                                      );
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const Divider(
                height: 1,
                thickness: 1,
                color: AppColors.line,
              ),

              // 하단: 현재 활동 또는 활동 없음 안내.
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                child: currentActivities.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                          '현재 STEP에 표시할 활동이 없어요.',
                          style: AppText.small,
                        ),
                      )
                    : Column(
                        children: [
                          for (
                            var index = 0;
                            index < currentActivities.length;
                            index++
                          ) ...[
                            if (index > 0) const Divider(),
                            _ActivityRow(
                              activity: currentActivities[index],
                              showStep: false,
                            ),
                          ],
                        ],
                      ),
              ),
            ],
          ),
        ),

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

/// 홈 전용 다음 STEP 버튼.
/// 비활성 상태에서도 터치 효과는 표시하지만 단계 이동은 막습니다.
class _NextStepButton extends StatelessWidget {
  const _NextStepButton({
    required this.isActive,
    required this.onTap,
    required this.tooltip,
    this.size = 40,
  });

  final bool isActive;
  final VoidCallback onTap;
  final String tooltip;
  final double size;

  @override
  Widget build(BuildContext context) {
    final circleColor = isActive
        ? AppColors.green
        : AppColors.line;

    final arrowColor = isActive
        ? AppColors.paper
        : AppColors.subtle;

    final effectColor = isActive
        ? AppColors.paper
        : AppColors.subtle;

    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        enabled: isActive,
        label: tooltip,
        onTap: isActive ? onTap : null,
        child: ExcludeSemantics(
          child: SizedBox(
            width: size,
            height: size,
            child: Material(
              color: circleColor,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                customBorder: const CircleBorder(),
                splashColor: effectColor.withValues(alpha: 0.24),
                highlightColor: effectColor.withValues(alpha: 0.12),

                // null로 설정하지 않아 비활성 상태에도
                // 터치 효과를 보여주고 상위 카드의 탭을 막습니다.
                onTap: () {
                  if (!isActive) return;
                  onTap();
                },
                child: Center(
                  child: Icon(
                    Icons.keyboard_double_arrow_right,
                    color: arrowColor,
                    size: size * 0.55,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
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
        child: Text(
          emptyMessage,
          style: AppText.small,
        ),
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
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          // 완료 / 완료 취소 버튼
          IconButton(
            tooltip: activity.done ? '완료 취소' : '활동 완료',
            onPressed: activity.onToggleDone,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(
              width: 40,
              height: 40,
            ),
            style: IconButton.styleFrom(
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: const CircleBorder(),
            ),
            icon: Icon(
              activity.done
                  ? Icons.check_circle_outline
                  : Icons.radio_button_unchecked,
              size: 20,
              color: activity.done
                  ? AppColors.dim
                  : AppColors.green,
            ),
          ),
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
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (activity.detail.isNotEmpty)
                      Text(
                        activity.detail,
                        style: AppText.caption,
                      ),
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
                        'STEP ${activity.step}',
                        style: AppText.caption.copyWith(
                          fontSize: 10,
                          color: AppColors.muted,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TagBadge(
            activity.statusLabel,
            tone: activity.done
                ? BadgeTone.gray
                : BadgeTone.green,
          ),
        ],
      ),
    );

    // 완료한 활동은 스와이프 기능 없이 표시합니다.
    // 완료 취소 버튼은 계속 사용할 수 있습니다.
    if (activity.done) {
      return row;
    }

    // 미완료 활동만 스와이프하여 그만둘 수 있습니다.
    return _SwipeableHomeActivity(
      key: ValueKey('${activity.step}:${activity.id}'),
      onDelete: () {
        context.read<AppState>().stopActivity(
              step: activity.step,
              activityId: activity.id,
            );
      },
      child: row,
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
              Text(
                '활동기관',
                style: AppText.caption,
              ),
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
                Text(
                  program.title,
                  style: AppText.bodyBold,
                ),
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

/// 왼쪽으로 밀면 삭제 버튼을 표시하고,
/// 오른쪽으로 밀면 원래 위치로 돌아옵니다.
class _SwipeableHomeActivity extends StatefulWidget {
  const _SwipeableHomeActivity({
    super.key,
    required this.child,
    required this.onDelete,
  });

  final Widget child;
  final VoidCallback onDelete;

  @override
  State<_SwipeableHomeActivity> createState() =>
      _SwipeableHomeActivityState();
}

class _SwipeableHomeActivityState
    extends State<_SwipeableHomeActivity> {
  // 기존 80 → 56으로 줄여 덜 밀리도록 합니다.
  static const double _actionWidth = 56;
  static const double _buttonSize = 40;

  double _offset = 0;
  bool _dragging = false;

  void _handleDragUpdate(DragUpdateDetails details) {
    setState(() {
      _offset = (_offset + details.delta.dx)
          .clamp(-_actionWidth, 0.0)
          .toDouble();
    });
  }

  void _handleDragEnd(DragEndDetails details) {
    final velocity = details.velocity.pixelsPerSecond.dx;

    final bool shouldOpen;

    if (velocity < -250) {
      shouldOpen = true;
    } else if (velocity > 250) {
      shouldOpen = false;
    } else {
      shouldOpen = _offset <= -_actionWidth / 2;
    }

    _settle(shouldOpen);
  }

  void _handleDragCancel() {
    _settle(_offset <= -_actionWidth / 2);
  }

  void _settle(bool open) {
    setState(() {
      _dragging = false;
      _offset = open ? -_actionWidth : 0;
    });
  }

  
  @override
  Widget build(BuildContext context) {
    final reveal = (-_offset / _actionWidth)
        .clamp(0.0, 1.0)
        .toDouble();

    return ClipRect(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragStart: (_) {
          setState(() {
            _dragging = true;
          });
        },
        onHorizontalDragUpdate: _handleDragUpdate,
        onHorizontalDragEnd: _handleDragEnd,
        onHorizontalDragCancel: _handleDragCancel,
        child: Stack(
          alignment: Alignment.centerLeft,
          children: [
            // 활동만 왼쪽으로 이동합니다.
            AnimatedContainer(
              duration: _dragging
                  ? Duration.zero
                  : const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              transform: Matrix4.translationValues(
                _offset,
                0,
                0,
              ),
              child: widget.child,
            ),

            // 쓰레기통은 기존처럼 오른쪽 끝에 고정합니다.
            Positioned(
              top: 0,
              bottom: 0,
              right: 0,
              width: _buttonSize,
              child: IgnorePointer(
                ignoring: _dragging || reveal < 0.99,
                child: AnimatedOpacity(
                  opacity: reveal,
                  duration: _dragging
                      ? Duration.zero
                      : const Duration(milliseconds: 180),
                  child: Center(
                    child: Tooltip(
                      message: '활동 그만두기',
                      child: SizedBox(
                        width: _buttonSize,
                        height: _buttonSize,
                        child: Material(
                          color: AppColors.red,
                          shape: const CircleBorder(),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: widget.onDelete,
                            child: const Center(
                              child: Icon(
                                Icons.delete_outline,
                                color: AppColors.paper,
                                size: 23,
                                semanticLabel: '활동 그만두기',
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            
          ],
        ),
      ),
    );
  }
}
