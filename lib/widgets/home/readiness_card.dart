// 홈 준비도 도우미 (구조 3안: 부족한 것만 추천)
//   nowAction: 지금 채우면 좋은 것 한 줄 (AI 가 고른 값 우선)
//   StageUpCard: 단계 올리기 물어보기 / DirectionCard: 기업·직무 고민 중일 때 방향 찾기

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/readiness_service.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../common.dart';

BadgeTone toneOf(AreaStatus s) => switch (s) {
      AreaStatus.met => BadgeTone.green,
      AreaStatus.partial => BadgeTone.amber,
      AreaStatus.lacking => BadgeTone.red,
    };

/// "지금 채우면 좋은 것" 한 줄. 단계가 낮으면 큰 활동 대신 단계에 맞는 일을 먼저 보여 줍니다.
({String title, String note}) nowAction(ReadinessResult r) {
  // AI 가 판단했으면 AI 가 고른 할 일을 그대로 씁니다. (AI 에게 단계도 알려 줌)
  final aiTitle = r.fillTitle;
  if (aiTitle != null) return (title: aiTitle, note: r.fillReason ?? '');
  final weak = r.weakest;
  switch (r.stage) {
    case UserStage.rhythm:
      return (
        title: '생활 리듬: 매일 같은 시간에 일어나기',
        note: '지금은 ${josa(weak.label, '이', '가')} 가장 부족하지만, 리듬부터 되찾고 채워도 늦지 않아요.',
      );
    case UserStage.social:
      return (
        title: '사람 만나기: 동네 청년센터 모임 하나 찾아보기',
        note: '사람들과 연결되면 ${weak.label}도 같이 채워 가요.',
      );
    case UserStage.explore:
    case UserStage.ready:
      return (
        title: '${weak.label}: ${weak.nextAction}',
        note: '채우면 준비도 +${weak.gain}점 · ${weak.gaps.isEmpty ? '거의 다 채웠어요' : weak.gaps.first}',
      );
  }
}

/// "요즘 리듬이 돌아온 것 같아요" — 단계를 올려도 될 때만 보입니다. 사용자가 '네'를 눌러야 바뀝니다.
class StageUpCard extends StatelessWidget {
  const StageUpCard({super.key});

  static const _messages = {
    UserStage.social: '요즘 미션을 꾸준히 해냈어요! 생활 리듬이 돌아온 것 같은데, 이제 사람들과 만나는 활동도 추천해 드릴까요?',
    UserStage.explore: '사람들과 함께하는 경험이 생겼어요! 이제 교육·공모전처럼 경험을 쌓는 활동도 추천해 드릴까요?',
    UserStage.ready: '준비도가 60점을 넘었어요! 이제 부족한 항목을 바로 채우는 활동과 공고도 추천해 드릴까요?',
  };

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final next = state.suggestedNextStage;
    if (next == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        margin: EdgeInsets.zero,
        color: AppColors.greenLight,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(_messages[next]!, style: AppText.body.copyWith(fontSize: 13.5)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: '아직이요',
                    small: true,
                    variant: ButtonVariant.outline,
                    onPressed: state.snoozeStageAsk,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: AppButton(
                    label: '네, 바꿔 주세요',
                    small: true,
                    onPressed: () {
                      state.moveToStage(next);
                      showToast(context, '이제 "${userStageLabel[next]}" 단계에 맞춰 추천할게요.');
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 기업·직무·분야를 아직 모를 때 방향 찾기.
/// AI 판단이 있으면 AI 가 끌리는 것·전공·하루 상태를 보고 고른 분야·직무·기업 유형과 "한 달만 해 봐요" 문장을 보여 줍니다.
/// AI 가 없으면 규칙으로 고른 보기를 "AI 아님" 표시와 함께 보여 줍니다.
class DirectionCard extends StatelessWidget {
  const DirectionCard({super.key});

  static const _companyOptions = {'스타트업', '중소기업', '중견기업', '대기업', '공기업·공공기관'};

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    if (!state.needsDirection) return const SizedBox.shrink();
    final d = state.effectiveDiagnosis;
    final r = state.readiness;
    final ai = r.source == ReadinessSource.ai ? r.direction : null;
    final aiField = ai?.fields.isEmpty ?? true ? null : ai!.fields.first;

    final children = <Widget>[];
    if (ai != null && !ai.isEmpty) {
      children.addAll([
        Text(ai.message, style: AppText.small.copyWith(fontSize: 12.5)),
        if (d.targetJobName == null && ai.jobs.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text('해 볼 만한 직무', style: AppText.caption.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          for (final j in ai.jobs) _Pick(name: j.name, why: j.why, onTap: () => _pickJob(context, state, j.name, aiField)),
        ],
        if (d.companySize == null && d.companyType == null && ai.companyTypes.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text('시작하기 좋은 기업', style: AppText.caption.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          for (final c in ai.companyTypes)
            if (_companyOptions.contains(c.name))
              _Pick(name: c.name, why: c.why, onTap: () => _pickCompany(context, state, c.name)),
        ],
      ]);
    } else if (state.readinessLoading) {
      children.add(Text('AI가 나에게 맞는 방향을 찾는 중이에요…', style: AppText.small));
    } else {
      children.addAll(_ruleContent(context, state));
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        margin: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text('나에게 맞는 방향 찾기', style: AppText.bodyBold)),
                if (ai == null && !state.readinessLoading) const TagBadge('AI 아님', tone: BadgeTone.gray),
              ],
            ),
            const SizedBox(height: 6),
            ...children,
          ],
        ),
      ),
    );
  }

