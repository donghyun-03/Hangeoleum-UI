"""관심기업 채용 공고 수집 (크롤링 버전) → 기업·직무별 지원 기준 JSON

⚠ 꼭 읽기
  - 채용 공고 사이트를 허락 없이 반복·체계적으로 긁어서 서비스에 쓰면 데이터베이스권 침해·부정경쟁행위가
    될 수 있다 (잡코리아 v. 사람인, 서울고법 2016나2019365 등). 이 스크립트는 수업 시연용으로
    "직접 실행해서, 적은 양만, 천천히" 가져오도록 만들었다.
  - robots.txt 에서 막힌 경로면 바로 멈춘다. 요청 사이에 기본 3초를 쉰다. 한 번에 최대 2페이지·상세 10건.
  - 공고 본문은 저장하지 않고, 학력·학점·어학·자격증·기술 키워드 같은 '사실 정보'만 남긴다.
  - 결과 JSON 은 앱 저장소(깃)에 올리지 말고 hangeoreum_data/postings/ 처럼 바깥 폴더에 둔다.
  - 실제 서비스에서는 공식 API(고용24 OPEN-API 채용정보 등)로 바꿔야 한다.

실행 (저장소 루트에서)
    python tool/crawl_postings.py --company 네이버 --job 백엔드 --group dev --out ../hangeoreum_data/postings
    python tool/postings_to_dart.py ../hangeoreum_data/postings          # → lib/data/posting_criteria_data.dart

    --group : 앱의 직무 묶음 (dev / data / design / office / marketing)
    --pages : 검색 결과 페이지 수 (1~2, 기본 1)
    --details : 본문까지 볼 공고 수 (0~10, 기본 5)
    --delay : 요청 사이 쉬는 시간(초, 최소 2, 기본 3)
    --from-html : 저장해 둔 검색 결과 HTML 로 오프라인 실행 (네트워크 X, 테스트용)

표준 라이브러리만 사용.
"""
import argparse
import html
import json
import re
import sys
import time
import urllib.parse
import urllib.request
import urllib.robotparser
from datetime import date
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from posting_requirements import aggregate, extract  # noqa: E402

BASE = "https://www.saramin.co.kr"
SEARCH = BASE + "/zf_user/search/recruit?searchword={q}&recruitPage={page}&recruitPageCount=40"
DETAIL = BASE + "/zf_user/jobs/relay/view-detail?rec_idx={id}&rec_seq=0&t_category=relay_view&t_content=view_detail"
VIEW = BASE + "/zf_user/jobs/relay/view?rec_idx={id}"
USER_AGENT = "HangeoleumStudentBot/0.1 (KIT open-source class project; non-commercial; low-rate)"
GROUPS = ["dev", "data", "design", "office", "marketing"]


# ───────────────────────── HTML → 데이터

def strip_tags(fragment):
    """HTML 조각 → 글자 (줄바꿈 유지)"""
    s = re.sub(r"(?is)<(script|style|noscript)[^>]*>.*?</\1>", " ", fragment or "")
    s = re.sub(r"(?i)<br\s*/?>|</(p|li|div|tr|h\d|dd|dt|table)>", "\n", s)
    s = re.sub(r"(?s)<[^>]+>", " ", s)
    s = html.unescape(s).replace("\xa0", " ")
    lines = [re.sub(r"[ \t]+", " ", x).strip() for x in s.split("\n")]
    return "\n".join(x for x in lines if x)


def _first(pattern, text, group=1):
    m = re.search(pattern, text, re.S)
    return m.group(group) if m else None


def parse_search(page_html):
    """사람인 검색 결과 HTML → 공고 목록 [{id, title, corp, conditions, sectors}]

    구조 (2026-11 확인): div.item_recruit[value=rec_idx]
      h2.job_tit > a[title]            공고 제목
      strong.corp_name > a             회사 이름
      div.job_condition > span × 4     지역 · 경력 · 학력 · 고용형태
      div.job_sector > (b >) a …       직무 분야 태그 (span.job_day 는 등록일)
    """
    chunks = re.split(r'<div class="item_recruit"', page_html)[1:]
    items = []
    for c in chunks:
        rec_id = _first(r'^\s*value="(\d+)"', c)
        if not rec_id:
            continue
        title = _first(r'<h2 class="job_tit">.*?<a[^>]*\btitle="([^"]*)"', c)
        corp = _first(r'<strong class="corp_name">\s*<a[^>]*>(.*?)</a>', c)
        cond_block = _first(r'<div class="job_condition">(.*?)</div>', c) or ""
        conditions = [strip_tags(x).replace("\n", " ") for x in re.findall(r"<span[^>]*>(.*?)</span>", cond_block, re.S)]
        sector_block = _first(r'<div class="job_sector">(.*?)</div>', c) or ""
        sector_block = re.sub(r'(?s)<span class="job_day">.*?</span>', "", sector_block)
        sectors = [strip_tags(x) for x in re.findall(r"<a[^>]*>(.*?)</a>", sector_block, re.S)]
        items.append({
            "id": rec_id,
            "title": html.unescape(title or "").strip(),
            "corp": strip_tags(corp or "").strip(),
            "conditions": [x for x in conditions if x],
            "sectors": [x for x in sectors if x],
        })
    return items


