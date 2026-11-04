"""온통청년 v3 정책 데이터 -> lib/data/ontong_programs.dart (앱 더미 데이터)

백엔드가 붙기 전까지 앱에서 실제 온통청년 정책을 보여 주려고, v3 JSON 에서 일부를 골라 Dart 상수로 만든다.

실행 (저장소 루트에서):
    python tool/ontong_to_dart.py ../hangeoreum_data/programs_ontong_v3.json

데이터 갱신 순서
    1) hangeoreum_data/fetch_ontong.py     API 수집 -> raw/ontong_youth_policies.json
    2) hangeoreum_data/convert_ontong_v3.py raw -> programs_ontong_v3.json
    3) 이 스크립트                          v3 -> lib/data/ontong_programs.dart

고르는 기준 (실행한 날 기준)
    STEP 3 : 지금 신청할 수 있고(특정기간, 시작~마감 사이) 마감까지 3일 이상 남음,
             만 19~34세가 신청 가능, 대분류가 교육·직업훈련 / 일자리 / 참여·기반,
             지원 방식이 프로그램·교육 성격, 특화 요건(군인·장애인 등) 없음
             -> 전국·서울 정책 위주로 조회수 순
    알림   : 마감 임박(1~7일 남음) 2건, 최근 등록된 정책 2건
표준 라이브러리만 사용.
"""
import json
import sys
from datetime import date, datetime
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DST = ROOT / "lib" / "data" / "ontong_programs.dart"

STEP3_COUNT = 30  # 전체 개수
STEP3_LOCAL = 8  # 그중 전국·서울 외 지역 정책 수
STEP3_CATEGORIES = {"교육･직업훈련", "일자리", "참여･기반"}
STEP3_METHODS = {"프로그램", "기타", "계약(위탁운영)"}  # 보조금·대출·바우처·보험 등 돈을 주는 정책은 제외
# 지원 방식이 '기타'여도 이름·키워드로 보면 돈·물품 지원인 정책은 STEP 3(도전)에서 뺌
MONEY_WORDS = ["장려금", "보증", "임차료", "응시료", "취득비", "이용료", "정장", "보조금", "지원금", "수당", "대출",
               "보험", "월세", "적금", "통장", "자격증 취득 지원", "자격증 취득비용"]
MONEY_KEYWORDS = {"보조금", "대출", "바우처"}

if len(sys.argv) < 2:
    sys.exit("사용법: python tool/ontong_to_dart.py <programs_ontong_v3.json 경로>")
data = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
programs = data["programs"]
TODAY = date.today()


def d(v):
    return date.fromisoformat(v) if v else None


def youth_ok(p):
    lo, hi = p.get("minAge"), p.get("maxAge")
    return (lo is None or lo <= 34) and (hi is None or hi >= 19)


def recruiting(p, min_days=0):
    """지금 신청 가능한 특정기간 정책 (마감까지 min_days 이상)"""
    if p["closed"] or p["applyPeriodType"] != "특정기간":
        return False
    start, end = d(p.get("applyStart")), d(p.get("applyEnd"))
    return bool(start and end and start <= TODAY and (end - TODAY).days >= min_days)


def step3_ok(p):
    return (
        recruiting(p, 3)
        and youth_ok(p)
        and set(p.get("categories") or []) & STEP3_CATEGORIES
        and (p.get("provisionMethod") or "기타") in STEP3_METHODS
        and not p.get("specialConditions")
        and not any(w in p["name"] for w in MONEY_WORDS)
        and not set(p.get("keywords") or []) & MONEY_KEYWORDS
        and (p.get("description") or p.get("benefit"))
    )


def youth_topic(p):
    """알림 '새 소식'용: 청년 일자리·교육·참여 분야이고 특화 요건이 없는 정책"""
    return set(p.get("categories") or []) & STEP3_CATEGORIES and not p.get("specialConditions")


def seoul_or_all(p):
    return p["isNationwide"] or "11" in p["regionSidoCodes"]


# 지원 방식이 '프로그램'인 정책을 먼저, 그 안에서 조회수 순
by_views = sorted(
    (p for p in programs if step3_ok(p)),
    key=lambda p: (p.get("provisionMethod") != "프로그램", -(p.get("viewCount") or 0)),
)
main = [p for p in by_views if seoul_or_all(p)][: STEP3_COUNT - STEP3_LOCAL]
local = [p for p in by_views if not seoul_or_all(p)][: STEP3_COUNT - len(main)]
step3 = sorted(main + local, key=lambda p: p["applyEnd"])

open_youth = [p for p in programs if not p["closed"] and youth_ok(p)]
deadline = sorted(
    (p for p in open_youth if recruiting(p) and 1 <= (d(p["applyEnd"]) - TODAY).days <= 7),
    key=lambda p: -(p.get("viewCount") or 0),
)[:2]
fresh = sorted(
    (p for p in open_youth if p.get("firstRegistered") and youth_topic(p) and p not in deadline),
    key=lambda p: p["firstRegistered"],
    reverse=True,
)[:2]


