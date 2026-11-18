// 홈 "AI 추천 활동" — 후보(미션·팀·교육/공모전·공고) 중에서 AI(BAZE)가 지금 이 사람에게 맞는 것을 최대 3개 고릅니다.
// 키가 없거나 AI 가 실패하면 규칙 추천(data/home_recommendation_data.dart buildHomeRecommendations)을 씁니다.
// 재료(준비도·진단·후보 목록)가 바뀔 때만 다시 부릅니다. (AppState.refreshRecommendations)

import 'dart:convert';

import '../models/diagnosis_profile.dart';
import '../models/models.dart';
import 'llm_client.dart';
import 'readiness_service.dart';

class RecommendInput {
  const RecommendInput({
    required this.readiness,
    required this.diagnosis,
    required this.candidates,
    this.likes = const [],
  });

  final ReadinessResult readiness;
  final DiagnosisProfile diagnosis;
  final List<HomeRecommendation> candidates;
  final List<String> likes;

  String get signature => jsonEncode({
        's': readiness.score,
        'a': [for (final a in readiness.shownAreas) a.score],
        'w': readiness.weakest.area.name,
        'd': diagnosis.answers,
        'c': [for (final c in candidates) c.id],
        'k': likes,
      });
}

abstract class RecommendJudge {
  Future<List<HomeRecommendation>> pick(RecommendInput input);
}

class BazeRecommendJudge implements RecommendJudge {
  BazeRecommendJudge({LlmClient? client}) : _client = client ?? LlmClient();
  final LlmClient _client;

  static const maxPicks = 3;

  static const system = '''너는 쉬었음 청년에게 지금 할 활동을 골라 주는 코치야.
$rules''';

  /// 고르는 기준 (준비도 판단과 한 번에 물어볼 때도 같이 씁니다: readiness_ai.dart)
  static const rules = '''후보 목록 안에서만 최대 3개를 골라. 후보에 없는 id 를 만들지 마.
고르는 기준:
- 지금 단계가 "생활 리듬 되찾는 중"이면 짧은 생활 미션만. 프로젝트·공모전·채용 공고는 절대 고르지 마.
- "사람들과 연결되는 중"이면 모임 미션·팀 프로젝트 위주.
- "경험 쌓을 거리 찾는 중"이면 수준에 맞는 교육·공모전·짧은 팀 활동.
- "취업 준비 중"이면 가장 부족한 항목을 채우는 활동. 준비도가 60점 미만이면 채용 공고는 고르지 마.
- 하루 시간이 10분이면 10분 이하 미션만, 30분이면 채용 공고는 빼.
- 관심 분야·희망 직무·끌리는 것과 가까운 것을 먼저.
reason: 왜 이 사람에게 지금 이게 좋은지 30자 이내 한 문장, "~해요" 체.''';

  static String userPrompt(RecommendInput i) {
    final r = i.readiness;
    final areas = [for (final a in r.shownAreas) '${a.label} ${a.score}점(${areaStatusLabel[a.status]})'].join(', ');
    final list = candidateLines(i.candidates);
    return '''${i.diagnosis.toPromptContext()}

[지금 상태]
- 단계: ${userStageLabel[r.stage]}
- 준비도 ${r.score}점: $areas
- 가장 먼저 채울 항목: ${r.weakest.label}
- 기준: ${r.target.label}
- 끌리는 것: ${i.likes.isEmpty ? '없음' : i.likes.join(', ')}

[후보 ${list.length}개]
${list.join('\n')}

JSON 으로 답해: {"picks":[{"id":"","reason":""}]}''';
  }

  static List<String> candidateLines(List<HomeRecommendation> candidates) => [
        for (final c in candidates) '- id=${c.id} | ${_typeLabel(c)} | ${c.title} | ${c.detail}',
      ];

  static String _typeLabel(HomeRecommendation c) => switch (c.type) {
        HomeRecommendationType.mission => '미션',
        HomeRecommendationType.team => '팀 프로젝트',
        HomeRecommendationType.opportunity => c.step == 4 ? '채용 공고' : '교육·공모전·프로그램',
      };

  @override
  Future<List<HomeRecommendation>> pick(RecommendInput input) async {
    final json = await _client.askJson(system: system, user: userPrompt(input), temperature: 0.3);
    return parse(json, input.candidates);
  }

  static List<HomeRecommendation> parse(Map<String, dynamic> json, List<HomeRecommendation> candidates) {
    final byId = {for (final c in candidates) c.id: c};
    final picked = <HomeRecommendation>[];
    for (final p in (json['picks'] as List? ?? const [])) {
      if (p is! Map) continue;
      final c = byId.remove('${p['id']}');
      if (c == null) continue;
      final reason = '${p['reason'] ?? ''}'.trim();
      picked.add(HomeRecommendation(
        id: c.id,
        targetId: c.targetId,
        step: c.step,
        title: c.title,
        detail: c.detail,
        reason: reason.isEmpty ? c.reason : reason,
        type: c.type,
      ));
      if (picked.length >= maxPicks) break;
    }
    if (picked.isEmpty) throw const LlmException('AI 가 고른 추천이 없어요');
    return picked;
  }
}
