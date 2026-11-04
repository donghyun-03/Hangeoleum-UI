// 프로그램 상세 — STEP 3·4 공고 카드, 스크랩 카드, 전체 탭 추천·검색, 기관 홈의 등록 프로그램을 누르면 진입
// 데이터 모양: hangeoreum_data/programs_ontong_v2.json (온통청년 → 한걸음 '프로그램' 테이블 v2) = models.dart 의 ProgramDetail
//
// 위:   요약 카드 (STEP·분류·모집 상태·이름·기관 + 한눈에 보기: 신청 기간 · 지역 · 나이 · 지원 방식)
//       한걸음 분류 (STEP·난이도·소요 시간·AI 확신도 — LLM 분류 값이 있을 때만)
// 가운데: 지원 내용 → 지원 대상(내 조건과 비교) → 신청 방법 → 기간 → 키워드 → 기타
// 아래:  출처·원문 링크 (온통청년 이용 조건: 출처와 원문 링크 표시) / 하단 고정: 신청하러 가기
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../data/mock_data.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

/// id(공고 id 또는 기관 등록 프로그램 id)로 상세를 찾습니다.
/// TODO(API): 서버에서 프로그램 상세 조회로 교체 (응답 → ProgramDetail.fromJson)
ProgramDetail? findProgramDetail(AppState state, String id) {
  if (mockProgramDetails[id] case final p?) return p;
  if (findOpportunity(id) case final o?) return ProgramDetail.fromOpportunity(o);
  for (final p in state.programs) {
    if (p.id == id) return ProgramDetail.fromRegistered(p);
  }
  return null;
}

class ProgramDetailScreen extends StatelessWidget {
  const ProgramDetailScreen({super.key, required this.programId});
  final String programId;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final p = findProgramDetail(state, programId);
    if (p == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('프로그램 상세')),
        body: const EmptyState(icon: Icons.search_off, title: '프로그램을 찾을 수 없어요', desc: '마감되었거나 삭제된 프로그램일 수 있어요.'),
      );
    }

    final today = DateUtils.dateOnly(DateTime.now());
    final closed = p.isClosedOn(today);
    final opportunity = findOpportunity(programId);
    final step = p.step ?? opportunity?.step;
    final scrapped = opportunity != null && state.isScrapped(programId);
    final registered = p.source == '기관';

    return Scaffold(
      appBar: AppBar(
        title: const Text('프로그램 상세'),
        actions: [
          // 스크랩은 STEP 3·4 공고만 (스크랩 탭이 공고 id 로 관리)
          if (opportunity != null)
            IconButton(
              tooltip: scrapped ? '스크랩 취소' : '스크랩',
              onPressed: () {
                state.toggleScrap(programId);
                showToast(context, scrapped ? '스크랩을 취소했어요' : '스크랩했어요. 스크랩 탭에서 모아 볼 수 있어요');
              },
              icon: Icon(scrapped ? Icons.bookmark : Icons.bookmark_border, color: scrapped ? AppColors.green : AppColors.muted),
            ),
        ],
      ),
      bottomNavigationBar: registered
          ? null
          : BottomBar(
              child: closed
                  ? const AppButton(label: '모집이 마감됐어요', onPressed: null)
                  : p.applyUrl == null
                      ? const AppButton(label: '아래 신청 방법을 확인해 주세요', onPressed: null)
                      : AppButton(
                          label: '신청하러 가기',
                          icon: Icons.open_in_new,
                          // TODO(url_launcher): 링크 열기. 패키지 추가 전까지는 복사
                          onPressed: () => _copyLink(context, p.applyUrl!, '신청 링크를 복사했어요. 브라우저에 붙여 넣어 열어 주세요'),
                        ),
            ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _Summary(p: p, step: step, today: today),
          if (p.hasServiceInfo) _ServiceInfo(p: p, step: step),
          if (closed)
            AppCard(
              color: AppColors.soft,
              child: Text(
                '모집이 끝난 프로그램이에요${p.closedReason != null ? ' (${p.closedReason})' : ''}. 비슷한 프로그램은 STEP 탭에서 찾아보세요.',
                style: AppText.small.copyWith(fontSize: 13),
              ),
            ),
          if (registered)
            AppCard(
              color: AppColors.soft,
              child: Text(
                '기관이 등록한 프로그램이에요. 검수가 끝나면 STEP ${step ?? ''}에 노출돼요.',
                style: AppText.small.copyWith(fontSize: 13),
              ),
            ),

          const SectionTitle('지원 내용'),
          if (p.content != null)
            _ExpandableText(p.content!)
          else ...[
            Text('상세 내용이 아직 없어요.', style: AppText.small),
            if (p.source == 'MOCK') const TodoBox('상세 데이터 연결 전 (STEP 3 은 온통청년, STEP 4 채용은 워크넷 API 예정)'),
          ],

          const SectionTitle('지원 대상'),
          if (state.user.role == UserRole.youth) _MyMatch(p: p, user: state.user),
          _Eligibility(p: p),

          if (p.applyMethod != null || p.screeningMethod != null || p.documents != null) ...[
            const SectionTitle('신청 방법'),
            if (p.applyMethod != null) _TextBlock('신청 방법', p.applyMethod!),
            if (p.screeningMethod != null) _TextBlock('심사 방법', p.screeningMethod!),
            if (p.documents != null) _TextBlock('제출 서류', p.documents!),
          ],

          const SectionTitle('기간'),
          _InfoRow('신청 기간', _applyPeriodLabel(p)),
          _InfoRow('사업 기간', _bizPeriodLabel(p)),

          if (p.keywords.isNotEmpty || p.subCategories.isNotEmpty) ...[
            const SectionTitle('키워드'),
            ChipWrap(children: [
              for (final c in p.subCategories) TagBadge(c, tone: BadgeTone.green),
              for (final k in p.keywords) TagBadge('#$k', tone: BadgeTone.gray),
            ]),
          ],

          if (p.etc != null) ...[
            const SectionTitle('기타'),
            Text(p.etc!, style: _bodyText),
          ],

          _SourceFooter(p: p),
        ],
      ),
    );
  }
}

