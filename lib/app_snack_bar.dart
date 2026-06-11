import 'package:flutter/material.dart';
import 'app_theme.dart';

enum SnackBarType { success, warning, info, error }

class AppSnackBar {
  static bool _isShowing = false;

  static void show(
    BuildContext context,
    String message, {
    SnackBarType type = SnackBarType.info,
    Duration duration = const Duration(seconds: 3),
  }) {
    if (_isShowing) return;
    _isShowing = true;

    final overlay = Overlay.of(context, rootOverlay: true);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (ctx) => _AppSnackBarWidget(
        message: message,
        type: type,
        duration: duration,
        onDismissed: () {
          entry.remove();
          _isShowing = false;
        },
      ),
    );

    overlay.insert(entry);
  }
}

class _AppSnackBarWidget extends StatefulWidget {
  final String message;
  final SnackBarType type;
  final Duration duration;
  final VoidCallback onDismissed;

  const _AppSnackBarWidget({
    required this.message,
    required this.type,
    required this.duration,
    required this.onDismissed,
  });

  @override
  State<_AppSnackBarWidget> createState() => _AppSnackBarWidgetState();
}

class _AppSnackBarWidgetState extends State<_AppSnackBarWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<Offset> _slide;
  late Animation<double> _fade;
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, -1.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _fade = Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));

    _ctrl.forward();
    Future.delayed(widget.duration, _dismiss);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _dismiss() async {
    if (_dismissed || !mounted) return;
    _dismissed = true;
    await _ctrl.reverse();
    widget.onDismissed();
  }

  Color get _borderColor {
    switch (widget.type) {
      case SnackBarType.success:
        return Colors.green;
      case SnackBarType.warning:
        return Colors.orange;
      case SnackBarType.error:
        return Colors.red;
      case SnackBarType.info:
    }
    return const Color(0xFFFF4655);
  }

  IconData get _icon {
    switch (widget.type) {
      case SnackBarType.success:
        return Icons.check_circle_outline;
      case SnackBarType.warning:
        return Icons.warning_amber_outlined;
      case SnackBarType.error:
        return Icons.error_outline;
      case SnackBarType.info:
    }
    return Icons.info_outline;
  }

  @override
  Widget build(BuildContext context) {
    final t = AppThemeNotifier.of(context);
    final topPadding = MediaQuery.of(context).padding.top;

    return Positioned(
      top: topPadding + 12,
      left: 16,
      right: 16,
      child: Material(
        color: Colors.transparent,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onVerticalDragUpdate: (d) {
            if (d.delta.dy < -4) _dismiss();
          },
          child: FadeTransition(
            opacity: _fade,
            child: SlideTransition(
              position: _slide,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: t.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _borderColor, width: 1.5),
                  boxShadow: const [
                    BoxShadow(
                        color: Colors.black54,
                        blurRadius: 12,
                        offset: Offset(0, 4)),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(_icon, color: _borderColor, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        widget.message,
                        style: TextStyle(
                            color: t.textPrimary,
                            fontSize: 13,
                            height: 1.4),
                      ),
                    ),
                    GestureDetector(
                      onTap: _dismiss,
                      child: Icon(Icons.close,
                          color: t.textSecondary, size: 16),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
