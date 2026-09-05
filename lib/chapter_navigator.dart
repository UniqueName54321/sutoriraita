import 'package:flutter/material.dart';

class StoryDragGrip<T extends Object> extends StatefulWidget {
  const StoryDragGrip({super.key, required this.data, required this.label});
  final T data;
  final String label;
  @override
  State<StoryDragGrip<T>> createState() => _StoryDragGripState<T>();
}

class _StoryDragGripState<T extends Object> extends State<StoryDragGrip<T>> {
  EdgeDraggingAutoScroller? scroller;
  @override
  void dispose() {
    scroller?.stopAutoScroll();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Draggable<T>(
    data: widget.data,
    onDragStarted: () {
      final scrollable = Scrollable.maybeOf(context);
      if (scrollable != null) {
        scroller = EdgeDraggingAutoScroller(scrollable, velocityScalar: 18);
      }
    },
    onDragUpdate: (details) => scroller?.startAutoScrollIfNecessary(
      Rect.fromCenter(center: details.globalPosition, width: 32, height: 80),
    ),
    onDragEnd: (_) => scroller?.stopAutoScroll(),
    feedback: Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(8),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 260),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            widget.label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    ),
    childWhenDragging: const SizedBox(width: 28, height: 32),
    child: Tooltip(
      message: widget.label,
      child: const SizedBox(
        width: 28,
        height: 32,
        child: Icon(Icons.drag_indicator, size: 19),
      ),
    ),
  );
}

class StoryDropSlot<T extends Object> extends StatelessWidget {
  const StoryDropSlot({
    super.key,
    required this.onDrop,
    required this.label,
    this.child,
  });
  final void Function(T) onDrop;
  final String label;
  final Widget? child;
  @override
  Widget build(BuildContext context) => DragTarget<T>(
    onAcceptWithDetails: (details) => onDrop(details.data),
    builder: (context, candidates, rejected) => Container(
      constraints: BoxConstraints(minHeight: child == null ? 14 : 0),
      decoration: BoxDecoration(
        color: candidates.isEmpty
            ? null
            : Theme.of(context).colorScheme.primaryContainer,
        border: candidates.isEmpty
            ? null
            : Border.all(
                color: Theme.of(context).colorScheme.primary,
                width: 2,
              ),
      ),
      child: candidates.isNotEmpty && child == null
          ? Padding(
              padding: const EdgeInsets.all(4),
              child: Text(label, style: const TextStyle(fontSize: 11)),
            )
          : child,
    ),
  );
}
