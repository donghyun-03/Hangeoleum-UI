// 관심기업 기준치 대비 5개 영역 충족 여부 계산
//
//   final report = evaluateReadiness(criteria, SpecSnapshot.from(user, records, teamProjects: 1));
//   report.of(CriteriaArea.language).status   // AreaStatus.met / partial / unmet / notRequired / unknown
//
// 같은 입력이면 항상 같은 결과가 나오는 계산식입니다 (AI 판단 X).
// Flutter 를 import 하지 않는 순수 Dart 파일입니다.
import '../data/criteria_data.dart';
import '../data/posting_criteria_data.dart';
import '../models/criteria.dart';
import '../models/models.dart';

/// 판단에 필요한 내 정보만 모은 것
class SpecSnapshot {
  const SpecSnapshot({
    required this.education,
    required this.major,
    required this.gpa,
    required this.gpaScale,
    required this.languages,
    required this.records,
    this.teamProjects = 0,
  });

  factory SpecSnapshot.from(AppUser u, List<ActivityRecord> records, {int teamProjects = 0}) => SpecSnapshot(
        education: u.education,
        major: u.major,
        gpa: u.gpa,
        gpaScale: u.gpaScale,
        languages: u.languages,
        records: records,
        teamProjects: teamProjects,
      );

  final String education;
  final String major;
  final double? gpa;
  final double gpaScale;
  final List<LanguageScore> languages;
  final List<ActivityRecord> records;

  /// 앱 안에서 참여한 팀 프로젝트 수 (STEP 2 미니 프로젝트 등)
  final int teamProjects;
}

// ───────────────────────── 변환 도우미

/// 학력 문자열(회원가입 선택지) → 학력 단계. 모르면 null
EduLevel? eduLevelOf(String education) {
  final e = education.replaceAll(' ', '');
  if (e.isEmpty || e == '기타') return null;
  if (e.contains('석') || e.contains('박사')) return EduLevel.graduate;
  // 대졸 예정도 신입 공채 지원은 가능하므로 대졸로 봄
  if (e.contains('대졸') || (e.contains('대학') && e.contains('졸업'))) return EduLevel.univ;
  if (e.contains('전문대') || e.contains('초대졸')) return EduLevel.college;
  // 대학 재학 · 고교 졸업 · 고졸 예정 → 고졸
  if (e.contains('대학') || e.contains('고교졸업') || e.contains('고졸')) {
    return e.contains('미만') ? EduLevel.none : EduLevel.high;
  }
  return EduLevel.none; // 고교 재학 · 고졸 미만
}

/// 학점을 4.5 만점으로 환산
double? gpaOn45(double? gpa, double scale) {
  if (gpa == null || scale <= 0) return null;
  return gpa * 4.5 / scale;
}

const _opicToToeic = {'NL': 300, 'NM': 350, 'NH': 400, 'IL': 550, 'IM1': 650, 'IM2': 700, 'IM3': 750, 'IM': 700, 'IH': 850, 'AL': 950};

/// 영어 시험 점수 → TOEIC 환산 (대략). 영어 시험이 아니거나 읽을 수 없으면 null
int? englishScore(LanguageScore s) {
  final exam = s.exam.toUpperCase().replaceAll(' ', '');
  final raw = s.score.toUpperCase().replaceAll(' ', '');
  final n = int.tryParse(RegExp(r'\d+').firstMatch(raw)?.group(0) ?? '');

  if (exam == 'TOEIC') return n == null ? null : n.clamp(0, 990);
  if (exam == 'TOEICSPEAKING') {
    // 등급(Lv.6) 또는 점수(130) 둘 다 받음
    if (n == null) return null;
    final level = n <= 8 ? n : (n >= 180 ? 8 : n >= 160 ? 7 : n >= 130 ? 6 : n >= 110 ? 5 : 4);
    return const {4: 500, 5: 600, 6: 700, 7: 800, 8: 900}[level.clamp(4, 8)];
  }
  if (exam == 'OPIC') {
    for (final key in ['IM1', 'IM2', 'IM3', 'NL', 'NM', 'NH', 'IL', 'IH', 'AL', 'IM']) {
      if (raw.contains(key)) return _opicToToeic[key];
    }
    return null;
  }
  if (exam == 'TOEFL') {
    if (n == null) return null;
    // iBT 120 만점 → 대략 TOEIC (60≈650, 80≈785, 100≈900)
    return (n * 6.5 + 260).round().clamp(0, 990);
  }
  return null; // JLPT · HSK · 기타
}

