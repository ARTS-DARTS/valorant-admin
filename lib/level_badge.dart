import 'package:flutter/material.dart';
import 'level_system.dart';

class LevelBadge extends StatefulWidget {
  final int approvedLineups;
  final bool animated;
  final bool large;

  const LevelBadge({
    super.key,
    required this.approvedLineups,
    this.animated = false,
    this.large = false,
  });

  @override
  State<LevelBadge> createState() => _LevelBadgeState();
}

class _LevelBadgeState extends State<LevelBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _pulse = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    if (widget.animated) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final levelData = LevelSystem.getLevel(widget.approvedLineups);
    final color = Color(levelData['color'] as int);
    final icon = levelData['icon'] as String;
    final name = levelData['name'] as String;
    final level = levelData['level'] as int;
    final size = widget.large ? 18.0 : 12.0;
    final padding = widget.large
        ? const EdgeInsets.symmetric(horizontal: 10, vertical: 4)
        : const EdgeInsets.symmetric(horizontal: 6, vertical: 2);

    Widget badge = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: TextStyle(fontSize: size)),
          const SizedBox(width: 4),
          Text(
            widget.large ? name : 'Lv.$level',
            style: TextStyle(
              color: color,
              fontSize: size,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );

    if (widget.animated) {
      return AnimatedBuilder(
        animation: _pulse,
        builder: (context, child) => Transform.scale(
          scale: _pulse.value,
          child: child,
        ),
        child: badge,
      );
    }

    return badge;
  }
}