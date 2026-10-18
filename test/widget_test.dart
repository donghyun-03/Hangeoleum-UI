// 기본 동작 확인 테스트: flutter test
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hangeoleum/main.dart';

void main() {
  _registerStepTests();

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
