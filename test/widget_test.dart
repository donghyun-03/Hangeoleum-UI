// 기본 동작 확인 테스트: flutter test
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:hangeoleum/data/mock_data.dart';
import 'package:hangeoleum/main.dart';
import 'package:hangeoleum/models/models.dart';
import 'package:hangeoleum/router/main_tabs.dart';
import 'package:hangeoleum/screens/record/record_report_screen.dart';
import 'package:hangeoleum/state/app_state.dart';
import 'package:hangeoleum/theme/app_theme.dart';

void main() {
  _registerStepTests();
  _registerReportTests();

  testWidgets('로그인 미리보기 → 홈 → STEP 탭 이동', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    await tester.pumpWidget(const HangeoleumApp());
    await tester.pumpAndSettle();

    expect(find.text('한걸음'), findsWidgets);
    await tester.tap(find.text('청년 · 진단 완료 → 홈'));
    await tester.pumpAndSettle();
    expect(find.text('지금 나의 단계'), findsOneWidget);

    await tester.tap(find.text('STEP').last);
    await tester.pumpAndSettle();
    expect(find.text('작은 성취'), findsWidgets);
  });

  testWidgets('스크랩 탭: 지원 여부 바꾸기', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    await tester.pumpWidget(const HangeoleumApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('청년 · 진단 완료 → 홈'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('스크랩').last);
    await tester.pumpAndSettle();
    expect(find.text('활동 스크랩'), findsOneWidget);
    await tester.tap(find.text('지원했어요').last);
    await tester.pumpAndSettle();
  });
}

// ── STEP 2 · STEP 4 기능 테스트
Future<void> _enterStep(WidgetTester tester, int step) async {
  await tester.binding.setSurfaceSize(const Size(400, 2400));
  await tester.pumpWidget(const HangeoleumApp());
  await tester.pumpAndSettle();
  await tester.tap(find.text('청년 · 진단 완료 → 홈'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('STEP').last);
  await tester.pumpAndSettle();
  await tester.tap(find.byTooltip('STEP $step'));
  await tester.pumpAndSettle();
}

/// 토스트 타이머가 남지 않도록 정리
Future<void> _flush(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 3));
  await tester.pumpAndSettle();
}

