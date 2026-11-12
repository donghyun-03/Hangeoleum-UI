// STAR 정리 서비스 — 활동 메모를 LLM 에 보내 S·T·A·R 로 받아요.
//
// 실행할 때만 키를 넣어요 (코드·깃허브에는 키를 절대 쓰지 않기):
//   flutter run --dart-define=LLM_KEY=BAZE키 --dart-define=LLM_MODEL=모델이름
// 키 없이 실행하면 FallbackStarService 가 대신 답해요 (앱이 멈추지 않게).
// 나중에 서버(Supabase Edge Function)를 만들면 ServerStarService 만 새로 만들어 starService 에 끼우면 돼요.
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/models.dart';

/// LLM 이 돌려준 결과 (json/llm/c6_star_output.schema.json 과 같은 모양)
class StarResult {
  final bool needMoreInfo; // 메모가 너무 짧으면 true
  final String? title; // AI 가 지은 기록 제목 (예: 강화학습 장애물 회피 설계)
  final String? followUpQuestion; // needMoreInfo 일 때 사용자에게 물을 질문
  final Star? star;
  final List<String> competencyTags;
  final List<String> sourceFacts; // 메모에서 그대로 가져온 사실
  final List<String> improveQuestions; // 답하면 STAR가 더 좋아지는 질문 (최대 2개)

  const StarResult({
    required this.needMoreInfo,
    this.title,
    this.followUpQuestion,
    this.star,
    this.competencyTags = const [],
    this.sourceFacts = const [],
    this.improveQuestions = const [],
  });

  factory StarResult.fromJson(Map<String, dynamic> j) {
    final s = j['star'] as Map<String, dynamic>?;
    final need = j['need_more_info'] == true;
    return StarResult(
      needMoreInfo: need,
      title: (j['title'] as String?)?.trim().isEmpty ?? true ? null : (j['title'] as String).trim(),
      followUpQuestion: j['follow_up_question'] as String?,
      star: (need || s == null)
          ? null
          : Star(s: '${s['S'] ?? ''}', t: '${s['T'] ?? ''}', a: '${s['A'] ?? ''}', r: '${s['R'] ?? ''}'),
      competencyTags: [for (final t in (j['competency_tags'] as List? ?? const [])) '$t'],
      sourceFacts: [for (final t in (j['source_facts'] as List? ?? const [])) '$t'],
      improveQuestions: [for (final t in (j['improve_questions'] as List? ?? const [])) '$t'].take(2).toList(),
    );
  }
}

/// 질문에 답한 내용을 메모 뒤에 붙여요. AI 는 이것도 메모와 같은 사실로 써요.
String memoWithAnswers(String memo, Map<String, String> answers) {
  final filled = answers.entries.where((e) => e.value.trim().isNotEmpty).toList();
  if (filled.isEmpty) return memo;
  return [memo, '', '[추가 답변]', for (final e in filled) ...['Q: ${e.key}', 'A: ${e.value.trim()}']].join('\n');
}

/// 화면은 이 틀만 알아요. 어떤 AI 를 쓰는지는 몰라도 돼요.
abstract class StarService {
  Future<StarResult> makeStar(String memo);
}

class StarServiceException implements Exception {
  final String message;
  const StarServiceException(this.message);
  @override
  String toString() => message;
}

// ── 프롬프트 (규칙을 바꾸고 싶으면 여기만 고쳐요)
const starPrompt = '''
너는 쉬었음 청년의 활동 메모를 자기소개서에 바로 쓸 수 있는 STAR 문장으로 다듬는 취업 코치야.

[칸별 규칙]
- S 상황: 어떤 활동이었는지와, 왜 이 활동을 하게 됐는지(관심이나 문제의식)를 함께 써.
- T 목표: 이 활동에서 무엇을 어디까지 이루려 했는지 분명하게 써. "~하고자 함"처럼 흐리게 쓰지 마.
- A 행동: 직접 한 일을 동사 2~3개로 구체적으로 써(조사, 분석, 설계, 제작, 발표 등). "생각함", "노력함" 같은 말은 쓰지 마.
  팀 활동이면 팀 규모, 내 역할, 팀원과 일을 어떻게 나누고 맞췄는지를 꼭 넣어.
- R 결과: 결과를 숫자와 함께 써(순위, 참가 팀 수, 기간, 횟수, 인원, 전후 변화).
  마지막에 이 경험으로 얻은 역량이나 배운 점을 한 문장 붙여.
- 말투는 "~했습니다" 체. 각 칸은 1~3문장.
- title: 무엇을 했는지 한눈에 보이는 20자 이내 명사형 제목. 분야 + 핵심 일로 지어.
  예: "강화학습 장애물 회피 설계", "쉬었음 청년 앱 아이디어 공모전 입상", "엑셀 가계부 자동화". "오늘 나는" 같은 말은 빼.
- 메모 속 감상이나 바람("좋겠다" 등)은 STAR에 넣지 마.

[지어내지 않기]
- 숫자, 팀원, 역할, 기관 이름, 성과는 메모(와 [추가 답변])에 있을 때만 써. 없으면 그 부분은 빼고 자연스럽게 써.
- 빠진 정보 중 STAR를 가장 좋아지게 할 것을 최대 2개 골라 improve_questions 에 짧은 질문으로 넣어.
  예: "팀은 몇 명이었고, 직접 맡은 역할은 무엇이었나요?", "몇 팀 중 몇 등이었나요?"
  더 물어볼 게 없으면 빈 배열로 둬.
- 메모가 한 줄뿐이거나 무엇을 했는지 전혀 알 수 없을 때만 need_more_info 를 true 로 하고,
  follow_up_question 에 질문 하나만 넣어. 이때 star 는 비워.
- STAR에 쓴 사실은 source_facts 에 메모 원문 그대로 적어.
- competency_tags 는 [데이터 활용, 문제 해결, 협업, 소통, 꾸준함, 기획, 디지털 도구] 중 1~2개만 골라.
''';