String _contentOf(ActivityRecord r) =>
    '${r.title} ${r.raw} ${r.star.s} ${r.star.t} ${r.star.a} ${r.star.r}'.toLowerCase();

const _teamWords = ['팀', '협업', '동아리', '조별', '공동', '함께', '스터디'];

/// 증빙(첨부·깃허브)이 있는 기록 = 포트폴리오
int countPortfolio(SpecSnapshot s) => s.records.where((r) => r.attachments.isNotEmpty).length;

/// 직무 관련 활동 기록 수 (+ 전공이 맞으면 1)
/// [extra]: 공고에 자주 나온 기술·자격증 (크롤링 버전)
int countJobFit(SpecSnapshot s, TargetCompany t, {List<String> extra = const []}) {
  final words = {
    ...t.jobGroup.keywords,
    ...t.jobTitle.toLowerCase().split(RegExp(r'\s+')).where((w) => w.length >= 2),
    ...extra.map((w) => w.toLowerCase()).where((w) => w.length >= 2),
  };
  final records = s.records.where((r) {
    final text = _contentOf(r);
    return words.any(text.contains);
  }).length;
  return records + (majorMatches(s.major, t.jobGroup) ? 1 : 0);
}

bool majorMatches(String major, JobGroup group) => group.majorKeywords.any(major.contains);

/// 팀 활동 수 = 팀 프로젝트 + 협업 내용이 들어간 기록
int countTeamwork(SpecSnapshot s) =>
    s.teamProjects + s.records.where((r) => _teamWords.any(_contentOf(r).contains)).length;

// ───────────────────────── 영역별 판단

AreaResult _count(CriteriaArea area, int have, int need, String unit, String hint, CriteriaSource source) {
  if (need <= 0) {
    return AreaResult(area: area, status: AreaStatus.notRequired, required: '필수 아님', current: '$have$unit', source: source);
  }
  final status = have >= need
      ? AreaStatus.met
      : have > 0
          ? AreaStatus.partial
          : AreaStatus.unmet;
  return AreaResult(
    area: area,
    status: status,
    required: '$need$unit 이상',
    current: '$have$unit',
    hint: status == AreaStatus.met ? '' : hint,
    source: source,
  );
}

AreaResult _academic(CompanyCriteria c, SpecSnapshot s) {
  final src = c.sourceOf(CriteriaArea.academic);
  final needEdu = c.minEducation;
  final needGpa = c.minGpa;
  final requiredText = [
    if (needEdu != EduLevel.none) needEdu.label,
    if (needGpa != null) '학점 ${needGpa.toStringAsFixed(1)}/4.5 이상',
  ].join(' · ');

  if (needEdu == EduLevel.none && needGpa == null) {
    return AreaResult(
      area: CriteriaArea.academic,
      status: AreaStatus.notRequired,
      required: '학력·학점 안 봐요',
      current: s.education.isEmpty ? '-' : s.education,
      source: src,
    );
  }

  final edu = eduLevelOf(s.education);
  final gpa = gpaOn45(s.gpa, s.gpaScale);
  final currentText = [
    if (s.education.isNotEmpty) s.education,
    if (s.gpa != null) '학점 ${s.gpa}/${s.gpaScale}',
  ].join(' · ');

  AreaResult result(AreaStatus st, String hint) => AreaResult(
        area: CriteriaArea.academic,
        status: st,
        required: requiredText,
        current: currentText.isEmpty ? '입력 안 함' : currentText,
        hint: hint,
        source: src,
      );

  if (needEdu != EduLevel.none) {
    if (edu == null) return result(AreaStatus.unknown, '내 정보에서 학력을 입력해 주세요.');
    if (edu.rank < needEdu.rank) return result(AreaStatus.unmet, '학력 기준이 낮은 기업이나 고졸·초대졸 채용을 함께 찾아봐요.');
  }
  if (needGpa != null) {
    if (gpa == null) return result(AreaStatus.unknown, '내 정보에서 학점을 입력해 주세요.');
    if (gpa + 1e-9 < needGpa - 0.3) return result(AreaStatus.unmet, '학점 대신 직무 경험·자격증으로 보완해 봐요.');
    if (gpa + 1e-9 < needGpa) return result(AreaStatus.partial, '조금만 더! 남은 학기 학점 관리나 자격증으로 보완해 봐요.');
  }
  return result(AreaStatus.met, '');
}

