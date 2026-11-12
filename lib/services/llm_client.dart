// AI(BAZE) 에 JSON 답을 받아오는 공통 도우미 — 자기소개서(essay_service)에서 써요.
// 키는 STAR 와 똑같이 실행할 때만 넣어요:
//   flutter run --dart-define=LLM_KEY=BAZE키 --dart-define=LLM_MODEL=모델이름
import 'dart:convert';

import 'package:http/http.dart' as http;

const _key = String.fromEnvironment('LLM_KEY');
const _model = String.fromEnvironment('LLM_MODEL');

/// 키를 넣고 실행했는지
bool get hasLlmKey => _key.isNotEmpty;

class LlmException implements Exception {
  final String message;
  const LlmException(this.message);
  @override
  String toString() => message;
}

class LlmClient {
  LlmClient({String? apiKey, String? model, http.Client? client})
    : apiKey = apiKey ?? _key,
      model = model ?? _model,
      _client = client ?? http.Client();
  final String apiKey;
  final String model;
  final http.Client _client;

  static final _uri = Uri.parse('https://api.baze.co/v1/gateway/chat/completions');

  /// system(규칙) 과 user(재료) 를 보내고 JSON 하나를 받아요. 깨지면 한 번만 다시 요청해요.
  Future<Map<String, dynamic>> askJson({required String system, required String user, double temperature = 0.3}) async {
    if (model.isEmpty) throw const LlmException('모델 이름이 없어요. --dart-define=LLM_MODEL=모델이름 을 같이 넣어 주세요');
    final body = jsonEncode({
      'model': model,
      'temperature': temperature,
      'messages': [
        {'role': 'system', 'content': '$system\n\n설명, 마크다운, ``` 없이 JSON 하나로만 답해.'},
        {'role': 'user', 'content': user},
      ],
    });
    for (var attempt = 0; attempt < 2; attempt++) {
      final res = await _client
          .post(_uri, headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $apiKey'}, body: body)
          .timeout(const Duration(seconds: 45));
      if (res.statusCode == 401) throw const LlmException('BAZE 키가 맞지 않아요 (401)');
      if (res.statusCode != 200) throw LlmException('AI 응답 오류 (${res.statusCode})');
      try {
        final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
        final text = data['choices'][0]['message']['content'] as String;
        final a = text.indexOf('{'), b = text.lastIndexOf('}');
        return jsonDecode(text.substring(a, b + 1)) as Map<String, dynamic>;
      } catch (_) {
        // 다음 시도로
      }
    }
    throw const LlmException('AI 답을 읽지 못했어요');
  }
}
