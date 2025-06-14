import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/src/auto_close_behavior.dart';
import 'package:flutter_slidable/src/notifications_old.dart';

import 'action_pane_configuration.dart';
import 'controller.dart';
import 'dismissal.dart';
import 'gesture_detector.dart';
import 'scrolling_behavior.dart';

part 'action_pane.dart';

/// A widget which can be dragged to reveal contextual actions.
class Slidable extends StatefulWidget {
  /// Creates a [Slidable].
  ///
  /// The [enabled], [closeOnScroll], [direction], [dragStartBehavior],
  /// [useTextDirection] and [child] arguments must not be null.
  const Slidable({
    super.key,
    this.controller,
    this.groupTag,
    this.enabled = true,
    this.closeOnScroll = true,
    this.startActionPane,
    this.endActionPane,
    this.direction = Axis.horizontal,
    this.dragStartBehavior = DragStartBehavior.down,
    this.useTextDirection = true,
    this.child,
    this.contentPadding,
    this.leading,
    this.title,
    this.subTitle,
    this.trailing,
  });

  /// The Slidable widget controller.
  final SlidableController? controller;

  /// Whether this slidable is interactive.
  ///
  /// If false, the child will not slid to show actions.
  ///
  /// Defaults to true.
  final bool enabled;

  /// Specifies to close this [Slidable] after the closest [Scrollable]'s
  /// position changed.
  ///
  /// Defaults to true.
  final bool closeOnScroll;

  /// {@template slidable.groupTag}
  /// The tag shared by all the [Slidable]s of the same group.
  ///
  /// This is used by [SlidableAutoCloseBehavior] to keep only one [Slidable]
  /// of the same group, open.
  /// {@endtemplate}
  final Object? groupTag;

  /// A widget which is shown when the user drags the [Slidable] to the right or
  /// to the bottom.
  ///
  /// When [direction] is [Axis.horizontal] and [useTextDirection] is true, the
  /// [startActionPane] is determined by the ambient [TextDirection].
  final ActionPane? startActionPane;

  /// A widget which is shown when the user drags the [Slidable] to the left or
  /// to the top.
  ///
  /// When [direction] is [Axis.horizontal] and [useTextDirection] is true, the
  /// [startActionPane] is determined by the ambient [TextDirection].
  final ActionPane? endActionPane;

  /// The direction in which this [Slidable] can be dragged.
  ///
  /// Defaults to [Axis.horizontal].
  final Axis direction;

  /// Whether the ambient [TextDirection] should be used to determine how
  /// [startActionPane] and [endActionPane] should be revealed.
  ///
  /// If [direction] is [Axis.vertical], this has no effect.
  /// If [direction] is [Axis.horizontal], then [startActionPane] is revealed
  /// when the users drags to the reading direction (and in the inverse of the
  /// reading direction for [endActionPane]).
  final bool useTextDirection;

  /// Determines the way that drag start behavior is handled.
  ///
  /// If set to [DragStartBehavior.start], the drag gesture used to dismiss a
  /// dismissible will begin upon the detection of a drag gesture. If set to
  /// [DragStartBehavior.down] it will begin when a down event is first detected.
  ///
  /// In general, setting this to [DragStartBehavior.start] will make drag
  /// animation smoother and setting it to [DragStartBehavior.down] will make
  /// drag behavior feel slightly more reactive.
  ///
  /// By default, the drag start behavior is [DragStartBehavior.start].
  ///
  /// See also:
  ///
  ///  * [DragGestureRecognizer.dragStartBehavior], which gives an example for the different behaviors.
  final DragStartBehavior dragStartBehavior;

  /// The widget below this widget in the tree.
  ///
  /// {@macro flutter.widgets.ProxyWidget.child}
  /// todo check, update by doersoul@126.com
  final Widget? child;

  /// todo check, add by doersoul@126.com
  final double? contentPadding;

  /// todo check, add by doersoul@126.com
  final Widget? leading;

  /// todo check, add by doersoul@126.com
  final Widget? title;

  /// todo check, add by doersoul@126.com
  final Widget? subTitle;

  /// todo check, add by doersoul@126.com
  final Widget? trailing;

  @override
  _SlidableState createState() => _SlidableState();

