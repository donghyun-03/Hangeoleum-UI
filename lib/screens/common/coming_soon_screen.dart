// 아직 만들지 않은 화면 자리.  AppNav.toComingSoon(context, '화면 이름');
import 'package:flutter/material.dart';

import '../../widgets/common.dart';

class ComingSoonScreen extends StatelessWidget {
  const ComingSoonScreen({super.key, required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title, overflow: TextOverflow.ellipsis)),
      body: const EmptyState(
        icon: Icons.construction_outlined,
        title: '준비 중인 화면이에요',
        desc: '디자인이 정해지면 이 자리에 화면을 만들어 주세요.',
      ),
    );
  }
}
