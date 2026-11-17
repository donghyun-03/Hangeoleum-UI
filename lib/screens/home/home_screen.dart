// 메인(홈)
// 나의 역량(접이식) / 나의 활동(STEP 낮은 순) / AI 추천 활동 순서로 표시합니다.
// 활동: STEP 1 미션, STEP 2 승인된 팀 활동, STEP 3·4 지원한 공고를 모아 보여줍니다.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/mock_data.dart';
import '../../data/home_mock_data.dart';
import '../../models/models.dart';
import '../../router/routes.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/home/recommended_section.dart';

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
    // 지원한 공고(appliedScraps) 또는 홈 추천에서 "활동에 추가"한 공고를 표시합니다.
    // 지원한 공고는 스크랩을 지웠어도 지원현황에 남으므로 appliedScraps 로 읽습니다.
    final appliedIds = state.appliedScraps
        .map((scrap) => scrap.opportunityId)
        .toSet();

    for (final opportunity in mockOpportunities) {
      final isApplied = appliedIds.contains(opportunity.id);
      final isAdded = state.isHomeOpportunityAdded(opportunity.id);

      if (!isApplied && !isAdded) continue;

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
    final activities = _collectActivities(state);

    // 완료된 활동은 홈 목록에서 숨기고, 진행 중인 활동만 STEP 순으로 표시합니다.
    final ongoing = activities.where((activity) => !activity.done).toList()
      ..sort(_compareByStep);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 나의 역량: 처음엔 준비도만 보이고, 눌러야 네 가지 역량이 펼쳐집니다.
        // TODO: 목표 기업 기준(목표 점수)은 니즈 진단 결과에서 읽도록 교체합니다.
        _SectionHeader(
          title: '나의 역량',
          trailing: TagBadge(homeTargetCompanyLabel, tone: BadgeTone.gray),
        ),
        const SizedBox(height: 10),
        _AbilityCard(data: _buildAbilityData(state)),

        // 나의 활동: 기존 활동 행(설명 · STEP 칩 · 상태)을 그대로 사용합니다.
        const SizedBox(height: 24),
        _SectionHeader(title: '나의 활동', count: ongoing.length),
        const SizedBox(height: 10),
        _ActivityList(
          activities: ongoing,
          showStep: true,
          emptyMessage: '아직 시작한 활동이 없어요. 아래 추천 활동을 추가해 보세요.',
        ),

        // AI 추천 활동: 옆으로 밀어 보고, 버튼으로 활동에 추가합니다.
        const SizedBox(height: 24),
        const _SectionHeader(title: 'AI 추천 활동'),
        const SizedBox(height: 10),
        const RecommendedSection(),
      ],
    );
  }
}

/// STEP이 낮은 순, 같은 STEP이면 제목순으로 정렬합니다.
int _compareByStep(_HomeActivity a, _HomeActivity b) {
  final stepOrder = a.step.compareTo(b.step);
  return stepOrder != 0 ? stepOrder : a.title.compareTo(b.title);
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



/// 섹션 제목 줄: 제목 + (진행 중 개수) + 오른쪽 위젯.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    this.count,
    this.trailing,
  });

  final String title;
  final int? count;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(title, style: AppText.bodyBold),
        if (count != null) ...[
          const SizedBox(width: 6),
          Text(
            '$count',
            style: AppText.bodyBold.copyWith(color: AppColors.greenDark),
          ),
        ],
        const Spacer(),
        ?trailing,
      ],
    );
  }
}

// ───────────────────────── 나의 역량 ─────────────────────────

/// 역량 하나. value 가 null 이면 아직 입력하지 않은 값입니다.
/// target 이 있으면 목표 점수를 함께 표시합니다.
class _Ability {
  const _Ability({
    required this.label,
    required this.value,
    required this.max,
    this.target,
  });

  final String label;
  final double? value;
  final double max;
  final double? target;

  bool get hasTarget => target != null;
  bool get achieved =>
      value != null && target != null && value! >= target!;

  double get progress =>
      value == null ? 0.0 : (value! / max).clamp(0.0, 1.0).toDouble();

  double? get targetProgress =>
      target == null ? null : (target! / max).clamp(0.0, 1.0).toDouble();

  /// 준비도 계산용 비율. 목표가 있으면 목표 대비, 없으면 만점 대비입니다.
  double get ratio {
    final v = value;
    if (v == null) return 0.0;
    return (v / (target ?? max)).clamp(0.0, 1.0).toDouble();
  }
}

