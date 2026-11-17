"""crawl_postings.py · posting_requirements.py 테스트 (네트워크 X)

실행 (저장소 루트에서):
    python tool/test_posting_requirements.py
"""
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from crawl_postings import corp_matches, job_matches, parse_search, strip_tags  # noqa: E402
from posting_requirements import (  # noqa: E402
    aggregate,
    edu_from_condition,
    edu_from_text,
    english_from_text,
    extract,
    gpa_from_text,
)

# 사람인 검색 결과와 같은 구조로 만든 가짜 HTML (2026-11 구조 기준)
SEARCH_HTML = """
<div class="item_recruit" value="111" data-data_layer="x">
  <div class="area_job">
    <h2 class="job_tit"><a title="2026 하반기 신입 백엔드 개발자" href="/zf_user/jobs/relay/view?rec_idx=111"><span>2026 하반기 신입 백엔드 개발자</span></a></h2>
    <div class="job_condition">
      <span><a href="#">경기</a> <a href="#">성남시 분당구</a></span>
      <span>신입</span> <span>대졸↑</span> <span>정규직</span>
    </div>
    <div class="job_sector"><b><a href="#">백엔드/서버개발</a></b>, <a href="#">Java</a> <span class="job_day">등록일 26/11/01</span></div>
  </div>
  <div class="area_corp"><strong class="corp_name"><a href="#"> <b>네이버</b>(주) </a></strong></div>
</div>
<div class="item_recruit" value="222">
  <div class="area_job">
    <h2 class="job_tit"><a title="[다른회사] 서버 개발" href="#"><span>x</span></a></h2>
    <div class="job_condition"><span>서울</span><span>경력무관</span><span>초대졸↑</span><span>정규직</span></div>
    <div class="job_sector"><a href="#">웹개발</a></div>
  </div>
  <div class="area_corp"><strong class="corp_name"><a href="#">엔에이치엔(주)</a></strong></div>
</div>
"""


class ParseSearchTest(unittest.TestCase):
    def test_items(self):
        items = parse_search(SEARCH_HTML)
        self.assertEqual([i["id"] for i in items], ["111", "222"])
        a = items[0]
        self.assertEqual(a["title"], "2026 하반기 신입 백엔드 개발자")
        self.assertEqual(a["corp"], "네이버 (주)")
        self.assertEqual(a["conditions"], ["경기 성남시 분당구", "신입", "대졸↑", "정규직"])
        self.assertEqual(a["sectors"], ["백엔드/서버개발", "Java"])

    def test_corp_filter(self):
        self.assertTrue(corp_matches("네이버 (주)", "네이버"))
        self.assertTrue(corp_matches("㈜카카오", "카카오"))
        self.assertFalse(corp_matches("엔에이치엔(주)", "네이버"))

    def test_job_filter(self):
        a = parse_search(SEARCH_HTML)[0]
        self.assertTrue(job_matches(a, "백엔드"))
        self.assertTrue(job_matches(a, "java"))
        self.assertFalse(job_matches(a, "디자인"))
        self.assertFalse(job_matches(a, ""))

    def test_strip_tags(self):
        self.assertEqual(strip_tags("<p>자격요건</p><ul><li>학점 3.0 이상</li></ul><script>x()</script>"), "자격요건\n학점 3.0 이상")


