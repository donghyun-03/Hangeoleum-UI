// 기본 동작 확인 테스트: flutter test
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

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

// ── 경험 리포트: 폰 폭(390px)에서 자기소개서 초안 · 결과지형 리포트
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

  /// '482/500자' 에서 앞 숫자
  int countOf(WidgetTester tester, int limit) {
    final t = tester.widget<Text>(find.textContaining('/$limit자')).data!;
    return int.parse(t.split('/').first);
  }

  /// 쓰기 버튼 누르고 '작성 중…' 이 끝날 때까지
  Future<void> write(WidgetTester tester, String label) async {
    await tester.tap(find.text(label));
    await tester.pump();
    expect(find.text('작성 중…'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
  }

  testWidgets('경험 리포트: 조건을 고르고 쓰기를 눌러야 한 번 써짐', (tester) async {
    await pumpReport(tester);
    expect(find.text('자기소개서 초안'), findsOneWidget);
    for (final q in ['직무 역량', '협업 경험', '문제 해결']) {
      expect(find.text(q), findsWidgets); // '문제 해결' 은 역량 막대에도 있음
    }
    expect(find.text('포트폴리오로 내보내기 (준비 중)'), findsNothing);

    // 처음엔 안내만, 칩을 눌러도 글은 안 써짐
    expect(find.text('문항과 글자 수를 고르고 쓰기를 눌러 주세요'), findsOneWidget);
    await tester.tap(find.text('300자'));
    await tester.pumpAndSettle();
    expect(find.textContaining('['), findsNothing);

    await write(tester, '자기소개서 쓰기');
    final c300 = countOf(tester, 300);
    expect(c300, lessThanOrEqualTo(300));
    final title300 = tester.widget<Text>(find.textContaining('[')).data;
    expect(find.text('다시 쓰기'), findsOneWidget);

    // 칩을 바꾸면 글은 그대로, 버튼만 '이 조건으로 다시 쓰기'
    await tester.tap(find.text('500자'));
    await tester.tap(find.text('협업 경험'));
    await tester.pumpAndSettle();
    expect(countOf(tester, 300), c300);
    expect(tester.widget<Text>(find.textContaining('[')).data, title300);
    expect(find.text('이 조건으로 다시 쓰기'), findsOneWidget);

    await write(tester, '이 조건으로 다시 쓰기');
    final c500 = countOf(tester, 500);
    expect(c500, lessThanOrEqualTo(500));
    expect(c500, greaterThan(c300));
    expect(tester.widget<Text>(find.textContaining('[')).data, isNot(title300));
    expect(find.text('면접 예상 질문'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('경험 리포트: 결과지형 — 강점 · 근거 기록 · 추천 직무 · 보완할 점', (tester) async {
    await pumpReport(tester);
    expect(find.text('결과지형 리포트'), findsOneWidget);
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

    await write(tester, '자기소개서 쓰기');
    await tester.tap(find.text('전체 복사'));
    await tester.pump();
    expect(find.text('자기소개서 초안을 복사했어요'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
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
