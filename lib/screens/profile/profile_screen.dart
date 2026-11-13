// 내 정보 — 보기 화면 (팀원 프로필과 같은 구성). 연필 버튼으로 내 정보 수정 화면 이동
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../router/routes.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../models/models.dart';
import 'profile_edit_screen.dart';

class _GpaFormatter extends TextInputFormatter {
  _GpaFormatter(this.max);
  final double max;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final t = newValue.text;
    if (t.isEmpty) return newValue;
    if (!RegExp(r'^\d(\.\d{0,2})?$').hasMatch(t)) return oldValue;
    final v = double.tryParse(t);
    if (v != null && v > max) return oldValue;
    return newValue;
  }
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Future<void> _editIntro(String current) async {
    final ctrl = TextEditingController(text: current);
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.paper,
        surfaceTintColor: AppColors.paper,
        title: Text('소개 수정', style: AppText.title),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(hintText: '간단한 소개를 적어 주세요'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('취소', style: TextStyle(color: AppColors.subtle)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, ctrl.text.trim()),
            child: const Text('저장', style: TextStyle(color: AppColors.green)),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (result == null || !mounted) return;
    context.read<AppState>().updateUser((u) => u.copyWith(intro: result));
  }

  Future<void> _pickScale(BuildContext fieldContext) async {
    final field = fieldContext.findRenderObject() as RenderBox;
    final overlay =
        Overlay.of(fieldContext).context.findRenderObject() as RenderBox;
    final origin = field.localToGlobal(Offset.zero, ancestor: overlay);
    final top = origin.dy + field.size.height + 4;
    const options = [4.0, 4.3, 4.5];
    final selected = await showGeneralDialog<double>(
      context: context,
      useRootNavigator: false,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: AppColors.ink.withValues(alpha: 0),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (menuContext, animation, secondaryAnimation) {
        return Material(
          color: AppColors.paper,
          surfaceTintColor: AppColors.paper,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            side: const BorderSide(color: AppColors.line),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final s in options)
                InkWell(
                  onTap: () => Navigator.of(menuContext).pop(s),
                  child: SizedBox(
                    height: 40,
                    width: double.infinity,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          '$s',
                          style: AppText.body.copyWith(fontSize: 14),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curve = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return Stack(
          children: [
            Positioned(
              left: origin.dx,
              top: top,
              width: 72,
              child: SizeTransition(
                sizeFactor: curve,
                alignment: Alignment.center,
                child: FadeTransition(opacity: animation, child: child),
              ),
            ),
          ],
        );
      },
    );
    if (selected == null || !mounted) return;
    final g = context.read<AppState>().user.gpa;
    context.read<AppState>().updateUser(
      (x) => x.copyWith(
        gpaScale: selected,
        gpa: (g != null && g > selected) ? selected : g,
      ),
    );
  }

  Future<void> _addLanguage() async {
    const exams = [
      'TOEIC',
      'TOEIC Speaking',
      'OPIc',
      'TOEFL',
      'JLPT',
      'HSK',
      '기타',
    ];
    final scoreCtrl = TextEditingController();
    final yearCtrl = TextEditingController();
    String? exam;
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          backgroundColor: AppColors.paper,
          surfaceTintColor: AppColors.paper,
          title: Text('어학 추가', style: AppText.title),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('시험 종류', style: AppText.small.copyWith(fontSize: 12)),
                const SizedBox(height: 6),
                ChipWrap(
                  children: [
                    for (final e in exams)
                      SelectChip(
                        label: e,
                        selected: exam == e,
                        onTap: () => setLocal(() => exam = e),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text('점수 · 등급', style: AppText.small.copyWith(fontSize: 12)),
                const SizedBox(height: 6),
                TextField(
                  controller: scoreCtrl,
                  decoration: const InputDecoration(hintText: '예: 850, IH, N2'),
                ),
                const SizedBox(height: 12),
                Text('취득 연도 (선택)', style: AppText.small.copyWith(fontSize: 12)),
                const SizedBox(height: 6),
                TextField(
                  controller: yearCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(4),
                  ],
                  decoration: const InputDecoration(hintText: '예: 2025'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text(
                '취소',
                style: TextStyle(color: AppColors.subtle),
              ),
            ),
            TextButton(
              onPressed: () {
                if (exam == null || scoreCtrl.text.trim().isEmpty) return;
                Navigator.pop(dialogContext, true);
              },
              child: const Text('추가', style: TextStyle(color: AppColors.green)),
            ),
          ],
        ),
      ),
    );
    final score = scoreCtrl.text.trim();
    final year = int.tryParse(yearCtrl.text);
    scoreCtrl.dispose();
    yearCtrl.dispose();
    if (saved != true || exam == null || !mounted) return;
    context.read<AppState>().updateUser(
      (u) => u.copyWith(
        languages: [
          ...u.languages,
          LanguageScore(exam: exam!, score: score, year: year),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final u = state.user;

    final myId = u.id; // 내 ID
    final intro = u.intro.isEmpty ? '안녕하세요, ${u.name}입니다.' : u.intro;

    final missions = state.doneMissionsOf(myId);
    final records = state.recordsOf(myId);
    final posts = state.teamPosts
        .where((p) => p.leaderId == myId || p.memberIds.contains(myId))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('내 정보'),
        actions: [
          TextButton(
            onPressed: () {
              context.read<AppState>().logout();
              AppNav.resetTo(context, Routes.login);
            },
            child: const Text(
              '로그아웃',
              style: TextStyle(fontSize: 12.5, color: AppColors.subtle),
            ),
          ),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: FloatingActionButton(
          tooltip: '내 정보 수정',
          backgroundColor: AppColors.green,
          foregroundColor: AppColors.paper,
          elevation: 2,
          shape: const CircleBorder(),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ProfileEditScreen()),
          ),
          child: const Icon(Icons.edit_outlined),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(child: Avatar(name: u.name, size: 72)),
          const SizedBox(height: 10),
          Center(child: Text(u.name, style: AppText.h2)),
          InkWell(
            borderRadius: BorderRadius.circular(AppRadius.md),
            onTap: () => _editIntro(intro),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      intro,
                      style: AppText.small.copyWith(fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(
                    Icons.edit_outlined,
                    size: 14,
                    color: AppColors.subtle,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                _StatButton(
                  n: missions.length,
                  label: '완료한 미션',
                  onTap: () => AppNav.toMemberActivity(context, myId),
                ),
                _StatButton(
                  n: records.length,
                  label: '활동 기록',
                  onTap: () => AppNav.toMemberActivity(context, myId, tab: 1),
                ),
              ],
            ),
          ),
          const SectionTitle('성적'),
          Row(
            children: [
              SizedBox(
                width: 72,
                child: TextFormField(
                  key: ValueKey(u.gpaScale),
                  initialValue: u.gpa == null ? '' : '${u.gpa}',
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [_GpaFormatter(u.gpaScale)],
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14),
                  decoration: const InputDecoration(
                    hintText: '본인 학점',
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 2,
                      vertical: 9,
                    ),
                  ),
                  onChanged: (v) => context.read<AppState>().updateUser(
                    (x) => x.copyWith(gpa: double.tryParse(v)),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text('/', style: AppText.body),
              ),
              Builder(
                builder: (fieldContext) => InkWell(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  onTap: () => _pickScale(fieldContext),
                  child: SizedBox(
                    width: 44,
                    height: 32,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${u.gpaScale}',
                          style: AppText.bodyBold.copyWith(fontSize: 15),
                        ),
                        const Icon(
                          Icons.expand_more,
                          size: 14,
                          color: AppColors.muted,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SectionTitle('어학'),
          ChipWrap(
            children: [
              for (var i = 0; i < u.languages.length; i++)
                InputChip(
                  label: Text(
                    '${u.languages[i].exam} ${u.languages[i].score}'
                    '${u.languages[i].year == null ? '' : ' (${u.languages[i].year})'}',
                    style: AppText.body.copyWith(fontSize: 12.5),
                  ),
                  backgroundColor: AppColors.soft,
                  side: BorderSide.none,
                  deleteIconColor: AppColors.subtle,
                  onDeleted: () => context.read<AppState>().updateUser(
                    (x) => x.copyWith(languages: [...x.languages]..removeAt(i)),
                  ),
                ),
              ActionChip(
                label: Text(
                  '+ 추가',
                  style: AppText.body.copyWith(
                    fontSize: 12.5,
                    color: AppColors.green,
                  ),
                ),
                backgroundColor: AppColors.paper,
                side: const BorderSide(color: AppColors.greenLine),
                onPressed: _addLanguage,
              ),
            ],
          ),
          const SectionTitle('관심 분야'),
          if (u.interests.isEmpty)
            Text(
              '선택한 관심 분야가 없어요.',
              style: AppText.caption.copyWith(fontSize: 12.5),
            )
          else
            ChipWrap(
              children: [
                for (final i in u.interests) TagBadge(i, tone: BadgeTone.gray),
              ],
            ),
          const SizedBox(height: 16),
          const Divider(),
          const SectionTitle('참여 중인 프로젝트'),
          if (posts.isEmpty)
            Text(
              '참여 중인 프로젝트가 없어요.',
              style: AppText.caption.copyWith(fontSize: 12.5),
            ),

          for (final p in posts)
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${p.category} · ${p.current}/${p.max}명',
                    style: AppText.caption.copyWith(fontSize: 11),
                  ),
                  const SizedBox(height: 4),
                  Text(p.title, style: AppText.bodyBold),
                  const SizedBox(height: 8),
                  AppButton(
                    label: '모집 글 보기',
                    small: true,
                    expand: false,
                    onPressed: () => AppNav.toTeamApply(context, p.id),
                  ),
                ],
              ),
            ),
          const SectionTitle('최근 활동 기록'),
          if (records.isEmpty)
            Text(
              '아직 활동 기록이 없어요.',
              style: AppText.caption.copyWith(fontSize: 12.5),
            ),
          for (final r in records.take(2))
            AppCard(
              onTap: () => AppNav.toMemberActivity(context, myId, tab: 1),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      TagBadge('STEP ${r.step}', tone: BadgeTone.gray),
                      const SizedBox(width: 6),
                      Text(
                        r.date,
                        style: AppText.caption.copyWith(fontSize: 11),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(r.title, style: AppText.bodyBold),
                  Text(
                    r.star.r,
                    style: AppText.small.copyWith(fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _StatButton extends StatelessWidget {
  const _StatButton({required this.n, required this.label, this.onTap});
  final int n;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            children: [
              Text('$n', style: AppText.h2.copyWith(color: AppColors.green)),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label, style: AppText.caption.copyWith(fontSize: 11)),
                  if (onTap != null)
                    const Icon(
                      Icons.chevron_right,
                      size: 13,
                      color: AppColors.subtle,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
