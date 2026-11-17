// 홈 AI 추천 활동의 임시 후보 데이터 구성입니다.
// 현재는 AppState와 개발용 공고 데이터를 바탕으로 후보를 만들며,
// 실제 AI 추천 결과가 연결되면 이 파일의 후보 생성 부분을 교체합니다.

import '../models/models.dart';
import '../state/app_state.dart';
import 'home_mock_data.dart';
import 'mock_data.dart';

List<HomeRecommendation> buildHomeRecommendations(AppState state) {
  final byStep = <List<HomeRecommendation>>[[], [], [], []];

  // STEP 1: 아직 시작하지 않은 미션
  for (final mission in state.missions) {
    if (mission.status != MissionStatus.todo) continue;

    byStep[0].add(
      HomeRecommendation(
        id: '1:${mission.id}',
        targetId: mission.id,
        step: 1,
        title: mission.title,
        detail: '${mission.minutes}분 · ${mission.category}',
        reason: homeRecommendationReasonStep1,
        type: HomeRecommendationType.mission,
      ),
    );
  }

  // STEP 2: 아직 신청하지 않은 팀 모집 글
  for (final post in state.teamPosts) {
    if (state.isMyPost(post) || state.applicationFor(post.id) != null) {
      continue;
    }

    byStep[1].add(
      HomeRecommendation(
        id: '2:${post.id}',
        targetId: post.id,
        step: 2,
        title: post.title,
        detail: [post.category, '${post.weeks}주', post.mode].join(' · '),
        reason: homeRecommendationReasonStep2,
        type: HomeRecommendationType.team,
      ),
    );
  }

  // STEP 3·4: 지원하지 않았고 홈에 추가되지 않은 공고
  for (final opportunity in mockOpportunities) {
    if (opportunity.step != 3 && opportunity.step != 4) continue;
    if (state.isApplied(opportunity.id)) continue;

    final onHome = state.isHomeOpportunityAdded(opportunity.id) &&
        !state.isActivityStopped(
          step: opportunity.step,
          activityId: opportunity.id,
        );
    if (onHome) continue;

    byStep[opportunity.step - 1].add(
      HomeRecommendation(
        id: '${opportunity.step}:${opportunity.id}',
        targetId: opportunity.id,
        step: opportunity.step,
        title: opportunity.title,
        detail: [
          opportunity.org,
          if (opportunity.region.isNotEmpty) opportunity.region,
        ].join(' · '),
        reason: homeRecommendationReasonStep34,
        type: HomeRecommendationType.opportunity,
      ),
    );
  }

  // STEP 1→4 순서로 한 개씩 번갈아 최대 2개를 선택합니다.
  const maxCount = 2;
  final picked = <HomeRecommendation>[];

  for (var round = 0; picked.length < maxCount; round++) {
    var added = false;
    for (final list in byStep) {
      if (round < list.length && picked.length < maxCount) {
        picked.add(list[round]);
        added = true;
      }
    }
    if (!added) break;
  }

  return picked;
}