void _registerStepTests() {
  test('스크랩: 지원한 공고는 스크랩을 지워도 지원현황에 남음', () {
    final s = AppState();
    bool inScrap(String id) => s.scraps.any((x) => x.opportunityId == id);
    bool inApplied(String id) => s.appliedScraps.any((x) => x.opportunityId == id);

    // o5: 지원 완료(서류 심사) → 스크랩만 지움
    s.toggleScrap('o5');
    expect(inScrap('o5'), isFalse);
    expect(inApplied('o5'), isTrue);
    // 다시 스크랩해도 지원 단계 그대로
    s.toggleScrap('o5');
    expect(inScrap('o5'), isTrue);
    expect(s.scraps.firstWhere((x) => x.opportunityId == 'o5').stage, ApplyStage.document);

    // o6: 스크랩 지운 뒤 지원까지 취소하면 완전히 사라짐
    s.toggleScrap('o6');
    s.setApplied('o6', false);
    expect(inScrap('o6'), isFalse);
    expect(inApplied('o6'), isFalse);

    // o7: 지원 안 한 스크랩은 지우면 끝
    s.toggleScrap('o7');
    expect(inScrap('o7'), isFalse);
    expect(inApplied('o7'), isFalse);
  });

  testWidgets('STEP 2: 팀 신청하면 내가 신청한 글에 보임', (tester) async {
    await _enterStep(tester, 2);
    await tester.tap(find.text('엑셀로 가계부 자동화 시트 같이 만들어요'));
    await tester.pumpAndSettle();
    expect(find.text('프로젝트 소개'), findsOneWidget);
    expect(find.text('구하는 팀원'), findsOneWidget);
    expect(find.text('팀장'), findsOneWidget);

    await tester.tap(find.text('엑셀·데이터').last);
    await tester.tap(find.text('주말'));
    await tester.enterText(find.byType(TextFormField).first, '꾸준히 참여할게요!');
    await tester.tap(find.text('신청하기'));
    await tester.pumpAndSettle();

    expect(find.text('내가 신청한 글 1'), findsOneWidget);
    expect(find.text('신청 완료 · 응답 대기'), findsOneWidget);
    await _flush(tester);
  });

  testWidgets('STEP 2: 모집 글쓰기 → 내가 쓴 글에 보임', (tester) async {
    await _enterStep(tester, 2);
    await tester.tap(find.text('글쓰기'));
    await tester.pumpAndSettle();
    expect(find.text('팀원 모집 글쓰기'), findsOneWidget);

    await tester.tap(find.text('스터디'));
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), '파이썬 기초 스터디 같이 해요');
    await tester.enterText(fields.at(2), '4주 동안 파이썬 기초 문법을 같이 공부하고 작은 프로그램을 만들어요.');
    await tester.tap(find.text('백엔드'));
    await tester.tap(find.text('모집 글 올리기'));
    await tester.pumpAndSettle();

    expect(find.text('내가 쓴 글 1'), findsOneWidget);
    expect(find.text('파이썬 기초 스터디 같이 해요'), findsOneWidget);
    await _flush(tester);
  });

  testWidgets('팀원 프로필 → 완료한 미션 · 활동 기록 자세히 보기', (tester) async {
    await _enterStep(tester, 2);
    await tester.tap(find.byTooltip('서연 프로필'));
    await tester.pumpAndSettle();
    expect(find.text('최근 활동 기록'), findsOneWidget);

    await tester.tap(find.text('완료한 미션'));
    await tester.pumpAndSettle();
    expect(find.text('서연님의 활동'), findsOneWidget);
    expect(find.text('완료한 미션 18'), findsOneWidget);

    await tester.tap(find.text('활동 기록 9'));
    await tester.pumpAndSettle();
    expect(find.text('카드를 누르면 자세한 내용을 볼 수 있어요.'), findsOneWidget);
  });

  testWidgets('STEP 3: 온통청년 정책 카드 → 프로그램 상세 → 스크랩', (tester) async {
    final first = mockOpportunities.firstWhere((o) => o.step == 3);
    await _enterStep(tester, 3);
    await tester.tap(find.text(first.title).first);
    await tester.pumpAndSettle();

    expect(find.text('프로그램 상세'), findsOneWidget);
    expect(find.text('지원 대상'), findsOneWidget);
    expect(find.text('내 조건으로 보면'), findsOneWidget);
    await tester.dragUntilVisible(find.textContaining('출처 온통청년'), find.byType(ListView), const Offset(0, -300));
    expect(find.textContaining('출처 온통청년'), findsOneWidget);

    await tester.tap(find.byTooltip('스크랩'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('스크랩 취소'), findsOneWidget);
    await _flush(tester);
  });

  testWidgets('알림: STEP 1 알림 → STEP 1 화면, 정책 알림 → 프로그램 상세', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 2400));
    await tester.pumpWidget(const HangeoleumApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('청년 · 진단 완료 → 홈'));
    await tester.pumpAndSettle();

    // 홈 오른쪽 위 종 아이콘 (tooltip '알림 N건')
    final bell = find.byWidgetPredicate((w) => w is IconButton && (w.tooltip ?? '').startsWith('알림'));
    await tester.tap(bell);
    await tester.pumpAndSettle();
    await tester.tap(find.text('오늘 해 볼 만한 STEP 1 미션이 있어요'));
    await tester.pumpAndSettle();
    expect(find.text('알림'), findsNothing);
    expect(find.textContaining('미션 '), findsWidgets); // STEP 1 미션 목록

    await tester.tap(find.text('홈').last);
    await tester.pumpAndSettle();
    await tester.tap(bell);
    await tester.pumpAndSettle();
    final policy = mockNotices.firstWhere((n) => n.group == 'new' && n.programId != null);
    await tester.tap(find.text(policy.title).first);
    await tester.pumpAndSettle();
    expect(find.text('프로그램 상세'), findsOneWidget);
  });

  testWidgets('STEP 4: 상세 데이터 없는 공고도 상세 화면이 열림', (tester) async {
    await _enterStep(tester, 4);
    await tester.tap(find.text('AI 학습용 데이터 검수 담당'));
    await tester.pumpAndSettle();
    expect(find.text('프로그램 상세'), findsOneWidget);
    expect(find.text('가온데이터'), findsOneWidget);
  });

  testWidgets('STEP 4: 지원현황 버튼 → 카드 목록', (tester) async {
    await _enterStep(tester, 4);
    expect(find.text('회사명, 직무로 검색'), findsOneWidget);
    await tester.tap(find.textContaining('지원현황'));
    await tester.pumpAndSettle();
    expect(find.text('취업 지원현황'), findsOneWidget);
    expect(find.text('데이터 입력 사원 모집'), findsOneWidget);
    expect(find.text('면접 예정'), findsOneWidget);
  });
}

