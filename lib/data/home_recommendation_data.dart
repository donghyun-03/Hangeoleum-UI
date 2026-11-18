// 홈 "AI 추천 활동" 후보 만들기 (구조 3안)
// - allHomeCandidates: AI 에게 넘기는 전체 후보 (AI 가 이 중에서 고름: services/recommend_ai.dart)
// - buildHomeRecommendations: AI 키가 없거나 AI 가 실패할 때 쓰는 규칙 추천 (아래 설명)
//
// 1) 하루 상태(진단 1번) → 지금 추천해도 되는 활동 크기
//      리듬: 생활 미션만 / 교류: 모임 미션·팀 / 탐색: 교육·공모전 / 취업 준비: 가장 부족한 항목을 채우는 활동
//    리듬이 무너진 사람에게는 포트폴리오가 좋아도 프로젝트·공모전을 추천하지 않습니다.
// 2) 하루 시간(진단 3번) → 10분이면 짧은 미션만, 30분이면 팀·교육까지, 1시간 이상이면 채용 공고까지
// 3) 먼저 도전하고 싶은 것(진단 2번) → 허용된 것 안에서 순서만 앞으로
// 4) 가장 부족한 항목(준비도) → 추천 이유 문장
//
// 실제 AI 추천이 연결되면 이 파일의 후보 생성 부분을 교체합니다.

import '../models/models.dart';
import '../services/readiness_service.dart';
import '../state/app_state.dart';
import 'mock_data.dart';

enum _Kind { lifeMission, meetMission, jobMission, team, program, job }

List<HomeRecommendation> buildHomeRecommendations(AppState state, {int maxCount = 3}) {
  final readiness = state.readiness;
  final stage = readiness.stage;
  final weakest = readiness.weakest;
  final time = state.effectiveDiagnosis.timeCommitment;

  // 단계별로 추천해도 되는 종류 (앞에 있을수록 먼저)
  var allowed = switch (stage) {
    UserStage.rhythm => [_Kind.lifeMission],
    UserStage.social => [_Kind.meetMission, _Kind.team, _Kind.lifeMission],
    UserStage.explore => [_Kind.program, _Kind.jobMission, _Kind.team],
    UserStage.ready => switch (weakest.area) {
        ReadinessArea.grades || ReadinessArea.language || ReadinessArea.certificate => [_Kind.program, _Kind.jobMission, _Kind.job],
        _ => [_Kind.program, _Kind.team, _Kind.job],
      },
  };
  // 준비도가 아직 낮으면 채용 공고는 빼고, 80점 이상이면 탐색 단계에도 공고를 넣습니다.
  if (readiness.score < 60) allowed.remove(_Kind.job);
  if (readiness.score >= 80 && !allowed.contains(_Kind.job) && stage == UserStage.explore) {
    allowed = [...allowed, _Kind.job];
  }

  // 하루 시간
  if (time == '10분 정도') {
    allowed = allowed.where((k) => k.index <= _Kind.jobMission.index).toList();
    if (allowed.isEmpty) allowed = [_Kind.jobMission];
  } else if (time == '30분 정도') {
    allowed.remove(_Kind.job);
    if (allowed.isEmpty) allowed = [_Kind.program];
  }

  // 먼저 도전하고 싶은 것 → 순서만 앞으로
  final prefer = switch (state.effectiveDiagnosis.primaryGoal) {
    '생활 리듬 되찾기' => _Kind.lifeMission,
    '사람 만나기' => _Kind.team,
    '경험 쌓기' => _Kind.program,
    '바로 취업 준비' => _Kind.job,
    _ => null,
  };
  if (prefer != null && allowed.remove(prefer)) allowed.insert(0, prefer);

  final maxMinutes = time == '10분 정도' ? 10 : 999;
  final byKind = <_Kind, List<HomeRecommendation>>{
    for (final k in allowed) k: _candidates(state, k, maxMinutes, readiness, weakest),
  };

  // 종류별로 하나씩 번갈아 고릅니다.
  final picked = <HomeRecommendation>[];
  for (var round = 0; picked.length < maxCount; round++) {
    var added = false;
    for (final k in allowed) {
      final list = byKind[k]!;
      if (round < list.length && picked.length < maxCount) {
        picked.add(list[round]);
        added = true;
      }
    }
    if (!added) break;
  }
  return picked;
}

/// AI 에게 넘길 전체 후보 (단계·시간으로 거르지 않음. 거르는 건 AI 가 판단)
List<HomeRecommendation> allHomeCandidates(AppState state) {
  final r = state.readiness;
  final w = r.weakest;
  final seen = <String>{};
  return [
    for (final k in _Kind.values)
      for (final c in _candidates(state, k, 999, r, w))
        if (seen.add(c.id)) c,
  ];
}

List<HomeRecommendation> _candidates(
  AppState state,
  _Kind kind,
  int maxMinutes,
  ReadinessResult readiness,
  AreaResult weakest,
) {
  final gapReason = '${josa(weakest.label, '이', '가')} 가장 부족해요. 채우면 준비도 +${weakest.gain}점';

  switch (kind) {
    case _Kind.lifeMission:
    case _Kind.meetMission:
    case _Kind.jobMission:
      final category = switch (kind) {
        _Kind.lifeMission => const {'생활', '돈', '정책'},
        _Kind.meetMission => const {'모임'},
        _ => const {'취업'},
      };
      final reason = switch (kind) {
        _Kind.lifeMission => '작은 일부터 해내며 하루 리듬을 다시 잡아 봐요.',
        _Kind.meetMission => '사람들과 가볍게 만나는 것부터 시작해 봐요.',
        _ => '부담 없는 취업 준비부터 해 봐요.',
      };
      return [
        for (final m in state.missions)
          if (m.status == MissionStatus.todo && category.contains(m.category) && m.minutes <= maxMinutes)
            HomeRecommendation(
              id: '1:${m.id}',
              targetId: m.id,
              step: 1,
              title: m.title,
              detail: '${m.minutes}분 · ${m.category}',
              reason: reason,
              type: HomeRecommendationType.mission,
            ),
      ];

    case _Kind.team:
      return [
        for (final post in state.teamPosts)
          if (!state.isMyPost(post) && state.applicationFor(post.id) == null && !post.isFull)
            HomeRecommendation(
              id: '2:${post.id}',
              targetId: post.id,
              step: 2,
              title: post.title,
              detail: [post.category, '${post.weeks}주', post.mode].join(' · '),
              reason: weakest.area == ReadinessArea.portfolio
                  ? gapReason
                  : '함께 만든 결과물이 포트폴리오로 쌓여요.',
              type: HomeRecommendationType.team,
            ),
      ];

    case _Kind.program:
    case _Kind.job:
      final step = kind == _Kind.program ? 3 : 4;
      return [
        for (final o in mockOpportunities)
          if (o.step == step &&
              !state.isApplied(o.id) &&
              !(state.isHomeOpportunityAdded(o.id) && !state.isActivityStopped(step: o.step, activityId: o.id)))
            HomeRecommendation(
              id: '$step:${o.id}',
              targetId: o.id,
              step: step,
              title: o.title,
              detail: [o.org, if (o.region.isNotEmpty) o.region].join(' · '),
              reason: kind == _Kind.job
                  ? '준비도 ${readiness.score}점이에요. 지원해 볼 만한 공고예요.'
                  : (weakest.area == ReadinessArea.jobSkill || weakest.area == ReadinessArea.portfolio
                      ? gapReason
                      : '수준에 맞는 교육·공모전으로 경험을 쌓아 봐요.'),
              type: HomeRecommendationType.opportunity,
            ),
      ];
  }
}