AreaResult _language(CompanyCriteria c, SpecSnapshot s) {
  final src = c.sourceOf(CriteriaArea.language);
  final need = c.minEnglish;
  final scores = [for (final l in s.languages) (l, englishScore(l))];
  final best = scores.where((e) => e.$2 != null).fold<(LanguageScore, int?)?>(
        null,
        (a, e) => a == null || e.$2! > a.$2! ? e : a,
      );
  final currentText = s.languages.isEmpty
      ? '입력 안 함'
      : s.languages.map((l) => '${l.exam} ${l.score}').join(', ');

  if (need == null) {
    return AreaResult(area: CriteriaArea.language, status: AreaStatus.notRequired, required: '필수 아님', current: currentText, source: src);
  }
  final requiredText = 'TOEIC $need 이상 (환산)';
  if (s.languages.isEmpty) {
    return AreaResult(
      area: CriteriaArea.language,
      status: AreaStatus.unknown,
      required: requiredText,
      current: currentText,
      hint: '어학 성적이 있으면 내 정보에 입력해 주세요.',
      source: src,
    );
  }
  final have = best?.$2;
  final status = have == null
      ? AreaStatus.unmet
      : have >= need
          ? AreaStatus.met
          : have >= need - 100
              ? AreaStatus.partial
              : AreaStatus.unmet;
  return AreaResult(
    area: CriteriaArea.language,
    status: status,
    required: requiredText,
    current: currentText,
    hint: switch (status) {
      AreaStatus.met => '',
      AreaStatus.partial => '조금만 더! 다음 정기 시험 일정을 확인해 봐요.',
      _ => have == null ? '영어 성적이 필요해요. 토익·오픽 중 하나를 준비해 봐요.' : '목표 점수까지 영어 시험을 준비해 봐요.',
    },
    source: src,
  );
}

/// 관심기업 기준 대비 5개 영역 결과
ReadinessReport evaluateReadiness(CompanyCriteria c, SpecSnapshot s) {
  final t = c.target;
  return ReadinessReport(criteria: c, results: [
    _count(
      CriteriaArea.portfolio,
      countPortfolio(s),
      c.minPortfolio,
      '개',
      '활동 기록에 결과물(파일·깃허브)을 첨부해 포트폴리오로 남겨 봐요.',
      c.sourceOf(CriteriaArea.portfolio),
    ),
    _academic(c, s),
    _count(
      CriteriaArea.jobFit,
      countJobFit(s, t, extra: c.extraKeywords),
      c.minJobFit,
      '개',
      '${t.jobLabel} 관련 교육·공모전·프로젝트를 하나 해 봐요.',
      c.sourceOf(CriteriaArea.jobFit),
    ),
    _language(c, s),
    _count(
      CriteriaArea.teamwork,
      countTeamwork(s),
      c.minTeamwork,
      '회',
      'STEP 2 미니 프로젝트나 동아리로 팀 경험을 쌓아 봐요.',
      c.sourceOf(CriteriaArea.teamwork),
    ),
  ]);
}