  /// The closest instance of the [SlidableController] which controls this
  /// [Slidable] that encloses the given context.
  ///
  /// {@tool snippet}
  /// Typical usage is as follows:
  ///
  /// ```dart
  /// SlidableController controller = Slidable.of(context);
  /// ```
  /// {@end-tool}
  static SlidableController? of(BuildContext context) {
    final scope = context
        .getElementForInheritedWidgetOfExactType<_SlidableControllerScope>()
        ?.widget as _SlidableControllerScope?;
    return scope?.controller;
  }
}

class _SlidableState extends State<Slidable>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late final SlidableController controller;
  late Animation<Offset> moveAnimation;
  late bool keepPanesOrder;

  @override
  bool get wantKeepAlive => !widget.closeOnScroll;

  @override
  void initState() {
    super.initState();
    controller = (widget.controller ?? SlidableController(this))
      ..actionPaneType.addListener(handleActionPanelTypeChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    updateIsLeftToRight();
    updateController();
    updateMoveAnimation();
  }

  @override
  void didUpdateWidget(covariant Slidable oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.controller != widget.controller) {
      controller.actionPaneType.removeListener(handleActionPanelTypeChanged);

      controller = (widget.controller ?? SlidableController(this))
        ..actionPaneType.addListener(handleActionPanelTypeChanged);
    }

    updateIsLeftToRight();
    updateController();
  }

  @override
  void dispose() {
    controller.actionPaneType.removeListener(handleActionPanelTypeChanged);

    if (controller != widget.controller) {
      controller.dispose();
    }
    super.dispose();
  }

  void updateController() {
    controller
      ..enableStartActionPane = startActionPane != null
      ..startActionPaneExtentRatio = startActionPane?.extentRatio ?? 0;

    controller
      ..enableEndActionPane = endActionPane != null
      ..endActionPaneExtentRatio = endActionPane?.extentRatio ?? 0;
  }

  void updateIsLeftToRight() {
    final textDirection = Directionality.of(context);
    controller.isLeftToRight = widget.direction == Axis.vertical ||
        !widget.useTextDirection ||
        textDirection == TextDirection.ltr;
  }

  void handleActionPanelTypeChanged() {
    setState(() {
      updateMoveAnimation();
    });
  }

  void handleDismissing() {
    if (controller.resizeRequest.value != null) {
      setState(() {});
    }
  }

  void updateMoveAnimation() {
    final double end = controller.direction.value.toDouble();
    moveAnimation = controller.animation.drive(
      Tween<Offset>(
        begin: Offset.zero,
        end: widget.direction == Axis.horizontal
            ? Offset(end, 0)
            : Offset(0, end),
      ),
    );
  }

  Widget? get actionPane {
    switch (controller.actionPaneType.value) {
      case ActionPaneType.start:
        return startActionPane;
      case ActionPaneType.end:
        return endActionPane;
      default:
        return null;
    }
  }

  ActionPane? get startActionPane => widget.startActionPane;

  ActionPane? get endActionPane => widget.endActionPane;

  Alignment get actionPaneAlignment {
    final sign = controller.direction.value.toDouble();
    if (widget.direction == Axis.horizontal) {
      return Alignment(-sign, 0);
    } else {
      return Alignment(0, -sign);
    }
  }

  /// todo check, add by doersoul@126.com
  void _onTapTrailing() {
    if (controller.direction.value != 0) {
      controller.close();
    } else {
      controller.openEndActionPane();
    }
  }

  Widget _buildContent() {
    Widget content = SlideTransition(
      position: moveAnimation,
      child: SlidableAutoCloseBehaviorInteractor(
        groupTag: widget.groupTag,
        controller: controller,
        child: widget.child ?? const SizedBox.shrink(),
      ),
    );

    content = Stack(
      children: <Widget>[
        if (actionPane != null)
          Positioned.fill(
            child: ClipRect(
              clipper: _SlidableClipper(
                axis: widget.direction,
                controller: controller,
              ),
              child: actionPane,
            ),
          ),
        content,
      ],
    );

    return SlidableGestureDetector(
      enabled: widget.enabled,
      controller: controller,
      direction: widget.direction,
      dragStartBehavior: widget.dragStartBehavior,
      fullScreenWidth: false,
      child: SlidableNotificationSender(
        tag: widget.groupTag,
        controller: controller,
        child: SlidableScrollingBehavior(
          controller: controller,
          closeOnScroll: widget.closeOnScroll,
          child: SlidableDismissal(
            axis: flipAxis(widget.direction),
            controller: controller,
            child: ActionPaneConfiguration(
              alignment: actionPaneAlignment,
              direction: widget.direction,
              isStartActionPane:
                  controller.actionPaneType.value == ActionPaneType.start,
              child: _SlidableControllerScope(
                controller: controller,
                child: content,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildListTile() {
    Widget content = widget.trailing ??
        Container(
          height: double.infinity,
          padding: EdgeInsets.symmetric(
            horizontal: widget.contentPadding ?? 16,
          ),
          child: const Icon(
            Icons.more_horiz_rounded,
            color: Colors.grey,
            size: 24,
          ),
        );

    content = GestureDetector(onTap: _onTapTrailing, child: content);

    content = ListTile(
      leading: widget.leading,
      title: widget.title,
      subtitle: widget.subTitle,
      titleAlignment: ListTileTitleAlignment.center,
      minVerticalPadding: widget.subTitle == null ? 20 : 16,
      contentPadding: EdgeInsets.only(left: widget.contentPadding ?? 16),
      trailing: SlidableGestureDetector(
        enabled: widget.enabled,
        controller: controller,
        direction: widget.direction,
        dragStartBehavior: widget.dragStartBehavior,
        fullScreenWidth: true,
        child: content,
      ),
    );

    content = SlideTransition(
      position: moveAnimation,
      child: SlidableAutoCloseBehaviorInteractor(
        groupTag: widget.groupTag,
        controller: controller,
        child: content,
      ),
    );

    content = Stack(
      children: <Widget>[
        if (actionPane != null)
          Positioned.fill(
            child: ClipRect(
              clipper: _SlidableClipper(
                axis: widget.direction,
                controller: controller,
              ),
              child: actionPane,
            ),
          ),
        content,
      ],
    );

    return SlidableAutoCloseNotificationSender(
      controller: controller,
      groupTag: widget.groupTag,
      child: SlidableScrollingBehavior(
        controller: controller,
        closeOnScroll: widget.closeOnScroll,
        child: SlidableDismissal(
          axis: flipAxis(widget.direction),
          controller: controller,
          child: ActionPaneConfiguration(
            alignment: actionPaneAlignment,
            direction: widget.direction,
            isStartActionPane:
                controller.actionPaneType.value == ActionPaneType.start,
            child: _SlidableControllerScope(
              controller: controller,
              child: content,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // See AutomaticKeepAliveClientMixin.

    return widget.title != null ? _buildListTile() : _buildContent();
  }
}

class _SlidableControllerScope extends InheritedWidget {
  const _SlidableControllerScope({
    required this.controller,
    required super.child,
  });

  final SlidableController? controller;

  @override
  bool updateShouldNotify(_SlidableControllerScope old) {
    return controller != old.controller;
  }
}

class _SlidableClipper extends CustomClipper<Rect> {
  _SlidableClipper({
    required this.axis,
    required this.controller,
  }) : super(reclip: controller.animation);

  final Axis axis;
  final SlidableController controller;

  @override
  Rect getClip(Size size) {
    switch (axis) {
      case Axis.horizontal:
        final double offset = controller.ratio * size.width;
        if (offset < 0) {
          return Rect.fromLTRB(size.width + offset, 0, size.width, size.height);
        }
        return Rect.fromLTRB(0, 0, offset, size.height);
      case Axis.vertical:
        final double offset = controller.ratio * size.height;
        if (offset < 0) {
          return Rect.fromLTRB(
            0,
            size.height + offset,
            size.width,
            size.height,
          );
        }
        return Rect.fromLTRB(0, 0, size.width, offset);
    }
  }

  @override
  Rect getApproximateClipRect(Size size) => getClip(size);

  @override
  bool shouldReclip(_SlidableClipper oldClipper) {
    return oldClipper.axis != axis;
  }
}
