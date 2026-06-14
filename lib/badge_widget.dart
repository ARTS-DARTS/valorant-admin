import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'badge_service.dart';

class BadgeRow extends StatelessWidget {
  final List<UserBadge> badges;
  final double size;

  const BadgeRow({super.key, required this.badges, this.size = 16});

  @override
  Widget build(BuildContext context) {
    if (badges.isEmpty) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: badges.map((b) => _BadgeChip(badge: b, size: size)).toList(),
    );
  }
}

class _BadgeChip extends StatelessWidget {
  final UserBadge badge;
  final double size;
  const _BadgeChip({required this.badge, required this.size});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: badge.url != null && badge.url!.isNotEmpty
          ? () => launchUrl(Uri.parse(badge.url!), mode: LaunchMode.externalApplication)
          : null,
      child: Tooltip(
        message: badge.label,
        child: Container(
          margin: const EdgeInsets.only(left: 4),
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          decoration: BoxDecoration(
            color: badge.color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: badge.color.withValues(alpha: 0.4)),
          ),
          child: Text(
            badge.emoji,
            style: TextStyle(fontSize: size - 2),
          ),
        ),
      ),
    );
  }
}

class UserBadgeRow extends StatefulWidget {
  final String uid;
  final double size;
  const UserBadgeRow({super.key, required this.uid, this.size = 16});

  @override
  State<UserBadgeRow> createState() => _UserBadgeRowState();
}

class _UserBadgeRowState extends State<UserBadgeRow> {
  List<UserBadge> _badges = [];

  @override
  void initState() {
    super.initState();
    BadgeService.getBadges(widget.uid).then((b) {
      if (mounted) setState(() => _badges = b);
    });
  }

  @override
  Widget build(BuildContext context) => BadgeRow(badges: _badges, size: widget.size);
}
