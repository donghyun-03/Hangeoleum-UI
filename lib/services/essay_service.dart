// 자기소개서 AI — 사용자가 고르고, AI 는 더 좋은 방향을 추천해요.
//   ① recommend: 목표(기업·직무·관심 분야)에 맞는 활동 추천 + 이유 + 보완 팁 + 부족한 경험
//   ② write: 고른 활동(STAR)으로 문항에 맞는 자기소개서 한 편 쓰기 (글자 수 넘으면 한 번 줄여요)
// 키 없이 실행하면 FallbackEssayService 가 예시로만 채워요.
import 'dart:convert';

import 'package:flutter/widgets.dart' show StringCharacters;

import '../models/models.dart';
import 'llm_client.dart';

/// 회사 유형 (AI 진단 Q4 와 같은 보기)
const companyTypes = ['대기업', '중견·중소', '공공기관', '스타트업', '아직 모름'];

/// 공공기관은 블라인드 채용이라 학교·지역 같은 정보를 빼요
bool isBlind(String companyType) => companyType == '공공기관';

class EssayTarget {
  final String company; // 희망 기업 (선택, 예: 카카오)
  final String job; // 지원 직무 (선택, 예: 서비스 기획)
  final String companyType;
  final List<String> interests; // 직무가 없을 때 기준이 되는 관심 분야
  const EssayTarget({this.company = '', this.job = '', required this.companyType, this.interests = const []});

  /// 직무가 있으면 직무, 없으면 관심 분야
  String get focus => job.isNotEmpty ? job : interests.join('·');

  /// 화면·복사에 쓰는 한 줄 (예: 카카오 서비스 기획)
  String get label => [if (company.isNotEmpty) company, focus].join(' ');

  /// AI 에게 보낼 모양
  Map<String, dynamic> toJson() => {'company': company, 'job': job, 'interests': interests, 'company_type': companyType};
}

/// 활동 하나에 대한 AI 의견
class RecordAdvice {
  final String id;
  final bool recommended;
  final String reason; // 왜 추천했는지 / 왜 약한지
  final String tip; // 넣는다면 이렇게 보완하면 좋아요
  const RecordAdvice({required this.id, required this.recommended, this.reason = '', this.tip = ''});
}

/// 지원 직무에 필요한데 기록이 부족한 경험
class ExperienceGap {
  final String competency;
  final String message; // 어떤 경험을 기록하면 좋은지
  const ExperienceGap({required this.competency, required this.message});
}

class Recommendation {
  final Map<String, RecordAdvice> advice; // 기록 id → 의견
  final List<ExperienceGap> gaps;
  const Recommendation({required this.advice, this.gaps = const []});
  List<String> get recommendedIds => [
    for (final a in advice.values)
      if (a.recommended) a.id,
  ];
}

/// 자기소개서 문항 (자주 나오는 것)
const essayQuestions = {
  '직무 역량': '지원 직무와 관련된 역량을 키운 경험을 적어 주세요.',
  '협업 경험': '다른 사람과 함께 목표를 이룬 경험을 적어 주세요.',
  '문제 해결': '어려운 문제를 스스로 해결한 경험을 적어 주세요.',
  '지원 동기': '지원 동기와 입사 후 하고 싶은 일을 적어 주세요.',
};

/// AI 가 쓴 자기소개서 한 편
class Essay {
  final String title; // [소제목]
  final String body;
  final List<String> usedIds; // 글에 쓴 활동 id
  final List<String> questions; // 답하면 글이 더 좋아지는 질문 (최대 2개)
  const Essay({required this.title, required this.body, this.usedIds = const [], this.questions = const []});

  /// 복사·글자 수에 쓰는 전체 글
  String get text => title.isEmpty ? body : '$title\n$body';

  /// 공백 포함 글자 수
  int get length => text.characters.length;
}

abstract class EssayService {
  Future<Recommendation> recommend(EssayTarget target, List<ActivityRecord> records);

  /// answers: 질문 → 사용자가 답한 내용
  Future<Essay> write(
    EssayTarget target,
    List<ActivityRecord> picked, {
    required String question,
    required int limit,
    Map<String, String> answers = const {},
  });
}

// 활동을 AI 에게 보낼 모양으로
Map<String, dynamic> _recordJson(ActivityRecord r, {String? answer}) => {
  'id': r.id,
  'title': r.title,
  'date': r.date,
  'star': {'S': r.star.s, 'T': r.star.t, 'A': r.star.a, 'R': r.star.r},
  'attachments': r.attachments.length,
  if (answer != null && answer.trim().isNotEmpty) 'extra_answer': answer.trim(),
};

