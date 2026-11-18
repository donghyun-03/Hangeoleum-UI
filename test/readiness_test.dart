// 홈 준비도(구조 3안) 계산·AI 판단·저장·튜토리얼 테스트: flutter test test/readiness_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hangeoleum/data/home_recommendation_data.dart';
import 'package:hangeoleum/data/mock_data.dart';
import 'package:hangeoleum/data/user_profile_store.dart';
import 'package:hangeoleum/main.dart';
import 'package:hangeoleum/models/diagnosis_profile.dart';
import 'package:hangeoleum/models/models.dart';
import 'package:hangeoleum/services/readiness_ai.dart';
import 'package:hangeoleum/services/recommend_ai.dart';
import 'package:hangeoleum/services/readiness_service.dart';
import 'package:hangeoleum/state/app_state.dart';

ReadinessResult _eval(DiagnosisProfile d, {AppUser user = mockUser, List<ActivityRecord> records = mockRecords}) =>
    ReadinessService.evaluate(user: user, diagnosis: d, records: records, acceptedTeams: const [], doneTeamIds: const {});

/// AI 대신 정해진 답을 돌려주는 가짜 판단기
class _FakeJudge implements ReadinessJudge {
  int calls = 0;
  @override
  Future<ReadinessResult> judge(ReadinessInput input) async {
    calls++;
    return BazeReadinessJudge.parse({
      'score': 20,
      'summary': '기록이 잘 쌓이고 있어요.',
      'areas': [
        {'key': 'portfolio', 'score': 30, 'weight': 25, 'gaps': ['결과물 링크가 하나뿐이에요.'], 'evidence': ['엑셀 워크숍'], 'next_action': '기록에 결과물 붙이기'},
        {'key': 'grades', 'score': 0, 'weight': 10},
        {'key': 'language', 'score': 0, 'weight': 10, 'gaps': ['어학 성적이 없어요.'], 'next_action': '오픽 일정 확인'},
        {'key': 'job_skill', 'score': 40, 'weight': 40},
        {'key': 'certificate', 'score': 0, 'weight': 15},
      ],
      'fill': {'key': 'language', 'title': '어학: 오픽 시험 일정 확인하기', 'reason': '대기업 서류에 어학이 필요해요.'},
    }, input.ruleResult());
  }
}

/// 준비도 판단 때 후보 중 첫 번째를 같이 고르는 가짜 판단기
class _PickingJudge implements ReadinessJudge {
  @override
  Future<ReadinessResult> judge(ReadinessInput input) async => BazeReadinessJudge.parse({
        'score': 5,
        'areas': [
          {'key': 'portfolio', 'score': 5},
        ],
        'picks': [
          {'id': input.candidates.first.id, 'reason': '같이 고른 이유'},
        ],
      }, input.ruleResult());
}

class _CountingRecommendJudge implements RecommendJudge {
  int calls = 0;
  @override
  Future<List<HomeRecommendation>> pick(RecommendInput input) async {
    calls++;
    return input.candidates.take(1).toList();
  }
}