// ── 경험 리포트: 폰 폭(390px)에서 요약 · AI 자기소개서 입구 · 결과지형 리포트
void _registerReportTests() {
  Future<void> pumpReport(WidgetTester tester, {AppState? state}) async {
    await tester.binding.setSurfaceSize(const Size(390, 3200));
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => state ?? AppState()),
        ChangeNotifierProvider(create: (_) => MainTabs()),
      ],
      child: MaterialApp(theme: buildAppTheme(), home: const RecordReportScreen()),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('경험 리포트: 첫 화면은 요약 → AI 자기소개서 → 강점', (tester) async {
    await pumpReport(tester);
    // 요약 카드가 맨 위, 그 아래 AI 자기소개서 입구
    final overviewTop = tester.getTopLeft(find.textContaining('님의 경험 리포트')).dy;
    final essayTop = tester.getTopLeft(find.text('AI로 자기소개서 쓰기')).dy;
    final strengthTop = tester.getTopLeft(find.textContaining('드러나요')).dy;
    expect(overviewTop, lessThan(essayTop));
    expect(essayTop, lessThan(strengthTop));
    // 예전 더미 자소서·포트폴리오는 없음
    expect(find.text('자기소개서 초안'), findsNothing);
    expect(find.textContaining('AI 연결 전 더미'), findsNothing);
    expect(find.text('포트폴리오 만들기'), findsNothing);

    await tester.tap(find.text('AI로 자기소개서 쓰기'));
    await tester.pumpAndSettle();
    expect(find.text('AI 자기소개서'), findsOneWidget);
    expect(find.text('어디에 낼 자기소개서인가요?'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('경험 리포트: 결과지형 — 강점 · 근거 기록 · 추천 직무 · 보완할 점', (tester) async {
    await pumpReport(tester);
    expect(find.textContaining('드러나요'), findsOneWidget);
    expect(find.text('역량별 근거'), findsNothing); // 역량 막대는 없앰

    // '활동 기록 2 · 보기 ›' 를 누르면 기록별 역량 창
    await tester.tap(find.text('보기 ›'));
    await tester.pumpAndSettle();
    expect(find.text('활동 기록별 역량 · 2개'), findsOneWidget);
    expect(find.text('청년센터 엑셀 워크숍 듣기'), findsOneWidget);
    expect(find.text('데이터 활용'), findsWidgets);
    expect(tester.takeException(), isNull);
    await tester.tapAt(const Offset(195, 20)); // 창 바깥 눌러 닫기
    await tester.pumpAndSettle();
    expect(find.textContaining('활동 기록별 역량'), findsNothing);
    expect(find.text('추천 직무'), findsOneWidget);
    expect(find.text('데이터 분석 보조'), findsOneWidget);
    expect(find.text('보완할 점'), findsOneWidget);

    expect(tester.takeException(), isNull);
  });

  testWidgets('경험 리포트: 기록이 많으면 창 안에서 스크롤 (폰 390×844)', (tester) async {
    final state = AppState();
    for (var i = 0; i < 8; i++) {
      state.saveRecord(ActivityRecord(
        id: 'many$i',
        step: 1,
        title: '더미 활동 $i — 제목이 길어도 줄바꿈되는지 확인하는 기록',
        date: '2026-03-${10 + i}',
        raw: '',
        star: const Star(s: '팀 모임에서 데이터 정리가 부족함', t: '엑셀로 정리', a: '매주 정리해서 발표', r: '보고 시간을 개선함'),
      ));
    }
    await pumpReport(tester, state: state);
    tester.view.physicalSize = const Size(390, 844); // 창 높이 계산(MediaQuery)도 폰 크기로
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.binding.setSurfaceSize(const Size(390, 844));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('보기 ›'), 200, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('보기 ›'));
    await tester.pumpAndSettle();
    expect(find.text('활동 기록별 역량 · 10개'), findsOneWidget);
    expect(tester.getRect(find.byType(BottomSheet)).height, lessThanOrEqualTo(844 * 0.7 + 1));

    // 목록을 끝까지 올리면 가장 오래된 기록이 보이고, 제목은 그대로 위에 있음
    final titleTop = tester.getTopLeft(find.text('활동 기록별 역량 · 10개')).dy;
    final oldest = find.text('청년센터 독서 동아리 참여');
    await tester.scrollUntilVisible(oldest, 200, scrollable: find.descendant(of: find.byKey(const ValueKey('record-skills-list')), matching: find.byType(Scrollable)));
    expect(oldest, findsOneWidget);
    expect(tester.getTopLeft(find.text('활동 기록별 역량 · 10개')).dy, titleTop);
    expect(tester.takeException(), isNull);
  });
}
