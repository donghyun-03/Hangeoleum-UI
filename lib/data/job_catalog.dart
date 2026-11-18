// 직무 목록 — 진단 채팅 '해보고 싶은 직무는 뭐예요?' 와 내 기준 바꾸기에서 검색해서 고릅니다.
// field 는 진단의 관심 분야(IT·데이터 / 디자인·영상 / 사무·행정)와 같은 이름이에요. 그 외 분야는 '기타'.
// keywords 는 검색할 때 같이 보는 다른 이름이에요. (예: '서버' 를 쳐도 백엔드 개발이 나옴)
// 직무를 더 넣으려면 아래 목록에 한 줄만 추가하면 돼요.
// TODO(API): 직무 DB(직무 테이블)가 연결되면 서버 목록으로 교체

class JobItem {
  const JobItem(this.name, this.field, [this.keywords = const []]);
  final String name;
  final String field;
  final List<String> keywords;

  /// 검색어가 이름이나 다른 이름에 들어 있는지 (띄어쓰기·대소문자 무시)
  bool matches(String query) {
    final q = _norm(query);
    if (q.isEmpty) return true;
    return _norm(name).contains(q) || keywords.any((k) => _norm(k).contains(q));
  }

  static String _norm(String v) => v.replaceAll(' ', '').toLowerCase();
}

const kJobCatalog = <JobItem>[
  // ── IT·데이터
  JobItem('백엔드 개발', 'IT·데이터', ['서버', '개발자', 'Java', 'Spring', 'Node', 'API']),
  JobItem('프론트엔드 개발', 'IT·데이터', ['웹', '개발자', 'React', 'JavaScript', '퍼블리셔']),
  JobItem('앱 개발', 'IT·데이터', ['모바일', '안드로이드', 'iOS', 'Flutter', '개발자']),
  JobItem('웹 퍼블리싱', 'IT·데이터', ['HTML', 'CSS', '퍼블리셔', '웹']),
  JobItem('게임 개발', 'IT·데이터', ['Unity', '유니티', '언리얼', '개발자']),
  JobItem('데이터 분석', 'IT·데이터', ['데이터', '분석가', 'SQL', '엑셀', '통계', 'BI']),
  JobItem('데이터 엔지니어', 'IT·데이터', ['데이터', '파이프라인', 'ETL', 'SQL']),
  JobItem('AI·머신러닝 엔지니어', 'IT·데이터', ['인공지능', 'AI', '머신러닝', '딥러닝', 'LLM', 'Python']),
  JobItem('정보보안', 'IT·데이터', ['보안', '해킹', '네트워크', '관제']),
  JobItem('클라우드·인프라 엔지니어', 'IT·데이터', ['서버', '네트워크', 'AWS', 'DevOps', '시스템']),
  JobItem('IT 지원·헬프데스크', 'IT·데이터', ['전산', 'PC', '유지보수', '헬프데스크']),
  JobItem('QA·테스터', 'IT·데이터', ['테스트', '품질', 'QA']),
  JobItem('서비스 기획(PM)', 'IT·데이터', ['기획', 'PM', 'PO', '프로덕트']),

  // ── 디자인·영상
  JobItem('UI·UX 디자인', '디자인·영상', ['앱 디자인', '웹 디자인', '피그마', 'Figma', '프로덕트 디자인']),
  JobItem('웹 디자인', '디자인·영상', ['홈페이지', '배너', '상세페이지']),
  JobItem('그래픽 디자인', '디자인·영상', ['편집 디자인', '포토샵', '일러스트', '인쇄']),
  JobItem('브랜드 디자인', '디자인·영상', ['로고', 'BI', 'CI', '브랜딩']),
  JobItem('영상 편집', '디자인·영상', ['유튜브', '프리미어', '편집자', '콘텐츠']),
  JobItem('모션그래픽', '디자인·영상', ['애프터이펙트', '모션', '애니메이션']),
  JobItem('영상 촬영·PD', '디자인·영상', ['촬영', 'PD', '연출', '방송']),
  JobItem('일러스트·웹툰', '디자인·영상', ['그림', '웹툰', '캐릭터', '일러스트레이터']),
  JobItem('3D 모델링', '디자인·영상', ['블렌더', '3D', '모델러', '게임 그래픽']),
  JobItem('사진 촬영', '디자인·영상', ['사진', '포토그래퍼', '스튜디오']),

  // ── 사무·행정
  JobItem('일반 사무', '사무·행정', ['사무직', '사무 보조', '문서', '엑셀']),
  JobItem('경영지원·총무', '사무·행정', ['총무', '경영지원', '구매', '자산관리']),
  JobItem('회계·재무', '사무·행정', ['경리', '회계', '세무', '재무', '전산회계']),
  JobItem('인사·HR', '사무·행정', ['인사', '채용', '교육', '노무', 'HR']),
  JobItem('공공기관 행정', '사무·행정', ['공무원', '공공', '행정', '기록물']),
  JobItem('고객 상담(CS)', '사무·행정', ['상담', '콜센터', 'CS', '민원']),
  JobItem('영업 관리', '사무·행정', ['영업', '영업지원', '거래처']),
  JobItem('물류·구매 관리', '사무·행정', ['물류', '재고', '구매', '유통']),
  JobItem('비서·안내', '사무·행정', ['비서', '리셉션', '안내']),
  JobItem('마케팅', '사무·행정', ['마케터', '광고', 'SNS', '홍보', '콘텐츠 마케팅']),

  // ── 기타 (관심 분야를 정하지 않은 사람도 고를 수 있게)
  JobItem('생산·제조', '기타', ['공장', '생산직', '제조', '품질']),
  JobItem('기계·전기 기술', '기타', ['기계', '전기', '설비', '정비']),
  JobItem('요리·조리', '기타', ['조리', '주방', '요리사', '제과', '제빵']),
  JobItem('매장 관리·판매', '기타', ['매장', '판매', '서비스', '점장']),
  JobItem('사회복지', '기타', ['복지', '돌봄', '사회복지사']),
  JobItem('교육·강사', '기타', ['강사', '교육', '튜터', '학원']),
];

/// 검색어로 직무 찾기. [field] 를 주면 그 분야 직무를 앞에 둡니다.
List<JobItem> searchJobs(String query, {String? field}) {
  final hits = kJobCatalog.where((j) => j.matches(query));
  if (field == null) return hits.toList();
  return [...hits.where((j) => j.field == field), ...hits.where((j) => j.field != field)];
}
