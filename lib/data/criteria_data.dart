// 러프 기준치 표 — 기업 유형 × 직무 묶음
//
// ⚠ 실제 채용 공고에서 가져온 값이 아니라, 팀이 정한 "대략적인 기준"입니다.
//   채용 공고를 자동으로 가져오는 것은 저작권(데이터베이스권)·약관 문제가 있어서
//   우선 이 표로 기준을 잡고, 숫자는 팀 회의에서 고쳐 쓰면 됩니다.
//
// 기준 잡은 방식
//   1) 기업 유형별 기본값 (_base)
//   2) 직무 묶음별 보정 (_adjust) — 예: 디자인은 포트폴리오 +2, 사무는 어학 +50
//   3) 범위 제한 (개수 0~3, 영어 550~900)
//
// 숫자의 뜻
//   학점   : 4.5 만점 환산. null 이면 학점을 보지 않음
//   영어   : TOEIC 환산 점수. null 이면 어학을 보지 않음 (TOEIC Speaking·OPIc·TOEFL 은 대략 환산)
//   포트폴리오 / 직무연관성 / 협업경험 : 필요한 개수 (0 이면 필수 아님)
import '../models/criteria.dart';

class _Row {
  const _Row(this.edu, this.gpa, this.eng, this.portfolio, this.jobFit, this.teamwork);
  final EduLevel edu;
  final double? gpa;
  final int? eng;
  final int portfolio;
  final int jobFit;
  final int teamwork;
}

/// 기업 유형별 기본값
const _base = <CompanyTier, _Row>{
  //                          학력           학점  영어  포폴 직무 협업
  CompanyTier.large: _Row(EduLevel.univ, 3.5, 750, 1, 2, 2),
  // 공기업은 블라인드 채용이라 학력·학점을 보지 않고, 어학 기준점과 직무(NCS·자격증)를 봄
  CompanyTier.public: _Row(EduLevel.none, null, 700, 0, 1, 1),
  CompanyTier.mid: _Row(EduLevel.univ, 3.0, 650, 1, 1, 1),
  CompanyTier.small: _Row(EduLevel.high, null, null, 1, 1, 1),
  // 스타트업은 학력보다 결과물과 바로 쓸 수 있는 실력을 봄
  CompanyTier.startup: _Row(EduLevel.none, null, null, 2, 2, 1),
};

/// 직무 묶음별 보정값 (더하기). 직무연관성 개수는 유형별 기본값을 그대로 씀
class _Adjust {
  const _Adjust({this.gpa = 0, this.eng = 0, this.portfolio = 0, this.teamwork = 0});
  final double gpa;
  final int eng;
  final int portfolio;
  final int teamwork;
}

const _adjust = <JobGroup, _Adjust>{
  JobGroup.dev: _Adjust(eng: -50, portfolio: 1),
  JobGroup.data: _Adjust(portfolio: 1),
  JobGroup.design: _Adjust(gpa: -0.5, eng: -100, portfolio: 2),
  JobGroup.office: _Adjust(eng: 50, portfolio: -1),
  JobGroup.marketing: _Adjust(teamwork: 1),
};

/// 기업 유형별 설명 (기준 화면 아래 안내)
const kTierNotes = <CompanyTier, String>{
  CompanyTier.large: '대기업 공채는 4년제 학력·학점·어학을 서류에서 보고, 직무 경험과 팀 경험을 면접에서 확인하는 편이에요.',
  CompanyTier.public: '공기업·공공기관은 블라인드 채용이라 학력·학점은 보지 않아요. 어학 기준점과 직무 관련 자격증·교육이 중요해요.',
  CompanyTier.mid: '중견기업은 대기업보다 기준이 조금 낮고, 직무 경험을 함께 봐요.',
  CompanyTier.small: '중소기업은 학력·어학보다 바로 일할 수 있는 경험을 봐요.',
  CompanyTier.startup: '스타트업은 학력보다 직접 만든 결과물(포트폴리오)과 직무 실력을 가장 많이 봐요.',
};

int _clampCount(int v) => v.clamp(0, 3);

/// 관심기업의 러프 기준치
CompanyCriteria roughCriteriaFor(TargetCompany target) {
  final b = _base[target.tier]!;
  final a = _adjust[target.jobGroup]!;

  final gpa = b.gpa == null ? null : double.parse((b.gpa! + a.gpa).clamp(2.5, 4.0).toStringAsFixed(1));
  final eng = b.eng == null ? null : (b.eng! + a.eng).clamp(550, 900);

  return CompanyCriteria(
    target: target,
    minEducation: b.edu,
    minGpa: gpa,
    minEnglish: eng,
    minPortfolio: _clampCount(b.portfolio + a.portfolio),
    minJobFit: _clampCount(b.jobFit),
    minTeamwork: _clampCount(b.teamwork + a.teamwork),
    note: '${kTierNotes[target.tier]!} 실제 공고가 아니라 기업 유형·직무로 잡은 대략적인 기준이에요.',
  );
}

/// 관심기업 이름 추천 (입력 칸 아래 칩). 이름을 고르면 기업 유형도 같이 채워집니다.
/// TODO(API): 기업 DB 가 연결되면 검색 결과로 교체
const kSampleCompanies = <(String, CompanyTier)>[
  ('삼성전자', CompanyTier.large),
  ('네이버', CompanyTier.large),
  ('카카오', CompanyTier.large),
  ('LG전자', CompanyTier.large),
  ('현대자동차', CompanyTier.large),
  ('한국전력공사', CompanyTier.public),
  ('국민건강보험공단', CompanyTier.public),
  ('한국토지주택공사', CompanyTier.public),
];
