// 관심기업 기준치(러프 기준) · 5개 영역 충족 판단 테스트
import 'package:flutter_test/flutter_test.dart';
import 'package:hangeoleum/data/criteria_data.dart';
import 'package:hangeoleum/models/criteria.dart';
import 'package:hangeoleum/models/models.dart';
import 'package:hangeoleum/services/criteria_service.dart';

ActivityRecord _rec(String id, String title, {String a = '', bool attached = false}) => ActivityRecord(
      id: id,
      step: 1,
      title: title,
      date: '2026-11-01',
      raw: '',
      star: Star(s: '', t: '', a: a, r: ''),
      attachments: attached
          ? const [Attachment(id: 'f', type: AttachmentType.github, name: 'repo', uri: 'https://github.com/x/y')]
          : const [],
    );

SpecSnapshot _spec({
  String education = '대학 졸업',
  String major = '컴퓨터공학과',
  double? gpa,
  double scale = 4.5,
  List<LanguageScore> languages = const [],
  List<ActivityRecord> records = const [],
  int teamProjects = 0,
}) =>
    SpecSnapshot(
      education: education,
      major: major,
      gpa: gpa,
      gpaScale: scale,
      languages: languages,
      records: records,
      teamProjects: teamProjects,
    );

const _naverDev = TargetCompany(name: '네이버', tier: CompanyTier.large, jobGroup: JobGroup.dev, jobTitle: '백엔드 개발');

