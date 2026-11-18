// 직무 목록 검색 · 고교 학력 판단 테스트
import 'package:flutter_test/flutter_test.dart';
import 'package:hangeoleum/data/job_catalog.dart';
import 'package:hangeoleum/services/readiness_service.dart';

void main() {
  test('글자가 들어간 직무가 나옴 (다른 이름 포함, 띄어쓰기·대소문자 무시)', () {
    expect(searchJobs('데이터').map((j) => j.name).contains('데이터 분석'), isTrue);
    expect(searchJobs('서버').map((j) => j.name).contains('백엔드 개발'), isTrue); // 다른 이름으로도 찾음
    expect(searchJobs('figma').map((j) => j.name).contains('UI·UX 디자인'), isTrue);
    expect(searchJobs('영상편집').map((j) => j.name).contains('영상 편집'), isTrue);
    expect(searchJobs('없는직무xyz'), isEmpty);
  });

  test('관심 분야 직무가 먼저 나옴', () {
    final hits = searchJobs('기획', field: '사무·행정');
    expect(hits, isNotEmpty);
    final firstOther = hits.indexWhere((j) => j.field != '사무·행정');
    final lastMine = hits.lastIndexWhere((j) => j.field == '사무·행정');
    if (firstOther != -1 && lastMine != -1) expect(lastMine < firstOther, isTrue);
  });

  test('직무 이름이 겹치지 않음', () {
    final names = kJobCatalog.map((j) => j.name).toList();
    expect(names.toSet().length, names.length);
  });

  test('고교 재학·고졸이면 내신, 대학이면 학점', () {
    expect(ReadinessService.isHighSchool('고교 졸업'), isTrue);
    expect(ReadinessService.isHighSchool('고교 재학'), isTrue);
    expect(ReadinessService.isHighSchool('고졸 예정'), isTrue);
    expect(ReadinessService.isHighSchool('고졸 미만'), isFalse);
    expect(ReadinessService.isHighSchool('대학 졸업'), isFalse);
    expect(ReadinessService.isHighSchool('대학 재학'), isFalse);
  });
}