// ───────────────────────── 위: 요약 카드

class _Summary extends StatelessWidget {
  const _Summary({required this.p, required this.step, required this.today});
  final ProgramDetail p;
  final int? step;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final (statusText, statusTone) = _status(p, today);
    final categoryLine = [
      if (p.category != null) p.category!,
      if (p.subCategory != null && p.subCategory != p.category) p.subCategory!,
    ].join(' › ');
    final orgLine = [
      if (p.organization != null) p.organization!,
      if (p.supervisingOrg != null && p.supervisingOrg != p.organization) '주관 ${p.supervisingOrg}',
    ].join(' · ');
    final tags = [
      if (p.providerGroup != null) p.providerGroup!,
      if (p.provisionMethod != null) p.provisionMethod!,
    ];

    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: 6, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
          if (step != null) TagBadge('STEP $step', tone: BadgeTone.dark),
          TagBadge(statusText, tone: statusTone),
          if (categoryLine.isNotEmpty) Text(categoryLine, style: AppText.caption.copyWith(fontSize: 11)),
        ]),
        const SizedBox(height: 8),
        Text(p.name, style: AppText.h2),
        if (orgLine.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(orgLine, style: AppText.small),
        ],
        if (tags.isNotEmpty) ...[
          const SizedBox(height: 10),
          ChipWrap(children: [for (final t in tags) TagBadge(t, tone: BadgeTone.gray)]),
        ],
        const SizedBox(height: 14),
        const Divider(),
        const SizedBox(height: 12),
        // 한눈에 보기 (2 × 2)
        Row(children: [
          Expanded(child: _Quick(icon: Icons.event_outlined, label: '신청 기간', value: _applyShort(p))),
          Expanded(child: _Quick(icon: Icons.place_outlined, label: '지역', value: p.regionLabel)),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _Quick(icon: Icons.person_outline, label: '나이', value: p.ageLabel)),
          Expanded(child: _Quick(icon: Icons.card_giftcard_outlined, label: '지원 방식', value: p.provisionMethod ?? p.category ?? '-')),
        ]),
      ]),
    );
  }
}

class _Quick extends StatelessWidget {
  const _Quick({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, size: 17, color: AppColors.subtle),
      const SizedBox(width: 6),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: AppText.caption.copyWith(fontSize: 11)),
          Text(value, style: AppText.bodyBold.copyWith(fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
        ]),
      ),
    ]);
  }
}

/// 한걸음 분류 (LLM 이 채우는 STEP·난이도·소요 시간·AI 확신도 + 검수 상태)
class _ServiceInfo extends StatelessWidget {
  const _ServiceInfo({required this.p, required this.step});
  final ProgramDetail p;
  final int? step;

  @override
  Widget build(BuildContext context) {
    final items = [
      if (step != null) 'STEP $step',
      if (p.difficulty != null) '난이도 ${p.difficulty}',
      if (p.durationMinutes != null) '약 ${_minutes(p.durationMinutes!)}',
      if (p.aiConfidence != null) 'AI 확신도 ${(p.aiConfidence! * 100).round()}%',
    ];
    final reviewed = p.reviewStatus == '검수 완료';

    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.auto_awesome, size: 16, color: AppColors.green),
          const SizedBox(width: 6),
          Expanded(child: Text('한걸음 분류', style: AppText.bodyBold.copyWith(fontSize: 13))),
          if (p.reviewStatus != null) TagBadge(p.reviewStatus!, tone: reviewed ? BadgeTone.green : BadgeTone.amber),
        ]),
        const SizedBox(height: 6),
        Text(items.join('  ·  '), style: AppText.small.copyWith(color: AppColors.ink)),
      ]),
    );
  }
}