/// BAZE API 게이트웨이 (OpenAI 방식 주소). 키 하나로 여러 회사 모델을 부를 수 있어요.
class BazeStarService implements StarService {
  BazeStarService(this.apiKey, {required this.model, http.Client? client}) : _client = client ?? http.Client();
  final String apiKey;
  final String model; // 예: BAZE 모델 목록(/models)에 나오는 이름
  final http.Client _client;

  static final _uri = Uri.parse('https://api.baze.co/v1/gateway/chat/completions');

  // AI 에게 "이 모양 JSON 으로만 답해"라고 알려 주는 부분 (json/llm/c6_star_output.schema.json)
  static const _format = '''
아래 JSON 하나로만 답해. 설명, 마크다운, ``` 는 쓰지 마.
{"need_more_info": false,
 "title": "20자 이내 제목",
 "follow_up_question": null,
 "star": {"S": "상황", "T": "목표", "A": "행동", "R": "결과"},
 "competency_tags": ["문제 해결"],
 "source_facts": ["메모 원문 그대로"],
 "improve_questions": ["빠진 정보를 묻는 짧은 질문"]}
''';

  @override
  Future<StarResult> makeStar(String memo) async {
    if (model.isEmpty) {
      throw const StarServiceException('모델 이름이 없어요. --dart-define=LLM_MODEL=모델이름 을 같이 넣어 주세요');
    }
    final body = jsonEncode({
      'model': model,
      'temperature': 0.3, // 낮을수록 덜 지어내요
      'messages': [
        {'role': 'system', 'content': '$starPrompt\n$_format'},
        {'role': 'user', 'content': '메모:\n$memo'},
      ],
    });

    // JSON 이 깨지는 경우가 있어서 한 번만 다시 시도해요
    for (var attempt = 0; attempt < 2; attempt++) {
      final res = await _client
          .post(_uri, headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $apiKey'}, body: body)
          .timeout(const Duration(seconds: 30));
      if (res.statusCode == 401) throw const StarServiceException('BAZE 키가 맞지 않아요 (401)');
      if (res.statusCode != 200) throw StarServiceException('AI 응답 오류 (${res.statusCode})');
      try {
        final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
        final text = data['choices'][0]['message']['content'] as String;
        return StarResult.fromJson(_pickJson(text));
      } catch (_) {
        // 다음 시도로
      }
    }
    throw const StarServiceException('AI 답을 읽지 못했어요');
  }

  /// 답 앞뒤에 다른 글이 붙어 와도 { ... } 부분만 꺼내요
  static Map<String, dynamic> _pickJson(String text) {
    final a = text.indexOf('{');
    final b = text.lastIndexOf('}');
    return jsonDecode(text.substring(a, b + 1)) as Map<String, dynamic>;
  }
}

/// 키 없이 실행했을 때만 쓰는 대체용 (진짜 AI 아님)
class FallbackStarService implements StarService {
  @override
  Future<StarResult> makeStar(String memo) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (memo.length < 20) {
      return const StarResult(needMoreInfo: true, followUpQuestion: '무엇을 했고, 해 보니 어땠는지 한 줄만 더 적어 줄래요?');
    }
    return StarResult(
      needMoreInfo: false,
      star: Star(s: '(키 없이 실행 중) 상황', t: '(키 없이 실행 중) 목표', a: memo, r: '(키 없이 실행 중) 결과'),
      improveQuestions: const ['(키 없이 실행 중) 팀은 몇 명이었고, 직접 맡은 역할은 무엇이었나요?'],
    );
  }
}

const _llmKey = String.fromEnvironment('LLM_KEY');
const _llmModel = String.fromEnvironment('LLM_MODEL');

/// 키가 있으면 진짜 AI, 없으면 대체용
bool get usingRealAi => _llmKey.isNotEmpty;

/// 앱 전체에서 쓰는 STAR 서비스 (테스트에서는 바꿔 끼울 수 있어요)
StarService starService = usingRealAi ? BazeStarService(_llmKey, model: _llmModel) : FallbackStarService();
