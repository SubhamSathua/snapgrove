import 'package:flutter/material.dart';

class NotificationService {
  final GlobalKey<ScaffoldMessengerState> messengerKey = GlobalKey<ScaffoldMessengerState>();

  void showSnackBar(
    String message, {
    bool isError = false,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 4),
  }) {
    final state = messengerKey.currentState;
    if (state == null) return;

    state.hideCurrentSnackBar();
    state.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        dismissDirection: DismissDirection.horizontal,
        duration: duration,
        elevation: 6,
        backgroundColor: isError ? const Color(0xFFC62828) : const Color(0xFF1E1E1E),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
            color: isError ? const Color(0x33FFCDD2) : const Color(0x22FFFFFF),
            width: 1,
          ),
        ),
        content: _ToastContent(
          message: message,
          isError: isError,
          actionLabel: actionLabel,
          onAction: onAction,
          onClose: () => state.hideCurrentSnackBar(),
        ),
      ),
    );
  }
}

class _ToastContent extends StatelessWidget {
  final String message;
  final bool isError;
  final String? actionLabel;
  final VoidCallback? onAction;
  final VoidCallback onClose;

  const _ToastContent({
    required this.message,
    required this.isError,
    this.actionLabel,
    this.onAction,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (isError) ...[
          const Icon(Icons.error_outline, size: 18, color: Colors.white),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Text(
            message,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'JetBrains Mono',
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
        ),
        if (actionLabel != null && onAction != null) ...[
          const SizedBox(width: 8),
          _ToastActionButton(
            label: actionLabel!,
            onTap: () {
              onClose();
              onAction!();
            },
          ),
        ],
        const SizedBox(width: 6),
        _ToastCloseButton(onTap: onClose),
      ],
    );
  }
}

class _ToastActionButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;

  const _ToastActionButton({
    required this.label,
    required this.onTap,
  });

  @override
  State<_ToastActionButton> createState() => _ToastActionButtonState();
}

class _ToastActionButtonState extends State<_ToastActionButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    const Color brandColor = Color(0xFFf89838);
    final Color bgColor = _isHovered
        ? brandColor.withValues(alpha: 0.25)
        : brandColor.withValues(alpha: 0.12);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: brandColor.withValues(alpha: 0.6)),
        ),
        child: Material(
          color: bgColor,
          borderRadius: BorderRadius.circular(6),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: widget.onTap,
            splashColor: brandColor.withValues(alpha: 0.35),
            highlightColor: brandColor.withValues(alpha: 0.15),
            hoverColor: Colors.transparent,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              child: Text(
                widget.label,
                style: const TextStyle(
                  fontFamily: 'JetBrains Mono',
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: brandColor,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ToastCloseButton extends StatefulWidget {
  final VoidCallback onTap;

  const _ToastCloseButton({required this.onTap});

  @override
  State<_ToastCloseButton> createState() => _ToastCloseButtonState();
}

class _ToastCloseButtonState extends State<_ToastCloseButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: SizedBox(
        width: 28,
        height: 28,
        child: Material(
          color: _isHovered ? Colors.white.withValues(alpha: 0.15) : Colors.transparent,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: widget.onTap,
            splashColor: Colors.white.withValues(alpha: 0.25),
            highlightColor: Colors.white.withValues(alpha: 0.1),
            hoverColor: Colors.transparent,
            child: const Center(
              child: Icon(
                Icons.close,
                size: 16,
                color: Colors.white70,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