void main() {
  test('비중은 5개 합이 1, 대학을 안 다니면 성적 비중은 어학으로', () {
    for (final field in ['IT·데이터', '디자인·영상', '사무·행정', null]) {
      for (final company in ['대기업', '스타트업', '중소기업', '공기업·공공기관', null]) {
        final t = ReadinessTarget(field: field, companyType: company, gpa45: 3.5, toeic: 800, toeicCutoff: 700);
        expect(ReadinessService.weightsOf(t).reduce((a, b) => a + b), closeTo(1.0, 0.0001));
        final noGpa = ReadinessService.weightsOf(t, hasGpa: false);
        expect(noGpa[1], 0);
        expect(noGpa.reduce((a, b) => a + b), closeTo(1.0, 0.0001));
      }
    }
  });

  test('규칙 계산: 시연 계정은 성적·어학이 0점, 5개 항목', () {
    final r = _eval(mockDiagnosis);
    expect(r.areas.length, 5);
    expect(r.target.label, '대기업 · 데이터 분석');
    expect(r.area(ReadinessArea.grades).score, 0);
    expect(r.area(ReadinessArea.language).score, 0);
    expect(r.source, ReadinessSource.rule);
  });

  test('학점·어학을 넣으면 오르고, 대학을 안 다녔으면 성적 칸은 숨긴다', () {
    final before = _eval(mockDiagnosis).score;
    final user = mockUser.copyWith(gpa: 3.7, languages: const [LanguageScore(exam: 'TOEIC', score: '850')]);
    final after = _eval(mockDiagnosis, user: user);
    expect(after.area(ReadinessArea.grades).score, 100);
    expect(after.area(ReadinessArea.language).score, 100);
    expect(after.score, greaterThan(before));

    final highSchool = _eval(mockDiagnosis, user: mockUser.copyWith(education: '고교 졸업'));
    expect(highSchool.shownAreas.any((a) => a.area == ReadinessArea.grades), isFalse);
  });

  test('근거 점수·어학 환산·조사', () {
    expect(ReadinessService.evidenceWeight(mockRecords[1]), 1.0);
    expect(ReadinessService.evidenceWeight(mockRecords[0]), 0.6);
    expect(ReadinessService.toeicEquivalent(const LanguageScore(exam: 'TOEIC Speaking', score: 'Lv6')), 800);
    expect(ReadinessService.toeicEquivalent(const LanguageScore(exam: 'OPIc', score: 'IH')), 880);
    expect(josa('포트폴리오', '이', '가'), '포트폴리오가');
    expect(josa('어학', '이', '가'), '어학이');
  });

  test('AI 답 읽기: 점수·채우면 좋은 것·빠진 항목은 규칙 값', () {
    final rule = _eval(mockDiagnosis);
    final r = BazeReadinessJudge.parse({
      'score': 140,
      'areas': [
        {'key': 'portfolio', 'score': 75, 'gaps': ['a'], 'next_action': '기록 붙이기'},
      ],
      'fill': {'key': 'portfolio', 'title': '포트폴리오: 기록 붙이기', 'reason': '왜냐면'},
    }, rule);
    expect(r.source, ReadinessSource.ai);
    // 종합 점수는 항목 점수 × 비중 합 + 5 를 못 넘는다 (후하게 주지 않기)
    final weighted = r.areas.fold<double>(0, (s, a) => s + a.score * a.weight).round();
    expect(r.score, weighted + 5);
    expect(r.area(ReadinessArea.portfolio).score, 75);
    expect(r.area(ReadinessArea.certificate).score, rule.area(ReadinessArea.certificate).score);
    expect(r.weakest.area, ReadinessArea.portfolio);
    expect(() => BazeReadinessJudge.parse({'areas': []}, rule), throwsA(anything));
  });

  test('AI 프롬프트에 진단·기록·참고 비중이 들어간다', () {
    final state = AppState()..loginAs(UserRole.youth);
    final input = ReadinessInput(
      user: state.user,
      diagnosis: state.effectiveDiagnosis,
      records: state.records,
      acceptedTeams: const [],
      doneTeamIds: const {},
    );
    final prompt = BazeReadinessJudge.userPrompt(input, input.ruleResult());
    expect(prompt, contains('희망 직무: 데이터 분석'));
    expect(prompt, contains('청년센터 엑셀 워크숍 듣기'));
    expect(prompt, contains('참고 비중'));
  });

  test('AI 판단은 재료가 바뀔 때만 다시 부르고, 결과는 사람마다 저장된다', () async {
    final judge = _FakeJudge();
    final store = MemoryUserProfileStore();
    final state = AppState()
      ..readinessJudge = judge
      ..profileStore = store
      ..loginAs(UserRole.youth);

    expect(state.readiness.source, ReadinessSource.rule);
    await state.refreshReadiness();
    expect(state.readiness.source, ReadinessSource.ai);
    expect(state.readiness.score, 20);
    expect(state.readiness.weakest.area, ReadinessArea.language);
    await state.refreshReadiness();
    expect(judge.calls, 1); // 그대로면 다시 안 부름

    state.updateUser((u) => u.copyWith(gpa: 4.0));
    expect(state.readiness.source, ReadinessSource.rule); // 바뀌면 새 판단 전까지 규칙 값
    await state.refreshReadiness();
    expect(judge.calls, 2);

    // 로그아웃 후 다시 로그인하면 저장소에서 진단·판단을 불러옴
    state.updateDiagnosisAnswer('company_preference', '스타트업');
    await state.refreshReadiness();
    state.logout();
    expect(state.diagnosis.isEmpty, isTrue);
    state.loginAs(UserRole.youth);
    expect(state.diagnosis.companyPreference, '스타트업');
    expect(store.load(mockUser.id)?.readinessJson, isNotNull);
  });

  test('진단 없이 들어와도 기본값으로 계산·추천한다', () {
    final state = AppState()..loginAs(UserRole.youth, diagnosed: false);
    expect(state.hasDiagnosis, isFalse);
    final r = state.readiness;
    expect(r.target.companyType, isNull);
    expect(r.target.field, 'IT·데이터'); // 회원 정보 관심 분야
    expect(r.stage, UserStage.explore);
    expect(buildHomeRecommendations(state), isNotEmpty);
    state.setTargetJob('웹 개발');
    expect(state.diagnosis.targetJobName, '웹 개발');
  });

  test('처음 시작하는 사람(기록·성적 없음)은 점수가 아주 낮다', () {
    final fresh = mockUser.copyWith(education: '고등학교 졸업', major: '', languages: const []);
    final r = _eval(DiagnosisProfile.fallback(), user: fresh, records: const []);
    expect(r.score, lessThan(10));
    for (final a in r.shownAreas) {
      expect(a.score, lessThan(20));
    }
  });

  test('AI 방향 추천(분야·직무·기업 모름)을 읽는다', () {
    final rule = _eval(DiagnosisProfile.fallback());
    final r = BazeReadinessJudge.parse({
      'score': 5,
      'areas': [
        {'key': 'portfolio', 'score': 0},
      ],
      'direction': {
        'message': '한 달만 해 봐요.',
        'fields': ['디자인·영상'],
        'jobs': [
          {'name': '영상 편집 보조', 'why': '사진을 좋아해서요.'},
          {'name': '', 'why': '빈 이름은 버림'},
        ],
        'company_types': [
          {'name': '스타트업', 'why': '작게 시작하기 좋아요.'},
        ],
      },
    }, rule);
    expect(r.direction?.jobs.map((j) => j.name), ['영상 편집 보조']);
    expect(r.direction?.companyTypes.single.name, '스타트업');
    expect(r.toJson()['direction'], isNotNull);
  });

  test('AI 추천: 후보 안에서만 최대 3개, 이유는 AI 문장', () {
    final state = AppState()..loginAs(UserRole.youth);
    final candidates = allHomeCandidates(state);
    expect(candidates.length, greaterThan(3));
    final picks = BazeRecommendJudge.parse({
      'picks': [
        {'id': 'nope', 'reason': '없는 후보'},
        for (final c in candidates.take(5)) {'id': c.id, 'reason': 'AI 이유'},
      ],
    }, candidates);
    expect(picks.length, 3);
    expect(picks.first.reason, 'AI 이유');
    expect(() => BazeRecommendJudge.parse({'picks': []}, candidates), throwsA(anything));
  });

  test('진단을 건너뛴 사람은 "끌리는 것 적기"가 필요하고, 적으면 저장된다', () {
    final store = MemoryUserProfileStore();
    final state = AppState()
      ..profileStore = store
      ..loginAs(UserRole.youth, diagnosed: false);
    expect(state.needsDirection, isTrue);
    state.setLikes(['게임', ' 사진 ', '게임']);
    expect(state.likes, ['게임', '사진']);
    expect(store.load(mockUser.id)?.likes, ['게임', '사진']);
  });

  test('어학: 커트라인을 넘으면 충족 — 공기업에 OPIc IM 이면 85점', () {
    final pub = ReadinessService.targetOf(const DiagnosisProfile({'interest': '사무·행정', 'company_preference': '공기업·공공기관'}), mockUser);
    expect(pub.toeicCutoff, 700);
    final im = ReadinessService.toeicEquivalent(const LanguageScore(exam: 'OPIc', score: 'IM'));
    expect(ReadinessService.languageScore(im, pub), 85);
    expect(ReadinessService.languageScore(600, pub), lessThan(60));
    expect(ReadinessService.languageScore(null, pub), 0);
  });

  test('AI 답: 비중은 AI 가 정하고(0 이면 숨김), 성적·어학은 규칙 점수 ±10 안에서만', () {
    final user = mockUser.copyWith(languages: const [LanguageScore(exam: 'OPIc', score: 'IM')]);
    const d = DiagnosisProfile({'interest': '디자인·영상', 'company_preference': '스타트업'});
    final rule = _eval(d, user: user);
    final r = BazeReadinessJudge.parse({
      'score': 99,
      'areas': [
        {'key': 'portfolio', 'score': 10, 'weight': 60},
        {'key': 'grades', 'score': 0, 'weight': 5},
        {'key': 'language', 'score': 20, 'weight': 5},
        {'key': 'job_skill', 'score': 10, 'weight': 30},
        {'key': 'certificate', 'score': 0, 'weight': 0},
      ],
    }, rule);
    expect(r.area(ReadinessArea.portfolio).weight, closeTo(0.6, 0.001));
    expect(r.shownAreas.map((a) => a.area), isNot(contains(ReadinessArea.certificate)));
    final ruleLang = rule.area(ReadinessArea.language).score;
    expect(ruleLang, greaterThanOrEqualTo(70)); // 스타트업 커트라인 500, IM 750 → 충족
    expect(r.area(ReadinessArea.language).score, ruleLang - 10); // AI 가 20 을 줘도 규칙 -10 까지만
    final weighted = r.areas.fold<double>(0, (s, a) => s + a.score * a.weight).round();
    expect(r.score, weighted + 5);
  });

  test('자격증: 목표에 맞는 자격증 2개면 100, 공기업은 한국사도 인정', () {
    const d = DiagnosisProfile({'interest': '사무·행정', 'company_preference': '공기업·공공기관'});
    final none = _eval(d);
    expect(none.area(ReadinessArea.certificate).score, 0);
    expect(none.area(ReadinessArea.certificate).weight, greaterThan(none.area(ReadinessArea.portfolio).weight));
    final two = _eval(d,
        user: mockUser.copyWith(certificates: const [Certificate(name: '컴퓨터활용능력 1급'), Certificate(name: '한국사능력검정 1급')]));
    expect(two.area(ReadinessArea.certificate).score, 100);
    final other = _eval(d, user: mockUser.copyWith(certificates: const [Certificate(name: '운전면허 1종')]));
    expect(other.area(ReadinessArea.certificate).score, 15);
  });

  test('기업·직무를 정했다고 답했으면 이름을 안 적어도 "끌리는 것 적기" 대상이 아니다', () {
    final state = AppState()..loginAs(UserRole.youth);
    state.updateDiagnosisAnswer('interest', '사무·행정');
    state.updateDiagnosisAnswer('company_preference', '공기업·공공기관');
    state.updateDiagnosisAnswer('target_clarity', '목표 기업과 직무 모두 있어요');
    state.updateDiagnosisAnswer('target_job_name', '');
    expect(state.diagnosis.targetJobName, isNull);
    expect(state.needsDirection, isFalse);
    state.updateDiagnosisAnswer('target_clarity', '아직 찾아가는 중이에요');
    expect(state.needsDirection, isTrue);
  });

  test('시작 가이드를 닫았어도 진단에서 포트폴리오를 "있음"으로 바꾸면 다시 연다', () {
    final state = AppState()..loginAs(UserRole.youth);
    state.updateDiagnosisAnswer('readiness_assets', '아직 둘 다 없어요');
    state.skipTutorialStep('portfolio');
    state.closeTutorial();
    expect(state.tutorialClosed, isTrue);
    state.updateDiagnosisAnswer('readiness_assets', '포트폴리오와 어학 성적 모두 있어요');
    expect(state.tutorialClosed, isFalse);
    expect(state.isTutorialSkipped('portfolio'), isFalse);
  });

  test('준비도와 홈 추천 활동을 AI 한 번에 같이 받는다 (추천을 따로 안 부름)', () async {
    final recJudge = _CountingRecommendJudge();
    final state = AppState()
      ..readinessJudge = _PickingJudge()
      ..recommendJudge = recJudge
      ..loginAs(UserRole.youth);
    await state.refreshReadiness();
    await state.refreshRecommendations();
    expect(state.recommendationsFromAi, isTrue);
    expect(state.homeRecommendations.first.reason, '같이 고른 이유');
    expect(recJudge.calls, 0);
  });

  test('하루 상태 → 단계, 답을 바꾸면 안 묻는 질문은 지우고 적어 둔 직무는 살린다', () {
    expect(stageOf(const DiagnosisProfile({'current_status': '일상 리듬이 무너져 대부분 집에서 보내고 있어요.'})), UserStage.rhythm);
    final changed = mockDiagnosis.withAnswer('company_preference', '아직 고민 중이에요');
    expect(changed.answers.containsKey('target_clarity'), isFalse);
    expect(changed.targetJobName, '데이터 분석');
    expect(changed.withAnswer('interest', '아직 잘 모르겠어요').targetJobName, isNull);
  });

  test('리듬 단계: 생활 미션만 추천, 미션 3번 하면 단계 올릴지 묻는다', () {
    final state = AppState()..loginAs(UserRole.youth);
    state.updateDiagnosisAnswer('current_status', stageAnswers[UserStage.rhythm]!);
    expect(buildHomeRecommendations(state).every((r) => r.type == HomeRecommendationType.mission), isTrue);
    for (final id in ['m4', 'm5', 'm7']) {
      state.updateMission(id, (m) => m.copyWith(status: MissionStatus.done));
    }
    expect(state.suggestedNextStage, UserStage.social);
    state.moveToStage(UserStage.social);
    expect(state.stage, UserStage.social);
  });

  testWidgets('홈: 나의 역량 펼치기 → 5개 항목·채우면 좋은 것 → 자세히 보기', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 2000));
    await tester.pumpWidget(const HangeoleumApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('청년 · 진단 완료 → 홈'));
    await tester.pumpAndSettle();

    expect(find.text('나의 역량'), findsOneWidget);
    expect(find.textContaining('지금 채우면 좋은 것 ·'), findsOneWidget);
    await tester.tap(find.text('준비도'));
    await tester.pumpAndSettle();
    for (final label in ['포트폴리오', '성적', '어학', '직무 역량', '자격증']) {
      expect(find.text(label), findsWidgets);
    }
    expect(find.text('지금 채우면 좋은 것'), findsOneWidget);

    await tester.tap(find.text('자세히 보기 ›'));
    await tester.pumpAndSettle();
    expect(find.text('준비도 자세히 보기'), findsOneWidget);
    expect(find.text('가장 먼저'), findsOneWidget);
  });

  testWidgets('홈 튜토리얼 박스: 좌우로 넘기고 건너뛰고 닫는다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 2000));
    await tester.pumpWidget(const HangeoleumApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('청년 · 진단 완료 → 홈'));
    await tester.pumpAndSettle();

    expect(find.text('시작 가이드'), findsOneWidget);
    // 진단에서 "포트폴리오만 있어요" → 첫 카드가 포트폴리오 (기록이 이미 있어도)
    expect(find.text('포트폴리오를 넣어 주세요!'), findsOneWidget);
    await tester.drag(find.text('포트폴리오를 넣어 주세요!'), const Offset(-350, 0));
    await tester.pumpAndSettle();
    expect(find.text('학점 넣기'), findsOneWidget);
    await tester.drag(find.text('학점 넣기'), const Offset(-350, 0));
    await tester.pumpAndSettle();
    // 진단에서 어학 성적이 없다고 했으면 어학 카드는 안 나오고, IT 대기업 기준은 자격증도 봐서 자격증 카드
    expect(find.text('어학 성적 넣기'), findsNothing);
    expect(find.text('자격증 넣기'), findsOneWidget);
    await tester.drag(find.text('자격증 넣기'), const Offset(350, 0));
    await tester.pumpAndSettle();
    expect(find.text('학점 넣기'), findsOneWidget);

    await tester.tap(find.text('건너뛰기').first);
    await tester.pumpAndSettle();
    expect(find.text('학점 넣기'), findsNothing);

    await tester.tap(find.byTooltip('가이드 닫기'));
    await tester.pumpAndSettle();
    expect(find.text('시작 가이드'), findsNothing);
  });

  testWidgets('진단 화면: 나중에 하기 → 홈(기본값)에 진단 가이드', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 2000));
    await tester.pumpWidget(const HangeoleumApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('청년 · 진단 전 → AI 대화'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('나중에 하기'));
    await tester.pumpAndSettle();
    expect(find.text('나의 역량'), findsOneWidget);
    expect(find.text('내 기준 정하기'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5)); // 진단 화면 말풍선 타이머 정리
  });
}
