// 메인(홈) — 구조 3안: 부족한 것만 추천
// 나의 역량(접이식, 준비도·5개 항목은 AI 판단) / 튜토리얼 박스 / 나의 활동(STEP 낮은 순) / AI 추천 활동 순서로 표시합니다.
// 활동: STEP 1 미션, STEP 2 승인된 팀 활동, STEP 3·4 지원했거나 '활동에 추가'한 공고를 모아 보여줍니다.
// 활동을 완료(체크)하면 "활동을 기록할까요?" 를 묻고, 예를 누르면 제목에 활동 이름이 들어간 기록 쓰기로 갑니다.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/mock_data.dart';
import '../../models/models.dart';
import '../../router/routes.dart';
import '../record/record_write_screen.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../services/readiness_service.dart';
import '../../widgets/home/readiness_card.dart';
import '../../widgets/home/recommended_section.dart';
import '../../widgets/home/tutorial_box.dart';

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
    final readiness = state.readiness;
    // 재료(진단 답·성적·기록·팀)가 바뀌었으면 AI 에게 다시 판단을 맡깁니다. (같으면 아무것도 안 함)
    // 추천 활동도 같은 방식 (준비도 판단이 끝난 뒤에 고릅니다)
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await state.refreshReadiness();
      await state.refreshRecommendations();
    });

    // 완료된 활동은 홈 목록에서 숨기고, 진행 중인 활동만 STEP 순으로 표시합니다.
    final ongoing = activities.where((activity) => !activity.done).toList()
      ..sort(_compareByStep);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 나의 역량: 처음엔 준비도만 보이고, 눌러야 5개 항목이 펼쳐집니다.
        // 준비도·항목·지금 채우면 좋은 것은 AI 판단 (키가 없으면 규칙 계산). 기준은 진단 답에서 읽습니다.
        _SectionHeader(
          title: '나의 역량',
          trailing: InkWell(
            onTap: () => Navigator.pushNamed(context, Routes.diagnosisEdit),
            child: TagBadge('${readiness.target.label} 기준', tone: BadgeTone.gray),
          ),
        ),
        const SizedBox(height: 10),
        _AbilityCard(data: _buildAbilityData(state, readiness)),

        // 튜토리얼(학점·어학·첫 기록·진단) · 단계 올리기 · 직무 정하기 — 해당할 때만 보입니다.
        const SizedBox(height: 12),
        const TutorialBox(),
        const StageUpCard(),
        const DirectionCard(),

        // 나의 활동: 기존 활동 행(설명 · STEP 칩 · 상태)을 그대로 사용합니다.
        const SizedBox(height: 12),
        _SectionHeader(title: '나의 활동', count: ongoing.length),
        const SizedBox(height: 10),
        _ActivityList(
          activities: ongoing,
          showStep: true,
          emptyMessage: '아직 시작한 활동이 없어요. 아래 추천 활동을 추가해 보세요.',
        ),

        // AI 추천 활동: 옆으로 밀어 보고, 버튼으로 활동에 추가합니다.
        const SizedBox(height: 24),
        _SectionHeader(
          title: 'AI 추천 활동',
          // 키 없이 실행하거나 AI 가 실패하면 규칙 추천이라고 알려 줍니다.
          trailing: state.recommendationsLoading
              ? Text('AI가 고르는 중…', style: AppText.caption)
              : (state.recommendationsFromAi ? null : const TagBadge('AI 아님 · 기본 추천', tone: BadgeTone.gray)),
        ),
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

  /// 완료 체크 → "활동을 기록할까요?" → 예: 활동 이름이 제목에 들어간 기록 쓰기로 이동
  /// (완료 취소일 때는 묻지 않아요)
  Future<void> _toggleDone(BuildContext context) async {
    final wasDone = activity.done;
    activity.onToggleDone();
    if (wasDone) return;

    // 완료하면 이 줄은 홈 목록에서 사라지므로, 이동은 화면(Navigator)으로 합니다.
    final navigator = Navigator.of(context);
    final write = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.paper,
        surfaceTintColor: AppColors.paper,
        title: Text('활동 완료!', style: AppText.title),
        content: Text(
          "'${activity.title}' 활동을 끝냈어요.\n활동을 기록하시겠습니까?",
          style: AppText.body.copyWith(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('나중에', style: TextStyle(color: AppColors.subtle)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('예', style: TextStyle(color: AppColors.green)),
          ),
        ],
      ),
    );
    if (write != true) return;
    navigator.pushNamed(
      Routes.recordWrite,
      arguments: RecordWriteArgs(
        missionId: activity.step == 1 ? activity.id : null,
        title: activity.title,
        step: activity.step,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          // 완료 / 완료 취소 버튼
          IconButton(
            tooltip: activity.done ? '완료 취소' : '활동 완료',
            onPressed: () => _toggleDone(context),
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
    required this.status,
    this.target,
  });

  final String label;
  final double? value;
  final double max;
  final double? target;

  /// 충족 · 일부 · 부족 (AI 판단)
  final AreaStatus status;

  bool get hasTarget => target != null;
  bool get achieved => status == AreaStatus.met;

  double get progress =>
      value == null ? 0.0 : (value! / max).clamp(0.0, 1.0).toDouble();

  double? get targetProgress =>
      target == null ? null : (target! / max).clamp(0.0, 1.0).toDouble();
}

