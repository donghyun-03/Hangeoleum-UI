// AI 자기소개서: 목표 → AI 추천(미리 체크) → 사용자가 바꾸기 → 문항·글자 수 → 쓰기 → 답 넣고 다시 쓰기
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:hangeoleum/models/models.dart';
import 'package:hangeoleum/router/main_tabs.dart';
import 'package:hangeoleum/screens/record/essay_screen.dart';
import 'package:hangeoleum/services/essay_service.dart';
import 'package:hangeoleum/services/llm_client.dart';
import 'package:hangeoleum/state/app_state.dart';
import 'package:hangeoleum/theme/app_theme.dart';

class _FakeEssay implements EssayService {
  List<String>? pickedIds;
  String? question;
  int? limit;
  Map<String, String>? answers;
  EssayTarget? target;

  @override
  Future<Recommendation> recommend(EssayTarget target, List<ActivityRecord> records) async => Recommendation(
    advice: {for (final (i, r) in records.indexed) r.id: RecordAdvice(id: r.id, recommended: i == 0, reason: '이유 $i', tip: '팁 $i')},
    gaps: const [ExperienceGap(competency: '협업', message: '팀 경험을 기록해 보세요.')],
  );

  @override
  Future<Essay> write(
    EssayTarget target,
    List<ActivityRecord> picked, {
    required String question,
    required int limit,
    Map<String, String> answers = const {},
  }) async {
    this.target = target;
    pickedIds = [for (final r in picked) r.id];
    this.question = question;
    this.limit = limit;
    this.answers = answers;
    return Essay(
      title: '[${target.label} 소제목]',
      body: answers.isEmpty ? '첫 글입니다.' : '답을 넣은 글입니다.',
      usedIds: pickedIds!,
      questions: answers.isEmpty ? const ['몇 명이었나요?'] : const [],
    );
  }
}

Future<void> _tapText(WidgetTester t, String text) async {
  final f = find.text(text);
  await t.ensureVisible(f.first);
  await t.tap(f.first);
  await t.pumpAndSettle();
}