  void _pickJob(BuildContext context, AppState state, String job, String? field) {
    state.setTargetJob(job, field: field);
    showToast(context, '"$job" 기준으로 준비도를 볼게요. 한 달만 해 봐요!');
  }

  void _pickCompany(BuildContext context, AppState state, String type) {
    state.updateDiagnosisAnswer('company_preference', type);
    showToast(context, '$type 기준으로 준비도를 볼게요.');
  }

  /// AI 가 없을 때: 관심 분야가 있으면 대표 직무, 없으면 맛보기 활동 (규칙)
  List<Widget> _ruleContent(BuildContext context, AppState state) {
    final d = state.effectiveDiagnosis;
    final field = d.interests.isEmpty ? null : d.interests.first;
    final lowEnergy = state.stage == UserStage.rhythm || d.timeCommitment == '10분 정도';
    final majorField = fieldFromMajor(state.user.major);
    if (field != null) {
      final jobs = fieldJobs[field] ?? const [];
      return [
        Text(
          lowEnergy && majorField == field
              ? '${state.user.major} 전공을 살려서 ${jobs.first} 쪽은 어때요? 딱 한 달만 해 봐요.'
              : '$field에는 이런 직무가 있어요. 마음 가는 걸 하나 골라 한 달만 해 봐요.',
          style: AppText.small.copyWith(fontSize: 12.5),
        ),
        const SizedBox(height: 10),
        ChipWrap(children: [
          for (final j in jobs) SelectChip(label: j, selected: false, onTap: () => _pickJob(context, state, j, field)),
        ]),
      ];
    }
    return [
      Text('아직 좋아하는 걸 찾는 중이죠. 해 보고 싶은 걸 하나 골라 보세요. 아니면 바꾸면 돼요.',
          style: AppText.small.copyWith(fontSize: 12.5)),
      const SizedBox(height: 10),
      ChipWrap(children: [
        for (final e in fieldTasters.entries)
          SelectChip(
            label: '${e.key} · ${e.value}',
            selected: false,
            onTap: () => state.updateDiagnosisAnswer('interest', e.key),
          ),
      ]),
    ];
  }
}

class _Pick extends StatelessWidget {
  const _Pick({required this.name, required this.why, required this.onTap});
  final String name;
  final String why;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.add_circle_outline, size: 18, color: AppColors.green),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: AppText.bodyBold.copyWith(fontSize: 13)),
                  if (why.isNotEmpty) Text(why, style: AppText.caption.copyWith(fontSize: 11.5)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