class _AbilityData {
  const _AbilityData({
    required this.readiness,
    required this.abilities,
    required this.result,
    required this.loading,
  });

  /// 종합 취업 준비도(0~100).
  final int readiness;
  final List<_Ability> abilities;
  final ReadinessResult result;
  final bool loading;
}

/// 준비도 판단 결과로 역량 칸을 만듭니다.
/// 성적·어학은 실제 값(학점 / 4.5, 토익 환산 / 990), 나머지는 점수 / 100 에 충족선(80)을 목표로 표시합니다.
_AbilityData _buildAbilityData(AppState state, ReadinessResult r) {
  final abilities = [
    for (final a in r.shownAreas)
      a.max != null
          ? _Ability(
              label: a.label,
              value: a.value,
              max: a.max!,
              target: a.target,
              status: a.status,
            )
          : _Ability(
              label: a.label,
              value: a.score.toDouble(),
              max: 100,
              target: 80,
              status: a.status,
            ),
  ];

  return _AbilityData(
    readiness: r.score,
    abilities: abilities,
    result: r,
    loading: state.readinessLoading,
  );
}

String _fmt(double n) =>
    n == n.roundToDouble() ? n.toInt().toString() : n.toStringAsFixed(1);

/// 접힌 상태의 한 줄 요약. 예: "지금 채우면 좋은 것 · 어학: 토익스피킹 일정 확인"
String _fillSummary(ReadinessResult r) => '지금 채우면 좋은 것 · ${nowAction(r).title}';

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
    final allAchieved = data.abilities.every((ability) => ability.achieved);
    final summary = data.loading
        ? 'AI가 준비도를 판단하는 중이에요…'
        : (allAchieved ? '모든 항목을 채웠어요' : _fillSummary(data.result));

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
          const SizedBox(height: 16),
          _FillBox(result: data.result),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  data.result.source == ReadinessSource.ai ? 'AI 판단' : 'AI 아님 · 기본 계산 (AI 키 없이 실행했거나 AI 오류)',
                  style: AppText.caption.copyWith(fontSize: 11),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pushNamed(context, Routes.readinessDetail),
                child: Text(
                  '자세히 보기 ›',
                  style: AppText.caption.copyWith(fontWeight: FontWeight.w700, color: AppColors.greenDark),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 펼친 카드 아래: 지금 채우면 좋은 것 (AI 가 고른 항목과 할 일)
class _FillBox extends StatelessWidget {
  const _FillBox({required this.result});

  final ReadinessResult result;

  @override
  Widget build(BuildContext context) {
    final action = nowAction(result);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.soft,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('지금 채우면 좋은 것', style: AppText.caption),
          const SizedBox(height: 3),
          Text(action.title, style: AppText.bodyBold.copyWith(fontSize: 13.5)),
          if (action.note.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(action.note, style: AppText.caption.copyWith(fontSize: 11.5)),
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
    final hint = ability.achieved
        ? '충족'
        : '${areaStatusLabel[ability.status]} · 목표 ${_fmt(ability.target ?? ability.max)}';

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
        // 칸마다 줄 높이를 맞추기 위해 같은 높이를 둡니다.
        SizedBox(
          height: 16,
          child: Text(
            hint,
            style: AppText.caption.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: switch (ability.status) {
                AreaStatus.met => AppColors.greenDark,
                AreaStatus.partial => AppColors.amber,
                AreaStatus.lacking => AppColors.red,
              },
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