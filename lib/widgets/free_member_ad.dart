import 'dart:async';
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../app/theme.dart';

/// Membership must resolve before showing a promotion. Paid members stay ad-free.
class FreeMemberAd extends StatelessWidget {
  final Stream<UserModel?> users;
  final String uid;
  final VoidCallback onViewPlans;

  const FreeMemberAd({
    super.key,
    required this.users,
    required this.uid,
    required this.onViewPlans,
  });

  @override
  Widget build(BuildContext context) => StreamBuilder<UserModel?>(
    stream: users,
    builder: (context, snapshot) {
      final user = snapshot.data;
      if (snapshot.hasError ||
          snapshot.connectionState == ConnectionState.waiting ||
          user == null ||
          user.uid != uid) {
        return const SizedBox.shrink();
      }
      return _MembershipPlacement(
        key: ValueKey(user.uid),
        user: user,
        onViewPlans: onViewPlans,
      );
    },
  );
}

class _MembershipPlacement extends StatefulWidget {
  final UserModel user;
  final VoidCallback onViewPlans;
  const _MembershipPlacement({
    super.key,
    required this.user,
    required this.onViewPlans,
  });
  @override
  State<_MembershipPlacement> createState() => _MembershipPlacementState();
}

class _MembershipPlacementState extends State<_MembershipPlacement>
    with WidgetsBindingObserver {
  Timer? _expiry;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _schedule();
  }

  @override
  void didUpdateWidget(covariant _MembershipPlacement oldWidget) {
    super.didUpdateWidget(oldWidget);
    _schedule();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) setState(_schedule);
  }

  void _schedule() {
    _expiry?.cancel();
    final expiry = widget.user.membershipExpiresAt;
    if (expiry != null) {
      _expiry = Timer(
        expiry.difference(DateTime.now()) + const Duration(milliseconds: 50),
        () {
          if (mounted) setState(_schedule);
        },
      );
    }
  }

  @override
  void dispose() {
    _expiry?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.user.membershipTier != 'free') return const SizedBox.shrink();
    return SafeArea(
      top: false,
      child: Material(
        color: AppColors.surfaceSoft,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 4,
            children: [
              const Text('廣告・PAWLINK 自家推廣', style: TextStyle(fontSize: 11)),
              const Text('Plus / Pro 享無廣告體驗'),
              TextButton(
                onPressed: widget.onViewPlans,
                child: const Text('查看方案'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
