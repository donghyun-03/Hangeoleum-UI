"""채용 공고 → 지원 기준 추출 (순수 함수, 네트워크 X)

crawl_postings.py 가 가져온 공고 목록 조건(지역·경력·학력·고용형태)과 상세 본문 글에서
학력 · 학점 · 어학 · 자격증 · 기술 키워드 · 포트폴리오/협업 언급 여부만 뽑는다.
본문 원문은 저장하지 않는다 (저작권·데이터베이스권 문제를 줄이려고 '사실 정보'만 남김).

표준 라이브러리만 사용.
"""
import re
from collections import Counter
from statistics import median

# 앱(lib/models/criteria.dart)의 EduLevel 이름과 같게 맞춤
EDU_RANK = {"none": 0, "high": 1, "college": 2, "univ": 3, "graduate": 4}

# 목록 조건의 학력 표기 (사람인: 학력무관 / 고졸↑ / 초대졸↑ / 대졸↑ / 석사↑ / 박사↑ / 대학(4년)↑ …)
_LIST_EDU = [  # 순서 중요: '초대졸'을 '대졸'보다 먼저 봄
    ("박사", "graduate"),
    ("석사", "graduate"),
    ("초대졸", "college"),
    ("대학(2,3년)", "college"),
    ("대졸", "univ"),
    ("대학(4년)", "univ"),
    ("4년", "univ"),
    ("고졸", "high"),
    ("학력무관", "none"),
]

# 본문의 학력 문장
_TEXT_EDU = [
    (re.compile(r"(석사|박사)\s*(학위)?\s*(이상|소지|보유)"), "graduate"),
    (re.compile(r"(4년제|학사)\s*(대학)?\s*(졸업|학위)?\s*(\(예정\))?\s*(예정자)?\s*(이상)?"), "univ"),
    (re.compile(r"(?<!초)대졸\s*(예정자?)?\s*이상|(?<!전문)대학교?\s*졸업\s*(예정자?)?\s*이상"), "univ"),
    (re.compile(r"(초대졸|전문대(학)?\s*졸업)\s*(예정자?)?\s*이상"), "college"),
    (re.compile(r"고졸\s*이상|고등학교\s*졸업\s*이상"), "high"),
    (re.compile(r"학력\s*(무관|제한\s*없음)"), "none"),
]

# 학점: "학점 3.0 이상", "평점 3.0/4.5 이상", "GPA 3.5 이상(4.5 만점)"
_GPA = re.compile(
    r"(?:학점|평점|GPA|성적)\s*[:은는]?\s*(?:평균\s*)?(?P<v>[1-4]\.\d{1,2})\s*(?:/\s*(?P<s>4\.[035]))?"
    r"(?:\s*\(?\s*(?P<s2>4\.[035])\s*만점\s*\)?)?\s*이상"
)

_OPIC = {"NL": 300, "NM": 350, "NH": 400, "IL": 550, "IM1": 650, "IM2": 700, "IM3": 750, "IM": 700, "IH": 850, "AL": 950}
_TOS_LV = {4: 500, 5: 600, 6: 700, 7: 800, 8: 900}

_TOEIC = re.compile(r"(?:TOEIC|토익)(?!\s*(?:Speaking|스피킹))\s*[:]?\s*(?P<n>[4-9]\d{2})\s*점?")
_TOS = re.compile(
    r"(?:TOEIC\s*Speaking|토익\s*스피킹|토스)\s*[:]?\s*"
    r"(?:(?:Lv\.?|레벨|level)?\s*(?P<n>[4-8]|1[0-9]{2}|200)(?!\d)|(?P<g>IM[1-3]|IL|IH|AL|NH|NM|NL))",
    re.I,
)
_OPIC_RE = re.compile(r"(?:OPIc|OPIC|오픽)\s*[:]?\s*(?P<g>IM[1-3]|NL|NM|NH|IL|IM|IH|AL)", re.I)
_TOEFL = re.compile(r"(?:TOEFL|토플)\s*(?:iBT)?\s*[:]?\s*(?P<n>\d{2,3})\s*점?", re.I)

CERTS = [
    "정보처리기사", "정보처리산업기사", "정보보안기사", "빅데이터분석기사", "SQLD", "SQLP", "ADsP", "ADP",
    "컴퓨터활용능력", "컴활", "GTQ", "웹디자인기능사", "시각디자인기사", "전산회계", "전산세무", "재경관리사",
    "한국사능력검정", "네트워크관리사", "리눅스마스터", "AWS", "CCNA", "정보처리기능사", "사회조사분석사",
]

