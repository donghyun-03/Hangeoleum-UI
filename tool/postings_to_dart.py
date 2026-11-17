"""crawl_postings.py 결과 JSON 들 → lib/data/posting_criteria_data.dart (앱에 넣을 공고 기준)

실행 (저장소 루트에서):
    python tool/postings_to_dart.py ../hangeoreum_data/postings
    python tool/postings_to_dart.py --empty        # 공고 기준을 모두 비우기 (러프 기준만 사용)

공고 본문·제목은 넣지 않고, 모아서 계산한 기준(학력·학점·어학·비율·키워드)과 원문 링크만 넣는다.
표준 라이브러리만 사용.
"""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DST = ROOT / "lib" / "data" / "posting_criteria_data.dart"
GROUPS = {"dev", "data", "design", "office", "marketing"}
EDU = {"none", "high", "college", "univ", "graduate"}
SOURCE_LABEL = {"saramin": "사람인"}
MAX_URLS = 5

HEADER = """// 자동 생성 파일 — tool/postings_to_dart.py 로 만듭니다. 직접 고치지 마세요.
// 관심기업 채용 공고에서 모은 지원 기준 (크롤링 버전). 비어 있으면 러프 기준만 씁니다.
// 공고 본문은 넣지 않고 기준 값과 원문 링크만 담습니다.
import '../models/criteria.dart';

"""


def s(v):
    """Dart 문자열 리터럴"""
    return "'" + str(v).replace("\\", "\\\\").replace("'", "\\'").replace("$", "\\$") + "'"


def str_list(xs):
    return "[" + ", ".join(s(x) for x in xs) + "]"


def entry(d):
    c = d["criteria"]
    group = d["group"]
    if group not in GROUPS:
        raise SystemExit(f"알 수 없는 직무 묶음: {group}")
    edu = c.get("education")
    lines = [
        f"    company: {s(d['company'])},",
        f"    job: {s(d.get('job', ''))},",
        f"    jobGroup: JobGroup.{group},",
        f"    source: {s(SOURCE_LABEL.get(d.get('source'), d.get('source', '')))},",
        f"    fetchedAt: {s(d['fetchedAt'])},",
        f"    postingCount: {int(c['postingCount'])},",
        f"    detailCount: {int(c.get('detailCount', 0))},",
    ]
    if edu in EDU:
        lines.append(f"    education: EduLevel.{edu},")
    if c.get("minGpa") is not None:
        lines.append(f"    minGpa: {float(c['minGpa'])},")
    if c.get("minEnglish") is not None:
        lines.append(f"    minEnglish: {int(c['minEnglish'])},")
    if c.get("englishPreferred"):
        lines.append("    englishPreferred: true,")
    lines += [
        f"    portfolioRate: {float(c.get('portfolioRate', 0))},",
        f"    teamworkRate: {float(c.get('teamworkRate', 0))},",
        f"    skills: {str_list(c.get('skills', []))},",
        f"    certificates: {str_list(c.get('certificates', []))},",
        f"    careers: {str_list(c.get('careers', []))},",
        f"    postingUrls: {str_list([p['url'] for p in d.get('postings', [])][:MAX_URLS])},",
    ]
    return "  PostingCriteria(\n" + "\n".join(lines) + "\n  ),\n"


def main(argv):
    entries = []
    if argv and argv[0] != "--empty":
        files = sorted(Path(argv[0]).glob("*.json"))
        if not files:
            raise SystemExit(f"{argv[0]} 에 JSON 이 없어요. 먼저 crawl_postings.py 를 실행하세요.")
        for f in files:
            d = json.loads(f.read_text(encoding="utf-8"))
            if d.get("criteria"):
                entries.append(entry(d))
    elif not argv:
        raise SystemExit("사용법: python tool/postings_to_dart.py <JSON 폴더> | --empty")

    body = "const kPostingCriteria = <PostingCriteria>[\n" + "".join(entries) + "];\n"
    DST.write_text(HEADER + body, encoding="utf-8")
    print(f"공고 기준 {len(entries)}개 → {DST.relative_to(ROOT)}")


if __name__ == "__main__":
    main(sys.argv[1:])