void main() {
  testWidgets('AI 자소서: 추천을 바꿔 고르고, 문항을 골라 쓰고, 답 넣고 다시 쓰기', (t) async {
    // 폰 폭(390)에서도 넘치지 않는지
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final fake = _FakeEssay();
    essayService = fake;
    final state = AppState();
    final records = state.records;
    expect(records.length, greaterThan(1));

    await t.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: state),
          ChangeNotifierProvider(create: (_) => MainTabs()),
        ],
        child: MaterialApp(theme: buildAppTheme(), home: const EssayScreen()),
      ),
    );

    // ① 목표: 기업 + 직무 + 공공기관(블라인드)
    await t.enterText(find.widgetWithText(TextField, '예: 카카오, 한국전력공사'), '한국전력공사');
    await _tapText(t, '서비스 기획');
    await _tapText(t, '공공기관');
    expect(find.textContaining('블라인드 채용'), findsOneWidget);
    await _tapText(t, '다음: AI 추천 받기');

    // ② 첫 기록만 추천 → 미리 체크(1개). 추천 밖 기록을 더 넣으면 팁, 순서 바꾸기
    expect(find.text('AI 추천'), findsOneWidget);
    expect(find.text('이런 경험이 있으면 더 좋아요'), findsOneWidget);
    await _tapText(t, records[1].title);
    expect(find.text('팁 1'), findsOneWidget);
    await t.tap(find.byTooltip('${records[1].title} 앞으로'));
    await t.pump();
    await _tapText(t, '다음: 문항 고르기 (2개)');

    // ③ 문항·글자 수 → 쓰기
    expect(find.textContaining('자기소개서 쓰기'), findsWidgets);
    await _tapText(t, '협업 경험');
    await _tapText(t, '800자');
    await _tapText(t, '자기소개서 쓰기');
    expect(fake.pickedIds, [records[1].id, records[0].id]);
    expect(fake.question, essayQuestions['협업 경험']);
    expect(fake.limit, 800);
    expect(fake.target!.company, '한국전력공사');
    expect(find.text('[한국전력공사 서비스 기획 소제목]'), findsOneWidget);
    expect(find.text('다시 쓰기'), findsOneWidget);

    // 조건을 바꾸면 버튼이 '이 조건으로 다시 쓰기'
    await _tapText(t, '500자');
    expect(find.text('이 조건으로 다시 쓰기'), findsOneWidget);

    // 회사 문항을 직접 넣으면 그걸로 써요
    await t.enterText(find.widgetWithText(TextField, '회사 문항이 있으면 그대로 붙여 넣어 주세요 (선택)'), '우리 회사에 지원한 이유는?');
    await t.pump();

    // 질문에 답하면 '답 넣고 다시 쓰기'
    final field = find.widgetWithText(TextField, '짧게 적어도 돼요');
    await t.ensureVisible(field);
    await t.enterText(field, '4명');
    await t.pump();
    await _tapText(t, '답 넣고 다시 쓰기');
    expect(fake.answers, {'몇 명이었나요?': '4명'});
    expect(fake.question, '우리 회사에 지원한 이유는?');
    expect(find.text('답을 넣은 글입니다.'), findsOneWidget);
    expect(find.text('이걸 알려 주면 더 좋아져요'), findsNothing);
  });

  test('AI 답 읽기: 추천은 3개까지·없는 id 버림, 글자 수 넘으면 한 번 줄여 달라고 함', () async {
    final sent = <Map<String, dynamic>>[];
    final client = MockClient((req) async {
      final body = jsonDecode(req.body) as Map<String, dynamic>;
      final user = jsonDecode((body['messages'] as List)[1]['content'] as String) as Map<String, dynamic>;
      sent.add(user);
      final Map<String, dynamic> content;
      if (user.containsKey('question')) {
        content = user.containsKey('previous')
            ? {
                'title': '짧은 제목',
                'body': '가' * 80,
                'used_ids': ['b', 'zzz'],
                'questions': ['q1', 'q2', 'q3'],
              }
            : {
                'title': '[긴 글]',
                'body': '가' * 200,
                'used_ids': ['b'],
              };
      } else {
        content = {
          'items': [
            for (final id in ['a', 'b', 'c', 'd']) {'id': id, 'recommended': true, 'reason': 'r', 'tip': ''},
            {'id': 'zzz', 'recommended': true},
          ],
          'gaps': [
            {'competency': '협업', 'message': 'm'},
          ],
        };
      }
      return http.Response.bytes(
        utf8.encode(
          jsonEncode({
            'choices': [
              {
                'message': {'content': '```json\n${jsonEncode(content)}\n```'},
              },
            ],
          }),
        ),
        200,
      );
    });
    final svc = AiEssayService(
      client: LlmClient(apiKey: 'k', model: 'm', client: client),
    );
    ActivityRecord rec(String id) => ActivityRecord(
      id: id,
      step: 1,
      title: id,
      date: '2026-11-12',
      raw: '',
      star: const Star(s: 's', t: 't', a: 'a', r: 'r'),
    );
    final records = [
      for (final id in ['a', 'b', 'c', 'd']) rec(id),
    ];
    const target = EssayTarget(job: '', interests: ['IT·데이터'], companyType: '대기업');
    expect(target.label, 'IT·데이터');

    final r = await svc.recommend(target, records);
    expect(r.advice.containsKey('zzz'), false);
    expect(r.recommendedIds, ['a', 'b', 'c']);

    final e = await svc.write(target, [records[1]], question: '문항', limit: 100, answers: {'몇 명?': '4명', '빈 답': ' '});
    expect(sent.length, 3); // 추천 1 + 쓰기 1 + 줄이기 1
    expect(sent[1]['extra_answers'], [
      {'q': '몇 명?', 'a': '4명'},
    ]);
    expect(sent[1]['interests'], ['IT·데이터']);
    expect(e.title, '[짧은 제목]');
    expect(e.length, lessThanOrEqualTo(100));
    expect(e.usedIds, ['b']);
    expect(e.questions.length, 2);
  });
}