# ---------- Dart 출력 ----------
def lit(v):
    if v is None:
        return "null"
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, (int, float)):
        return repr(v)
    if isinstance(v, list):
        return "[" + ", ".join(lit(x) for x in v) + "]"
    s = str(v).replace("\\", "\\\\").replace("'", "\\'").replace("$", "\\$")
    s = s.replace("\r\n", "\n").replace("\r", "\n").replace("\n", "\\n").replace("\t", " ")
    return f"'{s}'"


# ProgramDetail 생성자 인자 (v3 필드 중 앱에서 쓰는 것). 기본값과 같으면 생략
FIELDS = [
    "originalId", "firstRegistered", "lastModified",
    "name", "description", "benefit", "providerGroup", "provisionMethod",
    "organization", "organizationRole", "operatingOrg", "supervisingOrg", "registeringOrg", "regionTopOrg",
    "category", "categories", "subCategory", "subCategories", "keywords",
    "isNationwide", "regionSidoCodes", "regionZipCodes",
    "minAge", "maxAge", "jobConditions", "educationConditions", "majorConditions", "specialConditions",
    "marriageCondition", "incomeConditionType", "incomeMin", "incomeMax", "incomeConditionText",
    "extraEligibility", "excludedTargets",
    "isFirstComeFirstServed", "supportCount", "viewCount",
    "applyPeriodType", "applyStart", "applyEnd",
    "bizPeriodType", "bizStart", "bizEnd", "bizPeriodText",
    "applyUrl", "refUrls", "applyMethod", "screeningMethod", "documents", "etc",
    "reviewStatus", "closed", "closedReason",
]
DEFAULT_EMPTY = {"categories", "subCategories", "keywords", "regionSidoCodes", "regionZipCodes", "jobConditions",
                 "educationConditions", "majorConditions", "specialConditions", "refUrls"}


def program(p):
    lines = [f"  ProgramDetail(", f"    id: {lit(p['originalId'])},"]
    for f in FIELDS:
        v = p.get(f)
        if v is None or (f in DEFAULT_EMPTY and not v) or (f in ("isNationwide", "closed") and v is False):
            continue
        if f == "regionZipCodes" and p.get("isNationwide"):
            continue  # 전국 정책은 시군구 코드 수백 개라 생략 (화면에 안 씀)
        lines.append(f"    {f}: {lit(v)},")
    periods = p.get("applyPeriods") or []
    if len(periods) > 1:
        inner = ", ".join(f"ApplyPeriod({lit(x['start'])}, {lit(x['end'])})" for x in periods)
        lines.append(f"    applyPeriods: [{inner}],")
    lines.append("  ),")
    return "\n".join(lines)


def block(name, doc, items):
    body = "\n".join(program(p) for p in items)
    return f"/// {doc}\nconst {name} = <ProgramDetail>[\n{body}\n];\n"


header = f"""// 자동 생성 파일 — 직접 고치지 마세요.
// 만든 방법: python tool/ontong_to_dart.py <hangeoreum_data/programs_ontong_v3.json>
// 원본: 온통청년 청년정책 OPEN API (화면에 출처·원문 링크 표시 필수)
// 수집 {data.get('fetchedAt')} · 변환 {data.get('convertedAt')} · 선택 {TODAY.isoformat()}
// STEP·난이도·소요 시간은 LLM 분류 전이라 비어 있습니다.
import '../models/models.dart';

const ontongFetchedAt = {lit(data.get('fetchedAt'))};
"""
out = "\n".join([
    header,
    block("ontongStep3Programs", f"STEP 3 · 도전 목록 ({len(step3)}건, 마감 빠른 순)", step3),
    block("ontongDeadlinePrograms", f"알림 '마감 임박' ({len(deadline)}건)", deadline),
    block("ontongNewPrograms", f"알림 '새 소식' — 최근 등록 ({len(fresh)}건)", fresh),
])
DST.write_text(out, encoding="utf-8", newline="\n")

print(f"{DST.relative_to(ROOT)}: STEP3 {len(step3)} (전국·서울 {len(main)}, 그 외 {len(local)}) / "
      f"마감 임박 {len(deadline)} / 새 소식 {len(fresh)}  ({DST.stat().st_size // 1024}KB)")
print("STEP3 후보 전체:", len(by_views))
for p in step3:
    print(f"  {p['applyEnd']}  {p['provisionMethod']:<4} {p['category']:<8} {p['name'][:40]}")
print("마감 임박:", [(p["name"][:30], p["applyEnd"]) for p in deadline])
print("새 소식:", [(p["name"][:30], p["firstRegistered"]) for p in fresh])