// ───────────────────────── 가운데

const _bodyText = TextStyle(fontFamily: 'Pretendard', fontSize: 13.5, height: 1.65, color: AppColors.ink);

/// 긴 설명은 접어 두고 '더보기'로 펼침
class _ExpandableText extends StatefulWidget {
  const _ExpandableText(this.text);
  final String text;

  @override
  State<_ExpandableText> createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<_ExpandableText> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final long = widget.text.length > 200 || '\n'.allMatches(widget.text).length > 6;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(
        widget.text,
        style: _bodyText,
        maxLines: long && !_open ? 7 : null,
        overflow: long && !_open ? TextOverflow.ellipsis : null,
      ),
      if (long)
        TextButton(
          onPressed: () => setState(() => _open = !_open),
          style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 32)),
          child: Text(_open ? '접기' : '더보기', style: AppText.caption.copyWith(fontSize: 12.5, color: AppColors.green)),
        ),
    ]);
  }
}

/// 내 조건(나이·지역)으로 보면 맞는지 — 청년 사용자만
class _MyMatch extends StatelessWidget {
  const _MyMatch({required this.p, required this.user});
  final ProgramDetail p;
  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final myRegion = user.address.split(' ').first;
    final region = p.regionMatches(user.address);
    return AppCard(
      color: AppColors.greenLight,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('내 조건으로 보면', style: AppText.bodyBold.copyWith(fontSize: 13, color: AppColors.greenDark)),
        const SizedBox(height: 6),
        _MatchLine(ok: p.ageMatches(user.age), text: '나이 · 만 ${user.age}세'),
        _MatchLine(ok: region, text: '지역 · $myRegion'),
        const SizedBox(height: 4),
        Text('나이·지역만 비교했어요. 정확한 자격은 원문에서 꼭 확인해 주세요.', style: AppText.caption.copyWith(fontSize: 11)),
      ]),
    );
  }
}

class _MatchLine extends StatelessWidget {
  const _MatchLine({required this.ok, required this.text});

  /// null = 판단할 수 없음
  final bool? ok;
  final String text;

  @override
  Widget build(BuildContext context) {
    final (icon, color, result) = switch (ok) {
      true => (Icons.check_circle, AppColors.green, '해당돼요'),
      false => (Icons.cancel, AppColors.red, '조건과 달라요'),
      null => (Icons.help_outline, AppColors.subtle, '확인이 필요해요'),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Expanded(child: Text(text, style: AppText.body.copyWith(fontSize: 13))),
        Text(result, style: AppText.small.copyWith(fontSize: 12, color: color, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

/// 자격 조건 표. 빈 배열·null 은 '제한 없음'으로 한 줄에 모아 보여 줌
class _Eligibility extends StatelessWidget {
  const _Eligibility({required this.p});
  final ProgramDetail p;

  @override
  Widget build(BuildContext context) {
    String? list(List<String> v) => v.isEmpty ? null : v.join(', ');
    final conditional = <(String, String?)>[
      ('취업 상태', list(p.jobConditions)),
      ('학력', list(p.educationConditions)),
      ('전공', list(p.majorConditions)),
      ('특화 분야', list(p.specialConditions)),
      ('혼인', p.marriageCondition),
      ('소득', _incomeLabel(p)),
    ];
    final free = [for (final (label, v) in conditional) if (v == null) label];

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _InfoRow('나이', p.ageLabel),
      _InfoRow('지역', p.isNationwide || p.regionNames.length <= 3 ? p.regionLabel : p.regionNames.join(', ')),
      for (final (label, v) in conditional)
        if (v != null) _InfoRow(label, v),
      if (free.isNotEmpty) _InfoRow('제한 없음', free.join(' · '), muted: true),
      if (p.extraEligibility != null) _TextBlock('추가 자격', p.extraEligibility!),
      if (p.excludedTargets != null) _TextBlock('참여 제한 대상', p.excludedTargets!, warn: true),
    ]);
  }
}

/// 짧은 값: 왼쪽 라벨 + 오른쪽 값
class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value, {this.muted = false});
  final String label;
  final String value;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 76, child: Text(label, style: AppText.small.copyWith(fontSize: 12.5))),
        Expanded(
          child: Text(value, style: AppText.body.copyWith(fontSize: 13.5, color: muted ? AppColors.muted : AppColors.ink)),
        ),
      ]),
    );
  }
}