void main() {
  group('러프 기준표', () {
    test('대기업 개발: 대졸 · 학점 3.5 · 영어 700 · 포폴 2 · 직무 2 · 협업 2', () {
      final c = roughCriteriaFor(_naverDev);
      expect(c.minEducation, EduLevel.univ);
      expect(c.minGpa, 3.5);
      expect(c.minEnglish, 700);
      expect(c.minPortfolio, 2);
      expect(c.minJobFit, 2);
      expect(c.minTeamwork, 2);
    });

    test('공기업은 학력·학점을 보지 않음 (블라인드)', () {
      final c = roughCriteriaFor(const TargetCompany(name: '', tier: CompanyTier.public, jobGroup: JobGroup.office));
      expect(c.minEducation, EduLevel.none);
      expect(c.minGpa, isNull);
      expect(c.minEnglish, 750);
      expect(c.minPortfolio, 0);
    });

    test('모든 조합이 범위 안에 있음', () {
      for (final tier in CompanyTier.values) {
        for (final g in JobGroup.values) {
          final c = roughCriteriaFor(TargetCompany(name: '', tier: tier, jobGroup: g));
          for (final n in [c.minPortfolio, c.minJobFit, c.minTeamwork]) {
            expect(n >= 0 && n <= 3, isTrue);
          }
          if (c.minEnglish != null) expect(c.minEnglish! >= 550 && c.minEnglish! <= 900, isTrue);
          if (c.minGpa != null) expect(c.minGpa! >= 2.5 && c.minGpa! <= 4.0, isTrue);
          expect(c.note.isNotEmpty, isTrue);
        }
      }
    });
  });

  group('변환 도우미', () {
    test('학력 문자열 → 단계', () {
      expect(eduLevelOf('대학 졸업'), EduLevel.univ);
      expect(eduLevelOf('대학교 졸업'), EduLevel.univ);
      expect(eduLevelOf('대졸 예정'), EduLevel.univ);
      expect(eduLevelOf('대학 재학'), EduLevel.high);
      expect(eduLevelOf('고교 졸업'), EduLevel.high);
      expect(eduLevelOf('고졸 미만'), EduLevel.none);
      expect(eduLevelOf('석·박사'), EduLevel.graduate);
      expect(eduLevelOf('기타'), isNull);
    });

    test('영어 점수 환산', () {
      expect(englishScore(const LanguageScore(exam: 'TOEIC', score: '850')), 850);
      expect(englishScore(const LanguageScore(exam: 'OPIc', score: 'IM2')), 700);
      expect(englishScore(const LanguageScore(exam: 'OPIc', score: 'IH')), 850);
      expect(englishScore(const LanguageScore(exam: 'TOEIC Speaking', score: 'Lv.6')), 700);
      expect(englishScore(const LanguageScore(exam: 'TOEFL', score: '80')), 780);
      expect(englishScore(const LanguageScore(exam: 'JLPT', score: 'N2')), isNull);
    });

    test('학점 4.5 환산', () {
      expect(gpaOn45(4.0, 4.5), 4.0);
      expect(gpaOn45(3.6, 4.0), closeTo(4.05, 0.001));
      expect(gpaOn45(null, 4.5), isNull);
    });
  });

  group('5개 영역 판단', () {
    final c = roughCriteriaFor(_naverDev);

    test('아무것도 입력하지 않으면 학점·어학은 입력 필요', () {
      final r = evaluateReadiness(c, _spec(major: '경영학부'));
      expect(r.of(CriteriaArea.academic).status, AreaStatus.unknown);
      expect(r.of(CriteriaArea.language).status, AreaStatus.unknown);
      expect(r.of(CriteriaArea.portfolio).status, AreaStatus.unmet);
      expect(r.of(CriteriaArea.jobFit).status, AreaStatus.unmet);
      expect(r.of(CriteriaArea.teamwork).status, AreaStatus.unmet);
      expect(r.okCount, 0);
      expect(r.gaps.length, 5);
    });

    test('기준을 모두 넘으면 전부 충족', () {
      final r = evaluateReadiness(
        c,
        _spec(
          gpa: 3.8,
          languages: const [LanguageScore(exam: 'TOEIC', score: '780')],
          records: [
            _rec('1', 'Flutter 앱 개발 팀 프로젝트', attached: true),
            _rec('2', '알고리즘 스터디', a: '백엔드 서버 구현', attached: true),
          ],
          teamProjects: 1,
        ),
      );
      for (final x in r.results) {
        expect(x.status, AreaStatus.met, reason: x.area.label);
      }
      expect(r.allOk, isTrue);
    });

    test('조금 모자라면 조금 부족', () {
      final r = evaluateReadiness(
        c,
        _spec(
          gpa: 3.3,
          languages: const [LanguageScore(exam: 'OPIc', score: 'IL')],
          records: [_rec('1', '웹 개발 강의', attached: true)],
        ),
      );
      expect(r.of(CriteriaArea.academic).status, AreaStatus.partial);
      expect(r.of(CriteriaArea.language).status, AreaStatus.unmet); // IL ≈ 550 < 700-100
      expect(r.of(CriteriaArea.portfolio).status, AreaStatus.partial); // 1/2
      expect(r.of(CriteriaArea.jobFit).status, AreaStatus.met); // 기록 1 + 전공 1
    });

    test('학력 미달이면 학점과 상관없이 부족', () {
      final r = evaluateReadiness(c, _spec(education: '고교 졸업', gpa: 4.3));
      expect(r.of(CriteriaArea.academic).status, AreaStatus.unmet);
    });

    test('스타트업은 학력·어학 필수 아님', () {
      final s = roughCriteriaFor(const TargetCompany(name: '', tier: CompanyTier.startup, jobGroup: JobGroup.design));
      final r = evaluateReadiness(s, _spec(education: '고교 졸업'));
      expect(r.of(CriteriaArea.academic).status, AreaStatus.notRequired);
      expect(r.of(CriteriaArea.language).status, AreaStatus.notRequired);
      expect(r.of(CriteriaArea.portfolio).status, AreaStatus.unmet); // 디자인은 포트폴리오가 핵심
    });
  });

  group('채용 공고 기준 합치기 (크롤링 버전)', () {
    const naverPosting = PostingCriteria(
      company: '네이버',
      job: '백엔드',
      jobGroup: JobGroup.dev,
      source: '사람인',
      fetchedAt: '2026-11-17',
      postingCount: 6,
      detailCount: 4,
      education: EduLevel.univ,
      minGpa: 3.0,
      portfolioRate: 0.5,
      teamworkRate: 0.1,
      skills: ['Spring', 'Kotlin'],
      certificates: ['정보처리기사'],
    );

    test('공고 기준이 없으면 러프 기준 그대로', () {
      final c = resolveCriteria(_naverDev, postings: const []);
      expect(c.posting, isNull);
      expect(c.minGpa, 3.5);
      expect(c.sourceOf(CriteriaArea.academic), CriteriaSource.rough);
    });

    test('이름은 괄호·띄어쓰기를 무시하고 맞춤', () {
      expect(naverPosting.matchesCompany('네이버(주)'), isTrue);
      expect(naverPosting.matchesCompany('카카오'), false);
    });

    test('공고 값으로 학점·어학·포트폴리오를 바꿈', () {
      final c = resolveCriteria(_naverDev, postings: const [naverPosting]);
      expect(c.posting?.company, '네이버');
      expect(c.minGpa, 3.0); // 공고 값
      expect(c.minEnglish, isNull); // 본문을 읽은 공고에 어학이 없음 → 필수 아님
      expect(c.minPortfolio, 2); // 절반이 포트폴리오 언급 → 2 (러프 2 유지)
      expect(c.minTeamwork, 2); // 언급 적음 → 러프 그대로
      expect(c.sourceOf(CriteriaArea.academic), CriteriaSource.posting);
      expect(c.sourceOf(CriteriaArea.language), CriteriaSource.posting);
      expect(c.sourceOf(CriteriaArea.teamwork), CriteriaSource.rough);
      expect(c.sourceOf(CriteriaArea.jobFit), CriteriaSource.posting);
    });

    test('본문이 이미지뿐이면 학력만 공고에서 가져옴', () {
      const imageOnly = PostingCriteria(
        company: '네이버',
        job: '',
        jobGroup: JobGroup.dev,
        source: '사람인',
        fetchedAt: '2026-11-17',
        postingCount: 3,
        education: EduLevel.high,
      );
      final c = resolveCriteria(_naverDev, postings: const [imageOnly]);
      expect(c.minEducation, EduLevel.high);
      expect(c.minGpa, 3.5); // 러프 그대로
      expect(c.minEnglish, 700);
      expect(c.sourceOf(CriteriaArea.language), CriteriaSource.rough);
    });

    test('다른 직무 묶음 공고는 쓰지 않음', () {
      const design = TargetCompany(name: '네이버', tier: CompanyTier.large, jobGroup: JobGroup.design);
      expect(resolveCriteria(design, postings: const [naverPosting]).posting, isNull);
    });

    test('공고 기술 키워드로 직무연관성을 판단', () {
      final c = resolveCriteria(_naverDev, postings: const [naverPosting]);
      final s = _spec(major: '경영학부', records: [_rec('1', 'Kotlin 공부 기록')]);
      expect(countJobFit(s, c.target, extra: c.extraKeywords), 1);
      expect(countJobFit(s, c.target), 0);
    });
  });
}