class ExtractTest(unittest.TestCase):
    def test_edu_condition(self):
        self.assertEqual(edu_from_condition("대졸↑"), "univ")
        self.assertEqual(edu_from_condition("초대졸↑"), "college")
        self.assertEqual(edu_from_condition("고졸↑"), "high")
        self.assertEqual(edu_from_condition("학력무관"), "none")
        self.assertIsNone(edu_from_condition("정규직"))
        self.assertIsNone(edu_from_condition("경기 성남시"))

    def test_edu_text(self):
        self.assertEqual(edu_from_text("• 4년제 대학 졸업(예정)자 이상"), "univ")
        self.assertEqual(edu_from_text("• 전문대학 졸업 이상"), "college")
        self.assertEqual(edu_from_text("• 석사 학위 이상 우대"), None)  # 우대는 필수가 아님

    def test_gpa(self):
        self.assertEqual(gpa_from_text("• 학점 3.0 이상"), 3.0)
        self.assertEqual(gpa_from_text("• 평점 3.2/4.3 이상"), 3.35)
        self.assertEqual(gpa_from_text("• GPA 3.0 이상 (4.0 만점)"), 3.38)
        self.assertIsNone(gpa_from_text("• 학점 3.5 이상 우대"))

    def test_english_required_beats_preferred(self):
        text = "• 최종 학점 3.0 이상 / 오픽 IM1 이상 또는 이에 준하는 성적(토익 700점, 토익스피킹 IM1)\n• TOEIC 900점 이상 우대"
        e = english_from_text(text)
        self.assertEqual(e["required"], True)
        self.assertEqual(e["toeic"], 650)  # OPIc IM1 ≈ 650 (같은 줄에서는 먼저 나온 시험)

    def test_english_preferred_only(self):
        e = english_from_text("• 토익 800점 이상 우대")
        self.assertEqual(e, {"exam": "TOEIC", "score": "800", "toeic": 800, "required": False})

    def test_toeic_speaking(self):
        self.assertEqual(english_from_text("• 토익스피킹 Lv.6 이상")["toeic"], 700)
        self.assertEqual(english_from_text("• TOEIC Speaking 130점 이상")["toeic"], 700)
        self.assertEqual(english_from_text("• 토익스피킹 IH 이상")["toeic"], 850)

    def test_extract(self):
        text = (
            "자격요건\n• 4년제 대학 졸업(예정)자\n• Java, Spring 기반 개발 경험\n• 동료와 협업하며 문제를 해결한 경험\n"
            "우대사항\n• 정보처리기사 소지자 우대\n• 깃허브 포트폴리오 제출 시 우대\n" + "본문 " * 60
        )
        e = extract(["경기", "신입", "대졸↑", "정규직"], ["백엔드/서버개발"], text)
        self.assertEqual(e["education"], "univ")
        self.assertEqual(e["career"], "신입")
        self.assertIsNone(e["minGpa"])
        self.assertIsNone(e["english"])
        self.assertIn("정보처리기사", e["certificates"])
        self.assertTrue({"Java", "Spring", "백엔드/서버개발"} <= set(e["skills"]))
        self.assertTrue(e["portfolio"])
        self.assertTrue(e["teamwork"])
        self.assertTrue(e["detailText"])

    def test_image_only_posting(self):
        e = extract(["서울", "경력무관", "고졸↑", "정규직"], ["전자"], "")
        self.assertEqual(e["education"], "high")
        self.assertFalse(e["detailText"])
        self.assertFalse(e["portfolio"])


class AggregateTest(unittest.TestCase):
    def _p(self, **kw):
        base = {"education": "univ", "career": "신입", "minGpa": None, "english": None, "certificates": [],
                "skills": [], "portfolio": False, "teamwork": False, "detailText": True, "preferredLines": 0}
        base.update(kw)
        return {"extracted": base}

    def test_aggregate(self):
        ps = [
            self._p(minGpa=3.0, english={"exam": "TOEIC", "score": "700", "toeic": 700, "required": True},
                    skills=["Java", "Spring"], portfolio=True, teamwork=True),
            self._p(minGpa=3.4, english={"exam": "OPIc", "score": "IM2", "toeic": 700, "required": True},
                    skills=["Java"], teamwork=True),
            self._p(education="college", skills=["Python"]),
        ]
        a = aggregate(ps)
        self.assertEqual(a["postingCount"], 3)
        self.assertEqual(a["education"], "univ")
        self.assertEqual(a["minGpa"], 3.2)
        self.assertEqual(a["minEnglish"], 700)
        self.assertEqual(a["portfolioRate"], 0.33)
        self.assertEqual(a["teamworkRate"], 0.67)
        self.assertEqual(a["skills"], ["Java"])

    def test_rarely_mentioned_is_dropped(self):
        ps = [self._p(minGpa=3.5)] + [self._p() for _ in range(5)]
        self.assertIsNone(aggregate(ps)["minGpa"])  # 6건 중 1건만 적음 → 기준으로 안 씀

    def test_empty(self):
        self.assertIsNone(aggregate([]))


if __name__ == "__main__":
    unittest.main()