_CORP_NOISE = re.compile(r"\(주\)|㈜|주식회사|\(유\)|\(재\)|\(사\)|유한회사|\s+")


def norm_corp(name):
    return _CORP_NOISE.sub("", name or "").lower()


def corp_matches(corp, company):
    """검색어에 다른 회사 공고도 섞여 나오므로 회사 이름으로 한 번 더 거른다"""
    a, b = norm_corp(corp), norm_corp(company)
    return bool(a and b) and (b in a or a in b)


def job_matches(item, job):
    """직무 검색어(띄어쓰기로 여러 개 가능)가 제목이나 직무 태그에 들어 있는지"""
    words = [w.lower() for w in (job or "").split() if w]
    hay = (item["title"] + " " + " ".join(item["sectors"])).lower()
    return bool(words) and any(w in hay for w in words)


# ───────────────────────── 네트워크

class Fetcher:
    def __init__(self, delay):
        self.delay = max(2.0, delay)
        self.last = 0.0
        self.robots = urllib.robotparser.RobotFileParser(BASE + "/robots.txt")
        self.robots_loaded = False

    def allowed(self, url):
        if not self.robots_loaded:
            self.robots.read()
            self.robots_loaded = True
        return self.robots.can_fetch(USER_AGENT, url)

    def get(self, url):
        if not self.allowed(url):
            raise SystemExit(f"robots.txt 에서 막힌 주소라 멈춥니다: {url}")
        wait = self.delay - (time.time() - self.last)
        if wait > 0:
            time.sleep(wait)
        req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT, "Accept-Language": "ko"})
        try:
            with urllib.request.urlopen(req, timeout=20) as r:
                body = r.read().decode("utf-8", "replace")
        finally:
            self.last = time.time()
        return body


# ───────────────────────── 실행

def crawl(company, job, pages, details, delay, from_html=None):
    fetcher = None if from_html else Fetcher(delay)
    items = []
    if from_html:
        items = parse_search(Path(from_html).read_text(encoding="utf-8"))
    else:
        # '네이버 백엔드' 처럼 같이 검색하면 다른 회사 공고가 대부분이라, 회사 이름으로만 검색하고 직무는 아래에서 거른다
        q = urllib.parse.quote(company.strip())
        for page in range(1, pages + 1):
            got = parse_search(fetcher.get(SEARCH.format(q=q, page=page)))
            items += got
            if len(got) < 40:
                break

    seen, mine = set(), []
    for it in items:
        if it["id"] in seen or not corp_matches(it["corp"], company):
            continue
        seen.add(it["id"])
        mine.append(it)

    # 직무 검색어가 제목·직무 태그에 있는 공고만. 하나도 없으면 그 회사 공고 전체를 씀
    job_hit = [it for it in mine if job_matches(it, job)]
    if job and job_hit:
        mine = job_hit

    postings = []
    for i, it in enumerate(mine):
        text = ""
        if fetcher and i < details:
            text = strip_tags(fetcher.get(DETAIL.format(id=it["id"])))
        postings.append({
            "id": it["id"],
            "url": VIEW.format(id=it["id"]),
            "corp": it["corp"],
            "title": it["title"],
            "conditions": it["conditions"],
            "extracted": extract(it["conditions"], it["sectors"], text),
        })
    return postings


def main(argv=None):
    ap = argparse.ArgumentParser(description="관심기업 채용 공고 → 지원 기준 JSON (수업 시연용, 소량)")
    ap.add_argument("--company", required=True, help="관심기업 이름 (예: 네이버)")
    ap.add_argument("--job", default="", help="직무 검색어 (예: 백엔드). 공고 제목·직무 태그로 거름")
    ap.add_argument("--group", required=True, choices=GROUPS, help="앱의 직무 묶음")
    ap.add_argument("--pages", type=int, default=1)
    ap.add_argument("--details", type=int, default=5)
    ap.add_argument("--delay", type=float, default=3.0)
    ap.add_argument("--out", default="../hangeoreum_data/postings", help="결과 JSON 폴더 (앱 저장소 밖 권장)")
    ap.add_argument("--from-html", help="저장한 검색 결과 HTML 로 오프라인 실행")
    a = ap.parse_args(argv)

    pages = min(max(a.pages, 1), 2)
    details = min(max(a.details, 0), 10)
    postings = crawl(a.company, a.job, pages, details, a.delay, a.from_html)
    agg = aggregate(postings)
    if not agg:
        print(f"'{a.company}' 공고를 찾지 못했어요. 회사 이름이나 직무 검색어를 바꿔 보세요.")
        return 1

    result = {
        "source": "saramin",
        "company": a.company,
        "job": a.job,
        "group": a.group,
        "fetchedAt": date.today().isoformat(),
        "criteria": agg,
        "postings": postings,
    }
    out = Path(a.out)
    out.mkdir(parents=True, exist_ok=True)
    name = re.sub(r"[^\w가-힣]+", "_", f"{a.company}_{a.job or a.group}").strip("_")
    path = out / f"{name}.json"
    path.write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"공고 {agg['postingCount']}건 → {path}")
    print(json.dumps(agg, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main())