const recommendPrompt = '''
너는 쉬었음 청년의 자기소개서를 돕는 코치야. 최종 선택은 사용자가 해. 너는 더 좋은 방향을 추천만 해.
입력: 희망 기업(없을 수 있음), 지원 직무(없을 수 있음), 관심 분야, 회사 유형, 활동 기록 목록.
- 지원 직무가 비어 있으면 관심 분야를 기준으로 판단해.
- 희망 기업이 있으면 그 업종과 회사 유형에 맞춰 판단하되, 기업 정보(인재상, 사업 내용 등)를 지어내지 마.
할 일:
- 지원 직무에 가장 도움이 되는 활동을 최대 3개 골라 recommended 를 true 로 해.
  고르는 순서: 직무 연관성 > 내 역할과 숫자 결과가 분명함 > 첨부(증거)가 있음 > 최근 활동.
- 모든 활동에 reason(추천하거나 약한 이유, 40자 이내)을 써.
- 모든 활동에 tip(자소서에 쓴다면 보완할 점 하나, 40자 이내, 없으면 빈 문자열)을 써.
  추천하지 않은 활동도 사용자가 넣을 수 있으니, 막지 말고 어떻게 하면 직무와 연결되는지 알려 줘.
- gaps: 지원 직무에 필요한데 기록으로 근거가 부족한 역량 최대 2개. message 에는 어떤 경험을 기록하면 좋은지 한 문장으로.
- 기록에 없는 사실은 지어내지 마.
JSON 모양:
{"items":[{"id":"기록 id","recommended":true,"reason":"...","tip":"..."}],
 "gaps":[{"competency":"협업","message":"..."}]}
''';

const essayPrompt = '''
너는 쉬었음 청년의 자기소개서를 쓰는 취업 코치야.
입력: 희망 기업(없을 수 있음), 지원 직무(없을 수 있음), 관심 분야, 회사 유형, 문항, 글자 수 한도,
      사용자가 고른 활동(STAR, 앞에 있을수록 중요), 추가 답변(있을 수 있음).
규칙:
- 문항에 바로 답하는 두괄식으로 써. 첫 문장에 결론(나의 강점이나 답)을 써.
- title: [ ]로 감싼 소제목, 25자 이내. 핵심 역량과 근거가 한눈에 보이게.
- body: 고른 활동을 근거로 써. 앞쪽 활동을 중심으로, 한 활동은 상황 → 목표 → 행동 → 결과 흐름으로.
  행동은 무엇을 어떻게 했는지 구체적으로, 결과는 기록에 있는 숫자를 그대로 써.
  마지막 문단은 이 경험을 지원 직무(희망 기업이 있으면 그 회사)에서 어떻게 쓸지로 마무리해.
- 공백 포함 글자 수: title 과 body 를 합쳐 한도의 85~100% 로 맞춰. 한도를 넘기지 마.
- "~습니다" 체. 문단은 2~4개, 문단 사이에는 빈 줄 하나.
- 기록과 추가 답변에 없는 숫자, 역할, 성과, 기업 정보(인재상, 사업 등)는 절대 지어내지 마.
  지원 동기 문항에서 기업 정보가 없으면 직무와 내 경험을 중심으로 써.
- 공백기는 숨기지 말고, 필요하면 그 기간에 스스로 준비한 것으로 자연스럽게 써.
- 회사 유형이 공공기관이면 학교, 지역, 가족, 나이 같은 개인 정보는 쓰지 마.
- questions: 글을 더 좋게 할 빠진 정보를 묻는 짧은 질문, 최대 2개. 없으면 빈 배열.
- used_ids: 글에 실제로 쓴 활동 id.
JSON 모양:
{"title":"[...]","body":"...","used_ids":["기록 id"],"questions":["..."]}
''';

List<String> _strings(Object? v) => [for (final x in (v as List? ?? const [])) '$x'.trim()]..removeWhere((s) => s.isEmpty);
String _str(Object? v) => v == null ? '' : '$v'.trim();

class AiEssayService implements EssayService {
  AiEssayService({LlmClient? client}) : _llm = client ?? LlmClient();
  final LlmClient _llm;