/// 긴 값: 위에 라벨, 아래 본문 (신청 방법, 추가 자격 등 자유 서술)
class _TextBlock extends StatelessWidget {
  const _TextBlock(this.label, this.text, {this.warn = false});
  final String label;
  final String text;
  final bool warn;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: AppText.small.copyWith(fontSize: 12.5, color: warn ? AppColors.red : AppColors.muted)),
        const SizedBox(height: 2),
        Text(text, style: _bodyText),
      ]),
    );
  }
}

// ───────────────────────── 아래: 출처

class _SourceFooter extends StatelessWidget {
  const _SourceFooter({required this.p});
  final ProgramDetail p;

  @override
  Widget build(BuildContext context) {
    final modified = p.lastModified;
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Divider(),
        const SizedBox(height: 12),
        Text(
          [
            '출처 ${p.sourceName}',
            if (p.originalId != null) '정책번호 ${p.originalId}',
            if (modified != null) '최종 수정 ${modified.length >= 10 ? modified.substring(0, 10) : modified}',
          ].join(' · '),
          style: AppText.caption,
        ),
        for (final url in p.refUrls)
          InkWell(
            onTap: () => _copyLink(context, url, '원문 링크를 복사했어요'),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(children: [
                const Icon(Icons.link, size: 15, color: AppColors.muted),
                const SizedBox(width: 6),
                Expanded(
                  child: Text('원문 보기 · $url',
                      style: AppText.caption.copyWith(color: AppColors.muted, decoration: TextDecoration.underline),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ),
              ]),
            ),
          ),
      ]),
    );
  }
}

// ───────────────────────── 도우미

Future<void> _copyLink(BuildContext context, String url, String message) async {
  await Clipboard.setData(ClipboardData(text: url));
  if (context.mounted) showToast(context, message);
}

/// 모집 상태 배지
(String, BadgeTone) _status(ProgramDetail p, DateTime today) {
  if (p.isClosedOn(today)) return ('마감', BadgeTone.gray);
  if (p.isUpcomingOn(today)) return ('모집 예정', BadgeTone.amber);
  if (p.applyPeriodType == '상시') return ('상시 모집', BadgeTone.green);
  final d = p.ddayOn(today);
  if (d == null) return ('모집 중', BadgeTone.green);
  if (d == 0) return ('오늘 마감', BadgeTone.red);
  return ('D-$d', d <= 7 ? BadgeTone.red : BadgeTone.green);
}

/// '2026-11-08' → '2026.11.08' (날짜 형식이 아니면 그대로)
String _dot(String? ymd) => ymd == null ? '' : ymd.replaceAll('-', '.');

/// '2026-11-08' → '11.08'
String _md(String ymd) => ymd.length == 10 ? ymd.substring(5).replaceAll('-', '.') : ymd;

String _applyShort(ProgramDetail p) => switch (p.applyPeriodType) {
      '상시' => '상시 모집',
      '마감' => '마감',
      _ when p.applyEnd != null => '~ ${_md(p.applyEnd!)}',
      _ => '-',
    };

String _applyPeriodLabel(ProgramDetail p) => switch (p.applyPeriodType) {
      '상시' => '상시 모집',
      '마감' => '마감',
      _ when p.applyStart != null || p.applyEnd != null => '${_dot(p.applyStart)} ~ ${_dot(p.applyEnd)}'.trim(),
      _ => '정보 없음',
    };

String _bizPeriodLabel(ProgramDetail p) {
  if (p.bizStart != null || p.bizEnd != null) {
    final range = '${_dot(p.bizStart)} ~ ${_dot(p.bizEnd)}'.trim();
    return p.bizPeriodText == null ? range : '$range\n${p.bizPeriodText}';
  }
  return p.bizPeriodText ?? '정보 없음';
}

String? _incomeLabel(ProgramDetail p) {
  final type = p.incomeConditionType;
  if (type == null || type == '무관') return null;
  if (type != '연소득') return p.incomeConditionText ?? type;
  // TODO(데이터): 온통청년 소득 금액 단위(만원) 확인
  final low = p.incomeMin, high = p.incomeMax;
  final range = [
    if (low != null) '${_comma(low)}만원 이상',
    if (high != null) '${_comma(high)}만원 이하',
  ].join(' ~ ');
  return range.isEmpty ? (p.incomeConditionText ?? '연소득 조건 있음') : '연소득 $range';
}

String _comma(int n) => n.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');

String _minutes(int m) => m < 60 ? '$m분' : (m % 60 == 0 ? '${m ~/ 60}시간' : '${m ~/ 60}시간 ${m % 60}분');
