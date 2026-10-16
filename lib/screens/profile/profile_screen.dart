// 내 정보 — 기본 정보 수정, 관심 분야, 맞춤 알림
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/mock_data.dart';
import '../../models/models.dart';
import '../../router/routes.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

const _alertLabels = {'policy': '정책', 'camp': '캠프', 'saving': '청년 적금', 'project': '프로젝트'};

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late AppUser _u = context.read<AppState>().user;

  void _save() {
    // TODO(API): 내 정보 수정
    context.read<AppState>().updateUser((_) => _u);
    showToast(context, '저장했어요');
  }

  Widget _row(Widget a, Widget b, {int flexA = 1}) =>
      Row(crossAxisAlignment: CrossAxisAlignment.end, children: [Expanded(flex: flexA, child: a), const SizedBox(width: 10), Expanded(child: b)]);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('내 정보'),
        actions: [
          TextButton(
            onPressed: () {
              context.read<AppState>().logout();
              AppNav.resetTo(context, Routes.login);
            },
            child: const Text('로그아웃', style: TextStyle(fontSize: 12.5, color: AppColors.subtle)),
          ),
        ],
      ),
      bottomNavigationBar: BottomBar(child: AppButton(label: '저장하기', onPressed: _save)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(children: [
            Avatar(name: _u.name, size: 44, color: AppColors.dim),
            const SizedBox(width: 10),
            Text(_u.email, style: AppText.body),
          ]),
          const SizedBox(height: 16),
          _row(
            LabeledField(label: '이름', initialValue: _u.name, onChanged: (v) => _u = _u.copyWith(name: v)),
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
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('성별', style: AppText.small.copyWith(fontSize: 12)),
              const SizedBox(height: 6),
              Segmented<String>(
                value: _u.gender,
                onChanged: (v) => setState(() => _u = _u.copyWith(gender: v)),
                options: const [('female', '여성'), ('male', '남성')],
              ),
            ]),
            LabeledField(label: '연락처', initialValue: _u.phone, onChanged: (v) => _u = _u.copyWith(phone: v)),
          ),
          const SizedBox(height: 12),
          _row(
            LabeledField(label: '학부', initialValue: _u.major, onChanged: (v) => _u = _u.copyWith(major: v)),
            LabeledField(label: '학력', initialValue: _u.education, onChanged: (v) => _u = _u.copyWith(education: v)),
          ),
          const SizedBox(height: 12),
          LabeledField(label: '주소', initialValue: _u.address, onChanged: (v) => _u = _u.copyWith(address: v)),
          const SizedBox(height: 8),
          LabeledField(hint: '상세 주소', initialValue: _u.addressDetail, onChanged: (v) => _u = _u.copyWith(addressDetail: v)),
          const SectionTitle('관심 분야'),
          ChipWrap(children: [
            for (final i in interestOptions)
              SelectChip(
                label: i,
                selected: _u.interests.contains(i),
                onTap: () => setState(() => _u = _u.copyWith(
                      interests: _u.interests.contains(i) ? (_u.interests.where((x) => x != i).toList()) : [..._u.interests, i],
                    )),
              ),
          ]),
          const SectionTitle('맞춤 알림'),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Column(children: [
              for (final e in _alertLabels.entries)
                SwitchListTile(
                  value: _u.alerts[e.key] ?? false,
                  onChanged: (v) => setState(() => _u = _u.copyWith(alerts: {..._u.alerts, e.key: v})),
                  title: Text(e.value, style: AppText.body.copyWith(fontSize: 13.5)),
                  activeTrackColor: AppColors.green,
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
            ]),
          ),
        ],
      ),
    );
  }
}
