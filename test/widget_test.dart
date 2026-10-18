// 기본 동작 확인 테스트: flutter test
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hangeoleum/main.dart';

void main() {
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
    expect(find.text('공고 스크랩'), findsOneWidget);
    await tester.tap(find.text('지원했어요').last);
    await tester.pumpAndSettle();
  });
}