// ───────────────────────── 공고 기준 합치기 (크롤링 버전)

/// 관심기업에 맞는 공고 기준 찾기. 기업 이름이 같고 직무 묶음이 같은 것 중
/// 직무 이름까지 겹치는 것을 먼저 고릅니다. 없으면 null (→ 러프 기준만 사용)
PostingCriteria? findPostingCriteria(TargetCompany t, List<PostingCriteria> list) {
  if (t.name.trim().isEmpty) return null;
  final same = list.where((p) => p.matchesCompany(t.name) && p.jobGroup == t.jobGroup).toList();
  if (same.isEmpty) return null;
  final title = t.jobTitle.replaceAll(' ', '');
  for (final p in same) {
    final job = p.job.replaceAll(' ', '');
    if (title.isNotEmpty && job.isNotEmpty && (title.contains(job) || job.contains(title))) return p;
  }
  return same.first;
}

/// 관심기업 기준치 = 러프 기준 + (있으면) 채용 공고 기준
///
/// - 성적·학력: 공고의 학력. 본문을 읽은 공고가 있으면 학점도 공고 값 (적힌 게 없으면 학점 안 봄)
/// - 어학: 본문을 읽은 공고가 있으면 공고 값 (적힌 게 없거나 우대뿐이면 필수 아님)
/// - 포트폴리오·협업: 공고 절반 이상이 언급하면 2개, 20% 이상이면 1개 이상으로 올림 (내리지는 않음)
/// - 직무연관성: 개수는 러프 기준 그대로, 공고에 자주 나온 기술·자격증을 판단 단어에 더함
CompanyCriteria resolveCriteria(TargetCompany t, {List<PostingCriteria> postings = kPostingCriteria}) {
  final rough = roughCriteriaFor(t);
  final p = findPostingCriteria(t, postings);
  if (p == null) return rough;

  final src = <CriteriaArea, CriteriaSource>{};
  var c = rough;

  if (p.education != null) {
    c = c.copyWith(minEducation: p.education);
    src[CriteriaArea.academic] = CriteriaSource.posting;
  }
  if (p.hasDetail) {
    c = p.minGpa == null ? c.copyWith(clearGpa: true) : c.copyWith(minGpa: p.minGpa);
    c = p.minEnglish == null ? c.copyWith(clearEnglish: true) : c.copyWith(minEnglish: p.minEnglish);
    src[CriteriaArea.academic] = CriteriaSource.posting;
    src[CriteriaArea.language] = CriteriaSource.posting;

    int raise(int base, double rate) => rate >= 0.5
        ? (base < 2 ? 2 : base)
        : rate >= 0.2
            ? (base < 1 ? 1 : base)
            : base;
    final portfolio = raise(c.minPortfolio, p.portfolioRate);
    final teamwork = raise(c.minTeamwork, p.teamworkRate);
    if (p.portfolioRate >= 0.2) src[CriteriaArea.portfolio] = CriteriaSource.posting;
    if (p.teamworkRate >= 0.2) src[CriteriaArea.teamwork] = CriteriaSource.posting;
    c = c.copyWith(minPortfolio: portfolio, minTeamwork: teamwork);
  }

  final extra = [...p.skills, ...p.certificates];
  if (extra.isNotEmpty) src[CriteriaArea.jobFit] = CriteriaSource.posting;

  final english = p.hasDetail && p.minEnglish == null && p.englishPreferred ? ' 어학은 필수는 아니고 우대로 적혀 있어요.' : '';
  final detail = p.hasDetail ? '' : ' 공고 본문이 이미지라 학력만 공고에서 가져왔어요.';
  return c.copyWith(
    sources: src,
    extraKeywords: extra,
    posting: p,
    note: '${p.label} 기준이에요.$detail$english 표시가 없는 영역은 기본 기준이에요.',
  );
}
