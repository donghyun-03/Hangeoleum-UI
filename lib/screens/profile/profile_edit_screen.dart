// 내 정보 수정 — 기본 정보 수정, 관심 분야, 맞춤 알림
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/mock_data.dart';
import '../../models/models.dart';
import '../../router/routes.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

const _alertLabels = {
  'policy': '정책',
  'camp': '캠프',
  'saving': '청년 적금',
  'project': '프로젝트',
};

class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  late AppUser _u = context.read<AppState>().user;

  void _save() {
    // TODO(API): 내 정보 수정
    context.read<AppState>().updateUser((_) => _u);
    showToast(context, '저장했어요');
  }

  Widget _row(Widget a, Widget b, {int flexA = 1}) => Row(
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      Expanded(flex: flexA, child: a),
      const SizedBox(width: 10),
      Expanded(child: b),
    ],
  );

  Widget _alertBox(String key) {
    final on = _u.alerts[key] ?? false;
    return Container(
      height: 44,
      padding: const EdgeInsets.only(left: 14, right: 6),
      decoration: BoxDecoration(
        color: AppColors.soft,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _alertLabels[key]!,
              style: AppText.bodyBold.copyWith(
                fontSize: 13,
                color: on ? AppColors.ink : AppColors.subtle,
              ),
            ),
          ),
          Transform.scale(
            scale: 0.8,
            child: Switch(
              value: on,
              onChanged: (v) => setState(
                () => _u = _u.copyWith(alerts: {..._u.alerts, key: v}),
              ),
              activeTrackColor: AppColors.green,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEducationField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('학력', style: AppText.small.copyWith(fontSize: 12)),
        const SizedBox(height: 4),
        Builder(
          builder: (fieldContext) {
            return InkWell(
              onTap: () async {
                final field = fieldContext.findRenderObject() as RenderBox;
                final overlay =
                    Overlay.of(fieldContext).context.findRenderObject()
                        as RenderBox;
                final origin = field.localToGlobal(
                  Offset.zero,
                  ancestor: overlay,
                );
                final media = MediaQuery.of(fieldContext);
                final top = origin.dy + field.size.height + 4;
                final bottom =
                    overlay.size.height -
                    media.viewInsets.bottom -
                    media.padding.bottom -
                    8;
                final height = (bottom - top).clamp(0.0, 192.0).toDouble();
                if (height < 48) return;
                final selected = await showGeneralDialog<Education>(
                  context: context,
                  useRootNavigator: false,
                  barrierDismissible: true,
                  barrierLabel: MaterialLocalizations.of(
                    context,
                  ).modalBarrierDismissLabel,
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
                      child: SizedBox(
                        height: height,
                        child: ListView.builder(
                          primary: false,
                          padding: EdgeInsets.zero,
                          itemExtent: 48,
                          itemCount: Education.values.length,
                          itemBuilder: (context, index) {
                            final option = Education.values[index];
                            return InkWell(
                              onTap: () =>
                                  Navigator.of(menuContext).pop(option),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    option.label,
                                    style: AppText.body.copyWith(fontSize: 14),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  },
                  transitionBuilder:
                      (context, animation, secondaryAnimation, child) {
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
                              width: field.size.width,
                              child: SizeTransition(
                                sizeFactor: curve,
                                alignment: Alignment.center,
                                child: FadeTransition(
                                  opacity: animation,
                                  child: child,
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                );
                if (!mounted || selected == null) return;
                setState(() => _u = _u.copyWith(education: selected.label));
              },
              child: InputDecorator(
                isEmpty: _u.education.isEmpty,
                decoration: const InputDecoration(),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _u.education.isEmpty ? '선택' : _u.education,
                        style: _u.education.isEmpty
                            ? AppText.body
                                  .copyWith(fontSize: 14)
                                  .merge(
                                    Theme.of(
                                      context,
                                    ).inputDecorationTheme.hintStyle,
                                  )
                            : AppText.body.copyWith(fontSize: 14),
                      ),
                    ),
                    const Icon(Icons.expand_more, color: AppColors.muted),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('내 정보 수정'),
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
      bottomNavigationBar: BottomBar(
        child: AppButton(label: '저장하기', onPressed: _save),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              Avatar(name: _u.name, size: 44, color: AppColors.dim),
              const SizedBox(width: 10),
              Text(_u.email, style: AppText.body),
            ],
          ),
          const SizedBox(height: 16),
          _row(
            LabeledField(
              label: '이름',
              initialValue: _u.name,
              onChanged: (v) => _u = _u.copyWith(name: v),
            ),
            LabeledField(
              label: '나이',
              initialValue: _u.age == 0 ? '' : '${_u.age}',
              keyboardType: TextInputType.number,
              onChanged: (v) => _u = _u.copyWith(age: int.tryParse(v) ?? 0),
            ),
            flexA: 2,
          ),
          const SizedBox(height: 12),
          _row(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('성별', style: AppText.small.copyWith(fontSize: 12)),
                const SizedBox(height: 6),
                Segmented<String>(
                  value: _u.gender,
                  onChanged: (v) => setState(() => _u = _u.copyWith(gender: v)),
                  options: const [('female', '여성'), ('male', '남성')],
                ),
              ],
            ),
            LabeledField(
              label: '연락처',
              initialValue: _u.phone,
              onChanged: (v) => _u = _u.copyWith(phone: v),
            ),
          ),
          const SizedBox(height: 12),
          _row(
            LabeledField(
              label: '학부',
              initialValue: _u.major,
              onChanged: (v) => _u = _u.copyWith(major: v),
            ),
            _buildEducationField(),
          ),
          const SizedBox(height: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('주소', style: AppText.small.copyWith(fontSize: 12)),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      initialValue: _u.address,
                      onChanged: (v) => _u = _u.copyWith(address: v),
                      style: const TextStyle(fontSize: 14),
                      decoration: const InputDecoration(hintText: '주소 검색'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Material(
                    color: AppColors.bg,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      side: const BorderSide(color: AppColors.line),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      onTap: () {},
                      child: SizedBox(
                        width: 64,
                        height: 48,
                        child: Center(
                          child: Text(
                            '검색',
                            style: AppText.body.copyWith(
                              fontSize: 14,
                              color: AppColors.ink,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          LabeledField(
            hint: '상세 주소',
            initialValue: _u.addressDetail,
            onChanged: (v) => _u = _u.copyWith(addressDetail: v),
          ),
          const SectionTitle('관심 분야'),
          ChipWrap(
            children: [
              for (final i in interestOptions)
                SelectChip(
                  label: i,
                  selected: _u.interests.contains(i),
                  onTap: () => setState(
                    () => _u = _u.copyWith(
                      interests: _u.interests.contains(i)
                          ? (_u.interests.where((x) => x != i).toList())
                          : [..._u.interests, i],
                    ),
                  ),
                ),
            ],
          ),
          const SectionTitle('맞춤 알림'),
          Row(
            children: [
              Expanded(child: _alertBox('policy')),
              const SizedBox(width: 10),
              Expanded(child: _alertBox('camp')),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _alertBox('saving')),
              const SizedBox(width: 10),
              Expanded(child: _alertBox('project')),
            ],
          ),
        ],
      ),
    );
  }
}