  @override
  Future<Recommendation> recommend(EssayTarget target, List<ActivityRecord> records) async {
    final j = await _llm.askJson(
      system: recommendPrompt,
      user: jsonEncode({
        ...target.toJson(),
        'records': [for (final r in records) _recordJson(r)],
      }),
    );
    final ids = {for (final r in records) r.id};
    final advice = <String, RecordAdvice>{};
    for (final it in (j['items'] as List? ?? const [])) {
      final m = it as Map<String, dynamic>;
      final id = _str(m['id']);
      if (!ids.contains(id)) continue; // AI 가 없는 id 를 지어내면 버려요
      advice[id] = RecordAdvice(id: id, recommended: m['recommended'] == true, reason: _str(m['reason']), tip: _str(m['tip']));
    }
    // 추천은 최대 3개까지만
    var n = 0;
    for (final id in advice.keys.toList()) {
      final a = advice[id]!;
      if (a.recommended && ++n > 3) advice[id] = RecordAdvice(id: id, recommended: false, reason: a.reason, tip: a.tip);
    }
    return Recommendation(
      advice: advice,
      gaps: [
        for (final g in (j['gaps'] as List? ?? const []).take(2))
          ExperienceGap(competency: _str((g as Map)['competency']), message: _str(g['message'])),
      ],
    );
  }

  @override
  Future<Essay> write(
    EssayTarget target,
    List<ActivityRecord> picked, {
    required String question,
    required int limit,
    Map<String, String> answers = const {},
  }) async {
    final filled = {
      for (final e in answers.entries)
        if (e.value.trim().isNotEmpty) e.key: e.value.trim(),
    };
    final input = {
      ...target.toJson(),
      'question': question,
      'limit': limit,
      'records': [for (final r in picked) _recordJson(r)],
      if (filled.isNotEmpty)
        'extra_answers': [
          for (final e in filled.entries) {'q': e.key, 'a': e.value},
        ],
    };
    final ids = {for (final r in picked) r.id};
    var essay = _parse(await _llm.askJson(system: essayPrompt, user: jsonEncode(input), temperature: 0.5), ids);
    // AI 는 글자 수를 잘 못 세요. 넘으면 한 번만 줄여 달라고 해요
    if (essay.length > limit) {
      final shorter = await _llm.askJson(
        system: essayPrompt,
        user: jsonEncode({
          ...input,
          'previous': {'title': essay.title, 'body': essay.body},
          'request': '위 글이 공백 포함 ${essay.length}자라 한도($limit자)를 넘었어. 내용은 그대로 두고 ${(limit * 0.9).round()}자 정도로 줄여 줘.',
        }),
      );
      essay = _parse(shorter, ids);
    }
    return essay;
  }

  static Essay _parse(Map<String, dynamic> j, Set<String> ids) {
    var title = _str(j['title']);
    if (title.isNotEmpty && !title.startsWith('[')) title = '[$title]';
    return Essay(
      title: title,
      body: _str(j['body']),
      usedIds: _strings(j['used_ids']).where(ids.contains).toList(),
      questions: _strings(j['questions']).take(2).toList(),
    );
  }
}

/// 키 없이 실행했을 때만 쓰는 대체용 (진짜 AI 아님)
class FallbackEssayService implements EssayService {
  @override
  Future<Recommendation> recommend(EssayTarget target, List<ActivityRecord> records) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return Recommendation(
      advice: {
        for (final (i, r) in records.indexed)
          r.id: RecordAdvice(
            id: r.id,
            recommended: i < 3,
            reason: i < 3 ? '(키 없이 실행 중) 최근 기록이에요' : '(키 없이 실행 중) 예시 의견',
            tip: '(키 없이 실행 중) 맡은 역할을 적어 주세요',
          ),
      },
      gaps: const [ExperienceGap(competency: '협업', message: '(키 없이 실행 중) 팀으로 한 경험을 기록해 보세요.')],
    );
  }

  @override
  Future<Essay> write(
    EssayTarget target,
    List<ActivityRecord> picked, {
    required String question,
    required int limit,
    Map<String, String> answers = const {},
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final body = [for (final r in picked) '${r.star.s} ${r.star.a} ${r.star.r}'].join('\n\n');
    return Essay(
      title: '[(키 없이 실행 중) 예시 소제목]',
      body: body.characters.take(limit - 30).toString(),
      usedIds: [for (final r in picked) r.id],
      questions: answers.isEmpty ? const ['(키 없이 실행 중) 팀은 몇 명이었나요?'] : const [],
    );
  }
}

/// 앱 전체에서 쓰는 자소서 서비스 (테스트에서는 바꿔 끼울 수 있어요)
EssayService essayService = hasLlmKey ? AiEssayService() : FallbackEssayService();