class _AbilityData {
  const _AbilityData({required this.readiness, required this.abilities});

  /// 종합 취업 준비도(0~100).
  final int readiness;
  final List<_Ability> abilities;
}

/// 사용자 정보(학점·어학)와 임시 AI 점수로 역량 데이터를 만듭니다.
_AbilityData _buildAbilityData(AppState state) {
  final user = state.user;

  // 어학: 등록한 어학 점수 중 TOEIC 점수를 사용합니다.
  double? toeic;
  for (final language in user.languages) {
    final exam = language.exam.toUpperCase();
    if (exam.contains('TOEIC') || language.exam.contains('토익')) {
      toeic = double.tryParse(language.score);
      if (toeic != null) break;
    }
  }

  final abilities = <_Ability>[
    const _Ability(label: '포트폴리오', value: homeMockPortfolioScore, max: 100),
    _Ability(
      label: '성적',
      value: user.gpa,
      max: user.gpaScale,
      target: homeTargetGpa * user.gpaScale / 4.5,
    ),
    _Ability(
      label: '어학',
      value: toeic,
      max: homeToeicMax,
      target: homeTargetToeic,
    ),
    const _Ability(label: '직무 연관성', value: homeMockJobFitScore, max: 100),
  ];

  // 임시 계산식: 각 역량 달성 비율의 평균입니다. AI 종합 평가가 생기면 교체합니다.
  final average = abilities.fold<double>(0, (sum, a) => sum + a.ratio) /
      abilities.length;

  return _AbilityData(
    readiness: (average * 100).round(),
    abilities: abilities,
  );
}

String _fmt(double n) =>
    n == n.roundToDouble() ? n.toInt().toString() : n.toStringAsFixed(1);

/// 접힌 상태의 한 줄 요약. 예: "어학 40점 · 성적 0.4점 남음"
String _remainingSummary(List<_Ability> abilities) {
  final gaps = <String>[];
  final missing = <String>[];

  for (final ability in abilities) {
    if (!ability.hasTarget || ability.achieved) continue;

    final value = ability.value;
    if (value == null) {
      missing.add(ability.label);
    } else {
      gaps.add('${ability.label} ${_fmt(ability.target! - value)}점');
    }
  }

  return [
    if (gaps.isNotEmpty) '${gaps.join(' · ')} 남음',
    if (missing.isNotEmpty) '${missing.join(', ')} 미입력',
  ].join(' · ');
}

/// 준비도 한 줄 + 눌러서 펼치는 2x2 세부 역량.
class _AbilityCard extends StatefulWidget {
  const _AbilityCard({required this.data});

  final _AbilityData data;

  @override
  State<_AbilityCard> createState() => _AbilityCardState();
}

