import 'package:flutter/material.dart';

/// Add new creation/import formats as menu entries, not welcome-screen buttons.
class ProjectActionMenu extends StatelessWidget {
  const ProjectActionMenu({
    super.key,
    required this.label,
    required this.icon,
    required this.entries,
    this.primary = false,
  });

  final String label;
  final IconData icon;
  final bool primary;
  final List<({String label, IconData icon, VoidCallback onPressed})> entries;

  @override
  Widget build(BuildContext context) => MenuAnchor(
    consumeOutsideTap: true,
    menuChildren: [
      for (final entry in entries)
        MenuItemButton(
          leadingIcon: Icon(entry.icon, size: 20),
          onPressed: entry.onPressed,
          child: Text(entry.label),
        ),
    ],
    builder: (context, controller, child) {
      void toggle() =>
          controller.isOpen ? controller.close() : controller.open();
      final compact =
          MediaQuery.sizeOf(context).width < 400 &&
          MediaQuery.textScalerOf(context).scale(14) > 18;
      final content = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!compact) ...[Text(label), const SizedBox(width: 8)],
          const Icon(Icons.expand_more, size: 18),
        ],
      );
      const padding = EdgeInsets.symmetric(horizontal: 18, vertical: 17);
      return Tooltip(
        message: label,
        child: primary
            ? FilledButton.icon(
                onPressed: toggle,
                icon: Icon(icon, size: 20),
                label: content,
                style: FilledButton.styleFrom(padding: padding),
              )
            : OutlinedButton.icon(
                onPressed: toggle,
                icon: Icon(icon, size: 20),
                label: content,
                style: OutlinedButton.styleFrom(padding: padding),
              ),
      );
    },
  );
}