# 직무연관성 판단에 쓸 기술 키워드 후보 (본문에서 자주 나오는 것만)
SKILLS = [
    "Java", "Kotlin", "Spring", "Python", "Django", "FastAPI", "Node.js", "JavaScript", "TypeScript", "React", "Vue",
    "Flutter", "Dart", "Swift", "Android", "iOS", "C++", "C#", "Go", "SQL", "MySQL", "PostgreSQL", "Oracle",
    "Redis", "Kafka", "Docker", "Kubernetes", "AWS", "GCP", "Linux", "Git", "LLM", "RAG", "PyTorch", "TensorFlow",
    "Figma", "Photoshop", "Illustrator", "Premiere", "After Effects", "Excel", "엑셀", "PowerPoint", "Tableau",
    "GA4", "SEO", "SNS", "회계", "ERP", "SAP",
]

_PORTFOLIO = re.compile(r"포트폴리오|portfolio|깃허브|github|작업물|결과물\s*(제출|첨부)", re.I)
_TEAMWORK = re.compile(r"협업|커뮤니케이션|소통|팀\s*프로젝트|팀워크|동료와|함께\s*(일|성장)")
_PREFERRED = re.compile(r"우대|가산|플러스|더\s*좋아요|있으면\s*좋")


def _lines(text):
    """본문을 문장/줄 단위로 나눔 (• · ㆍ - 줄바꿈 기준)"""
    parts = re.split(r"[\n\r]+|(?<=[.!?])\s+|\s*[•·ㆍ▪◦■□▶►※-]\s+", text or "")
    return [p.strip() for p in parts if p and p.strip()]


def edu_from_condition(cond):
    """목록 조건 문자열 하나 → EduLevel 이름 (해당 없으면 None)"""
    c = (cond or "").replace(" ", "")
    if "학력" not in c and "졸" not in c and "↑" not in c and "석사" not in c and "박사" not in c:
        return None
    for key, level in _LIST_EDU:
        if key in c:
            return level
    return None


def edu_from_text(text):
    """본문에서 가장 높은 필수 학력 (우대 문장은 제외)"""
    best = None
    for line in _lines(text):
        if _PREFERRED.search(line):
            continue
        for pat, level in _TEXT_EDU:
            if pat.search(line):
                if best is None or EDU_RANK[level] > EDU_RANK[best]:
                    best = level
    return best


def gpa_from_text(text):
    """필수 학점 하한 (4.5 만점 환산). 없으면 None"""
    for line in _lines(text):
        if _PREFERRED.search(line):
            continue
        m = _GPA.search(line)
        if not m:
            continue
        v = float(m.group("v"))
        after = re.search(r"(4\.[035])\s*만점", line)  # "3.0 이상 (4.0 만점)" 처럼 뒤에 적은 경우
        scale = float(m.group("s") or m.group("s2") or (after.group(1) if after else 4.5))
        if v > scale:
            continue
        return round(v * 4.5 / scale, 2)
    return None


def _english_in(line):
    """한 문장에서 영어 점수 → (시험, 원래 표기, TOEIC 환산)"""
    m = _TOS.search(line)
    if m and m.group("g"):  # 2022년부터 토익스피킹도 IM1·IH 같은 등급 표기를 씀
        g = m.group("g").upper()
        return ("TOEIC Speaking", g, _OPIC[g])
    if m:
        n = int(m.group("n"))
        lv = n if n <= 8 else (8 if n >= 180 else 7 if n >= 160 else 6 if n >= 130 else 5 if n >= 110 else 4)
        return ("TOEIC Speaking", m.group(0).strip(), _TOS_LV[max(4, min(8, lv))])
    m = _OPIC_RE.search(line)
    if m:
        g = m.group("g").upper()
        return ("OPIc", g, _OPIC[g])
    m = _TOEIC.search(line)
    if m:
        return ("TOEIC", m.group("n"), int(m.group("n")))
    m = _TOEFL.search(line)
    if m:
        n = int(m.group("n"))
        if 40 <= n <= 120:
            return ("TOEFL", str(n), min(990, round(n * 6.5 + 260)))
    return None