class _AbilityCardState extends State<_AbilityCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final targeted =
        data.abilities.where((ability) => ability.hasTarget).toList();
    final allAchieved =
        targeted.isNotEmpty && targeted.every((ability) => ability.achieved);
    final summary = allAchieved
        ? '모든 목표를 달성했어요'
        : _remainingSummary(data.abilities);

    return Semantics(
      button: true,
      label: _expanded ? '세부 역량 접기' : '세부 역량 펼치기',
      child: AppCard(
        // AppCard 기본 아래 여백(10)을 없애고, 간격은 SizedBox로 맞춥니다.
        margin: EdgeInsets.zero,
        onTap: () => setState(() => _expanded = !_expanded),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '준비도',
                  style: AppText.bodyBold.copyWith(fontSize: 14),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _GaugeBar(
                    progress:
                        (data.readiness / 100).clamp(0.0, 1.0).toDouble(),
                    height: 12,
                  ),
                ),
                const SizedBox(width: 10),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '${data.readiness}',
                        style: AppText.h2.copyWith(
                          fontSize: 27,
                          fontWeight: FontWeight.w800,
                          color: AppColors.greenDark,
                          height: 1.1,
                        ),
                      ),
                      TextSpan(
                        text: '점',
                        style: AppText.bodyBold.copyWith(
                          fontSize: 12,
                          color: AppColors.greenDark,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                AnimatedRotation(
                  turns: _expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(
                    Icons.keyboard_arrow_down,
                    size: 20,
                    color: AppColors.subtle,
                  ),
                ),
              ],
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              alignment: Alignment.topCenter,
              child: _expanded
                  ? _buildDetail(data)
                  : (summary.isEmpty
                      ? const SizedBox(width: double.infinity)
                      : Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(summary, style: AppText.caption),
                        )),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetail(_AbilityData data) {
    final items = data.abilities;

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Divider(height: 1, thickness: 1, color: AppColors.line),
          const SizedBox(height: 14),
          for (var i = 0; i < items.length; i += 2) ...[
            if (i > 0) const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _AbilityCell(ability: items[i])),
                const SizedBox(width: 16),
                Expanded(
                  child: i + 1 < items.length
                      ? _AbilityCell(ability: items[i + 1])
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// 2x2 칸 하나: 이름, 현재 / 만점, 게이지, 목표 문구.
class _AbilityCell extends StatelessWidget {
  const _AbilityCell({required this.ability});

  final _Ability ability;

  @override
  Widget build(BuildContext context) {
    final value = ability.value;
    final hint = !ability.hasTarget
        ? null
        : ability.achieved
            ? '목표 달성'
            : '목표 ${_fmt(ability.target!)}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          ability.label,
          style: AppText.bodyBold.copyWith(fontSize: 12),
        ),
        const SizedBox(height: 4),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: value == null ? '-' : _fmt(value),
                style: AppText.h2.copyWith(fontSize: 20),
              ),
              TextSpan(
                text: ' / ${_fmt(ability.max)}',
                style: AppText.caption,
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        _GaugeBar(
          progress: ability.progress,
          targetProgress: ability.targetProgress,
          achieved: ability.achieved,
          keepEndSpace: true,
        ),
        const SizedBox(height: 5),
        // 목표가 없는 역량도 줄 높이를 맞추기 위해 같은 높이를 비워 둡니다.
        SizedBox(
          height: 16,
          child: hint == null
              ? null
              : Text(
                  hint,
                  style: AppText.caption.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.greenDark,
                  ),
                ),
        ),
      ],
    );
  }
}

/// 게이지: 현재 값(진한 초록) → 목표까지 남은 구간(연한 초록) → 만점(회색).
/// 목표 위치에는 동그란 마커를 표시하고, 달성하면 체크가 들어갑니다.
class _GaugeBar extends StatelessWidget {
  const _GaugeBar({
    required this.progress,
    this.targetProgress,
    this.achieved = false,
    this.height = 8,
    this.keepEndSpace = false,
  });

  final double progress;
  final double? targetProgress;
  final bool achieved;
  final double height;
  final bool keepEndSpace;

  static const double _markerSize = 18;

  @override
  Widget build(BuildContext context) {
    final target = targetProgress;
    final boxHeight = target == null ? height : _markerSize;
    final barTop = (boxHeight - height) / 2;
    final radius = BorderRadius.circular(height / 2);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        // 목표 마커가 오른쪽 끝에 붙지 않도록 목표형 게이지는 10% 여백을 둡니다.
        final usableWidth = width * (keepEndSpace ? 0.90 : 1.0);
        final fillWidth = usableWidth * progress;
        final gapWidth = target == null
            ? 0.0
            : (usableWidth * (target - progress)).clamp(0.0, usableWidth).toDouble();

        return SizedBox(
          height: boxHeight,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: 0,
                right: 0,
                top: barTop,
                height: height,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.line,
                    borderRadius: radius,
                  ),
                ),
              ),
              if (gapWidth > 0)
                Positioned(
                  left: fillWidth,
                  top: barTop,
                  width: gapWidth,
                  height: height,
                  child: const DecoratedBox(
                    decoration: BoxDecoration(color: AppColors.greenLine),
                  ),
                ),
              Positioned(
                left: 0,
                top: barTop,
                width: fillWidth,
                height: height,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.green,
                    borderRadius: radius,
                  ),
                ),
              ),
              if (target != null)
                Positioned(
                  left: (usableWidth * target - _markerSize / 2).clamp(0.0, width - _markerSize).toDouble(),
                  top: 0,
                  width: _markerSize,
                  height: _markerSize,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: achieved ? AppColors.green : AppColors.paper,
                      border: Border.all(color: AppColors.greenDark, width: 2.5),
                    ),
                    child: achieved
                        ? const Icon(
                            Icons.check,
                            size: 9,
                            color: AppColors.paper,
                          )
                        : null,
                  ),
                ),
            ],
          ),
        );
      },
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
            onTap: () => AppNav.toProgramDetail(context, program.id),
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