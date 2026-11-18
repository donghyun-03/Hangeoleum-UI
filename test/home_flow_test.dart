// 홈 활동 완료 → 기록 쓰기 / 시작 가이드 → 내 정보 / 직무 검색 테스트: flutter test test/home_flow_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hangeoleum/main.dart';
import 'package:hangeoleum/widgets/job_search_field.dart';

Future<void> _toHome(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(400, 2000));
  await tester.pumpWidget(const HangeoleumApp());
  await tester.pumpAndSettle();
  await tester.tap(find.text('청년 · 진단 완료 → 홈'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('홈: 활동 완료 체크 → 기록할지 묻고 → 예 → 제목에 활동 이름이 들어간 기록 쓰기', (tester) async {
    await _toHome(tester);

    await tester.tap(find.byTooltip('활동 완료').first);
    await tester.pumpAndSettle();
    expect(find.text('활동 완료!'), findsOneWidget);
    expect(find.textContaining('활동을 기록하시겠습니까?'), findsOneWidget);

    // 팝업 문장에서 활동 이름을 꺼내 둡니다: '활동 이름' 활동을 끝냈어요.
    final message = tester.widget<Text>(find.textContaining('활동을 끝냈어요')).data!;
    final title = message.substring(1, message.indexOf("' 활동을"));

    await tester.tap(find.text('예'));
    await tester.pumpAndSettle();
    expect(find.text('활동 기록하기'), findsOneWidget); // 기록 쓰기 화면
    expect(find.text('제목'), findsOneWidget);
    expect(find.text('내용'), findsOneWidget);
    expect(find.text(title), findsOneWidget); // 제목 칸에 활동 이름
  });

  testWidgets('홈: 활동 완료 팝업에서 나중에 → 기록 쓰기로 가지 않음', (tester) async {
    await _toHome(tester);
    await tester.tap(find.byTooltip('활동 완료').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('나중에'));
    await tester.pumpAndSettle();
    expect(find.text('활동 기록하기'), findsNothing);
    expect(find.text('나의 활동'), findsOneWidget);
  });

  testWidgets('시작 가이드: 학점 입력 → 내 정보 화면으로', (tester) async {
    await _toHome(tester);
    // 첫 카드(포트폴리오) 다음이 학점
    await tester.drag(find.text('포트폴리오를 넣어 주세요!'), const Offset(-350, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('학점 입력'));
    await tester.pumpAndSettle();
    expect(find.text('내 정보'), findsOneWidget);
    expect(find.text('성적'), findsOneWidget);
  });

  testWidgets('직무 검색: 글자를 치면 그 글자가 들어간 직무가 나오고 고를 수 있다', (tester) async {
    String? picked;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: JobSearchField(field: 'IT·데이터', onSelected: (j) => picked = j),
        ),
      ),
    ));
    // 비어 있으면 관심 분야(IT·데이터) 직무
    expect(find.text('백엔드 개발'), findsOneWidget);
    expect(find.text('영상 편집'), findsNothing);

    await tester.enterText(find.byType(TextField), '영상');
    await tester.pump();
    expect(find.text('영상 편집'), findsOneWidget);
    expect(find.text('백엔드 개발'), findsNothing);

    await tester.tap(find.text('영상 편집'));
    expect(picked, '영상 편집');

    // 목록에 없으면 그대로 쓰기
    await tester.enterText(find.byType(TextField), '드론 조종');
    await tester.pump();
    await tester.tap(find.text("'드론 조종' 그대로 쓰기"));
    expect(picked, '드론 조종');
  });
}