def english_from_text(text):
    """어학 기준. 필수 기준이 있으면 그중 가장 낮은 것, 없으면 우대 기준 (required=False)"""
    required, preferred = [], []
    for line in _lines(text):
        e = _english_in(line)
        if not e:
            continue
        (preferred if _PREFERRED.search(line) else required).append(e)
    pool, is_required = (required, True) if required else (preferred, False)
    if not pool:
        return None
    exam, raw, toeic = min(pool, key=lambda e: e[2])
    return {"exam": exam, "score": raw, "toeic": toeic, "required": is_required}


def certificates_from_text(text):
    t = text or ""
    found = []
    for c in CERTS:
        if c in t and c not in found:
            found.append(c)
    # 컴활 / 컴퓨터활용능력 은 하나로
    if "컴활" in found and "컴퓨터활용능력" in found:
        found.remove("컴활")
    return found


def skills_from_text(text):
    t = text or ""
    found = []
    for s in SKILLS:
        if re.search(r"(?<![A-Za-z])" + re.escape(s) + r"(?![A-Za-z])", t, re.I if s.isascii() else 0):
            found.append(s)
    return found


def extract(conditions, sectors, text):
    """공고 한 건 → 추출 결과 (원문은 담지 않음)

    conditions: 목록 조건 문자열들 (예: ['경기 성남시', '경력무관', '대졸↑', '정규직'])
    sectors:    직무 분야 태그 (예: ['백엔드/서버개발', 'Java'])
    text:       상세 본문 글 (없으면 빈 문자열)
    """
    list_edu = next((e for e in map(edu_from_condition, conditions) if e), None)
    text_edu = edu_from_text(text)
    # 목록 조건과 본문 중 더 높은 쪽을 필수 학력으로 봄
    edu = max([e for e in (list_edu, text_edu) if e], key=lambda e: EDU_RANK[e], default=None)
    career = next((c for c in conditions if "경력" in c or "신입" in c), None)
    lines = _lines(text)
    return {
        "education": edu,
        "career": career,
        "minGpa": gpa_from_text(text),
        "english": english_from_text(text),
        "certificates": certificates_from_text(text),
        "skills": sorted(set(skills_from_text(text)) | {s for s in sectors if s}),
        "portfolio": bool(_PORTFOLIO.search(text or "")),
        "teamwork": bool(_TEAMWORK.search(text or "")),
        "detailText": len(text or "") >= 200,  # 본문이 이미지뿐이면 False
        "preferredLines": sum(1 for x in lines if _PREFERRED.search(x)),
    }


def aggregate(postings):
    """같은 기업·직무 공고 여러 건 → 앱에 넣을 기준 한 개

    - 학력: 가장 많이 나온 값 (동률이면 높은 쪽)
    - 학점·어학: 필수로 적은 공고들의 중앙값 (공고 3건 중 1건 이상이 적었을 때만)
    - 포트폴리오·협업: 언급한 공고 비율 (0~1)
    - 기술·자격증: 2건 이상 나온 것 (공고가 1건이면 전부)
    """
    ex = [p["extracted"] for p in postings]
    n = len(ex)
    if n == 0:
        return None

    edus = Counter(e["education"] for e in ex if e["education"])
    education = None
    if edus:
        top = max(edus.values())
        education = max((k for k, v in edus.items() if v == top), key=lambda k: EDU_RANK[k])

    need = max(1, -(-n // 3))  # 3건 중 1건 이상
    gpas = [e["minGpa"] for e in ex if e["minGpa"]]
    eng_req = [e["english"]["toeic"] for e in ex if e["english"] and e["english"]["required"]]
    eng_pref = [e["english"]["toeic"] for e in ex if e["english"] and not e["english"]["required"]]

    def frequent(key):
        c = Counter(x for e in ex for x in e[key])
        cut = 1 if n == 1 else 2
        return [k for k, v in c.most_common() if v >= cut][:12]

    return {
        "postingCount": n,
        "detailCount": sum(1 for e in ex if e["detailText"]),  # 본문 글을 읽을 수 있었던 공고 수 (이미지 공고 제외)
        "education": education,
        "minGpa": round(median(gpas), 1) if len(gpas) >= need else None,
        "minEnglish": int(median(eng_req)) if len(eng_req) >= need else None,
        "englishPreferred": bool(eng_pref) and len(eng_req) < need,
        "portfolioRate": round(sum(e["portfolio"] for e in ex) / n, 2),
        "teamworkRate": round(sum(e["teamwork"] for e in ex) / n, 2),
        "skills": frequent("skills"),
        "certificates": frequent("certificates"),
        "careers": [k for k, _ in Counter(e["career"] for e in ex if e["career"]).most_common()],
    }
