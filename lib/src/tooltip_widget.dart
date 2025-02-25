import 'dart:math';

import 'package:flutter/material.dart';

import 'enum.dart';
import 'get_position.dart';
import 'measure_size.dart';
import 'widget/tooltip_slide_transition.dart';

const _kDefaultPaddingFromParent = 14.0;

// Assuming the TooltipPosition enum needs to be updated
// You'll need to modify enum.dart to include these values:
// enum TooltipPosition { top, bottom, left, right }

class ToolTipWidget extends StatefulWidget {
  final GetPosition? position;
  final Offset? offset;
  final Size screenSize;
  final String? title;
  final TextAlign? titleAlignment;
  final String? description;
  final TextAlign? descriptionAlignment;
  final TextStyle? titleTextStyle;
  final TextStyle? descTextStyle;
  final Widget? container;
  final Color? tooltipBackgroundColor;
  final Color? textColor;
  final bool showArrow;
  final double? contentHeight;
  final double? contentWidth;
  final VoidCallback? onTooltipTap;
  final EdgeInsets? tooltipPadding;
  final Duration movingAnimationDuration;
  final bool disableMovingAnimation;
  final bool disableScaleAnimation;
  final BorderRadius? tooltipBorderRadius;
  final Duration scaleAnimationDuration;
  final Curve scaleAnimationCurve;
  final Alignment? scaleAnimationAlignment;
  final bool isTooltipDismissed;
  final TooltipPosition? tooltipPosition;
  final EdgeInsets? titlePadding;
  final EdgeInsets? descriptionPadding;
  final TextDirection? titleTextDirection;
  final TextDirection? descriptionTextDirection;
  final double toolTipSlideEndDistance;
  final CrossAxisAlignment? titleDesCrossAxisAlignment;
  final Widget? toolTipWidget;
  final double? toolTipWidth;
  final double heightBetweenTargetAndTooltip;
  // Add this new property for horizontal spacing
  final double widthBetweenTargetAndTooltip;

  const ToolTipWidget({
    super.key,
    required this.position,
    required this.offset,
    required this.screenSize,
    required this.title,
    required this.titleAlignment,
    required this.description,
    required this.titleTextStyle,
    required this.descTextStyle,
    required this.container,
    required this.tooltipBackgroundColor,
    required this.textColor,
    required this.showArrow,
    required this.contentHeight,
    required this.contentWidth,
    required this.onTooltipTap,
    required this.movingAnimationDuration,
    required this.descriptionAlignment,
    this.tooltipPadding = const EdgeInsets.symmetric(vertical: 8),
    required this.disableMovingAnimation,
    required this.disableScaleAnimation,
    required this.tooltipBorderRadius,
    required this.scaleAnimationDuration,
    required this.scaleAnimationCurve,
    this.scaleAnimationAlignment,
    this.isTooltipDismissed = false,
    this.tooltipPosition,
    this.titlePadding,
    this.descriptionPadding,
    this.titleTextDirection,
    this.descriptionTextDirection,
    this.toolTipSlideEndDistance = 7,
    this.titleDesCrossAxisAlignment,
    this.toolTipWidget,
    this.toolTipWidth,
    required this.heightBetweenTargetAndTooltip,
    this.widthBetweenTargetAndTooltip = 14.0,
  });

  @override
  State<ToolTipWidget> createState() => _ToolTipWidgetState();
}

class _ToolTipWidgetState extends State<ToolTipWidget>
    with TickerProviderStateMixin {
  Offset? position;

  bool isArrowUp = false;
  bool isArrowDown = false;
  bool isArrowLeft = false;
  bool isArrowRight = false;
  TooltipPosition _currentPosition = TooltipPosition.bottom;

  late final AnimationController _movingAnimationController;
  late final Animation<double> _movingAnimation;
  late final AnimationController _scaleAnimationController;
  late final Animation<double> _scaleAnimation;

  double tooltipWidth = 0;
  double tooltipHeight = 0;
  double tooltipScreenEdgePadding = 20;
  double tooltipTextPadding = 15;

  TooltipPosition findPositionForContent(Offset position) {
    var height = 120.0;
    var width = 200.0;
    height = widget.contentHeight ?? height;
    width = widget.contentWidth ?? width;

    final bottomPosition =
        position.dy + ((widget.position?.getHeight() ?? 0) / 2);
    final topPosition = position.dy - ((widget.position?.getHeight() ?? 0) / 2);
    final rightPosition =
        position.dx + ((widget.position?.getWidth() ?? 0) / 2);
    final leftPosition = position.dx - ((widget.position?.getWidth() ?? 0) / 2);

    final hasSpaceInTop = topPosition >= height;
    final hasSpaceInLeft = leftPosition >= width;
    final hasSpaceInRight = (widget.screenSize.width - rightPosition) >= width;

    // Get current view insets
    // TODO: need to update for flutter version > 3.8.X
    // ignore: deprecated_member_use
    final EdgeInsets viewInsets = EdgeInsets.fromWindowPadding(
      // ignore: deprecated_member_use
      WidgetsBinding.instance.window.viewInsets,
      // ignore: deprecated_member_use
      WidgetsBinding.instance.window.devicePixelRatio,
    );

    final double actualVisibleScreenHeight =
        widget.screenSize.height - viewInsets.bottom;
    final hasSpaceInBottom =
        (actualVisibleScreenHeight - bottomPosition) >= height;

    // First check if a specific position was requested
    if (widget.tooltipPosition != null) {
      debugPrint('Tool tip position: ${widget.tooltipPosition!.name}');
      return widget.tooltipPosition!;
    }

    // Check if the screen is in portrait or landscape mode
    final isPortrait = widget.screenSize.height > widget.screenSize.width;

    // Position based on orientation
    if (isPortrait) {
      // In portrait mode, prefer top/bottom positions
      if (hasSpaceInBottom) {
        return TooltipPosition.bottom;
      } else if (hasSpaceInTop) {
        return TooltipPosition.top;
      } else if (hasSpaceInRight) {
        return TooltipPosition.right;
      } else if (hasSpaceInLeft) {
        return TooltipPosition.left;
      }
    } else {
      // In landscape mode, prefer left/right positions
      if (hasSpaceInRight) {
        return TooltipPosition.right;
      } else if (hasSpaceInLeft) {
        return TooltipPosition.left;
      } else if (hasSpaceInBottom) {
        return TooltipPosition.bottom;
      } else if (hasSpaceInTop) {
        return TooltipPosition.top;
      }
    }

    // Default to bottom if no other position works
    return TooltipPosition.bottom;
  }

  void _getTooltipSize() {
    if (widget.toolTipWidth != null) {
      tooltipWidth = widget.toolTipWidth!;
      return;
    }

    final titleStyle = widget.titleTextStyle ??
        Theme.of(context)
            .textTheme
            .titleLarge!
            .merge(TextStyle(color: widget.textColor));
    final descriptionStyle = widget.descTextStyle ??
        Theme.of(context)
            .textTheme
            .titleSmall!
            .merge(TextStyle(color: widget.textColor));
    final titleLength = widget.title == null
        ? 0
        : _textSize(widget.title!, titleStyle).width +
            widget.tooltipPadding!.right +
            widget.tooltipPadding!.left +
            (widget.titlePadding?.right ?? 0) +
            (widget.titlePadding?.left ?? 0);
    final descriptionLength = widget.description == null
        ? 0
        : (_textSize(widget.description!, descriptionStyle).width +
            widget.tooltipPadding!.right +
            widget.tooltipPadding!.left +
            (widget.descriptionPadding?.right ?? 0) +
            (widget.descriptionPadding?.left ?? 0));
    var maxTextWidth = max(titleLength, descriptionLength);
    if (maxTextWidth > widget.screenSize.width - tooltipScreenEdgePadding) {
      tooltipWidth = widget.screenSize.width - tooltipScreenEdgePadding;
    } else {
      tooltipWidth = maxTextWidth + tooltipTextPadding;
    }

    // Calculate approximate height for horizontal tooltips
    final titleHeight = widget.title == null
        ? 0
        : _textSize(widget.title!, titleStyle).height +
            (widget.titlePadding?.top ?? 0) +
            (widget.titlePadding?.bottom ?? 0);
    final descriptionHeight = widget.description == null
        ? 0
        : _textSize(widget.description!, descriptionStyle).height +
            (widget.descriptionPadding?.top ?? 0) +
            (widget.descriptionPadding?.bottom ?? 0);

    tooltipHeight = titleHeight +
        descriptionHeight +
        widget.tooltipPadding!.top +
        widget.tooltipPadding!.bottom;
  }

  double? _getLeft() {
    if (widget.position != null) {
      if (_currentPosition == TooltipPosition.left) {
        return widget.position!.getLeft() -
            tooltipWidth -
            widget.widthBetweenTargetAndTooltip;
      } else if (_currentPosition == TooltipPosition.right) {
        return widget.position!.getRight() +
            widget.widthBetweenTargetAndTooltip;
      }

      final width =
          widget.container != null ? _customContainerWidth.value : tooltipWidth;
      double leftPositionValue = widget.position!.getCenter() - (width * 0.5);
      if ((leftPositionValue + width) > widget.screenSize.width) {
        return null;
      } else if ((leftPositionValue) < _kDefaultPaddingFromParent) {
        return _kDefaultPaddingFromParent;
      } else {
        return leftPositionValue;
      }
    }
    return null;
  }

  double? _getRight() {
    if (widget.position != null) {
      if (_currentPosition == TooltipPosition.left ||
          _currentPosition == TooltipPosition.right) {
        return null; // We're using left for horizontal positioning
      }

      final width =
          widget.container != null ? _customContainerWidth.value : tooltipWidth;

      final left = _getLeft();
      if (left == null || (left + width) > widget.screenSize.width) {
        final rightPosition = widget.position!.getCenter() + (width * 0.5);

        return (rightPosition + width) > widget.screenSize.width
            ? _kDefaultPaddingFromParent
            : null;
      } else {
        return null;
      }
    }
    return null;
  }

  double? _getTop() {
    if (widget.position != null) {
      if (_currentPosition == TooltipPosition.top) {
        return widget.position!.getTop() -
            tooltipHeight -
            widget.heightBetweenTargetAndTooltip;
      } else if (_currentPosition == TooltipPosition.bottom) {
        return widget.position!.getBottom() +
            widget.heightBetweenTargetAndTooltip;
      } else if (_currentPosition == TooltipPosition.left ||
          _currentPosition == TooltipPosition.right) {
        // For left/right positions, center vertically with the target
        return widget.position!.getCenter() - (tooltipHeight / 2);
      }
    }
    return null;
  }

  double _getSpace() {
    var space = widget.position!.getCenter() - (widget.contentWidth! / 2);
    if (space + widget.contentWidth! > widget.screenSize.width) {
      space = widget.screenSize.width - widget.contentWidth! - 8;
    } else if (space < (widget.contentWidth! / 2)) {
      space = 16;
    }
    return space;
  }

  double _getAlignmentX() {
    if (_currentPosition == TooltipPosition.left) {
      return 1.0; // Align to the right side of the tooltip (toward the target)
    } else if (_currentPosition == TooltipPosition.right) {
      return -1.0; // Align to the left side of the tooltip (toward the target)
    }

    final calculatedLeft = _getLeft();
    var left = calculatedLeft == null
        ? 0
        : (widget.position!.getCenter() - calculatedLeft);
    var right = _getLeft() == null
        ? (widget.screenSize.width - widget.position!.getCenter()) -
            (_getRight() ?? 0)
        : 0;
    final containerWidth =
        widget.container != null ? _customContainerWidth.value : tooltipWidth;

    if (left != 0) {
      return (-1 + (2 * (left / containerWidth)));
    } else {
      return (1 - (2 * (right / containerWidth)));
    }
  }

  double _getAlignmentY() {
    if (_currentPosition == TooltipPosition.top) {
      return 1.0; // Align to the bottom of the tooltip (toward the target)
    } else if (_currentPosition == TooltipPosition.bottom) {
      return -1.0; // Align to the top of the tooltip (toward the target)
    } else if (_currentPosition == TooltipPosition.left ||
        _currentPosition == TooltipPosition.right) {
      // Calculate vertical alignment for horizontal tooltips
      final targetCenter = widget.position!.getCenter();
      final tooltipTop = _getTop() ?? 0;
      final verticalOffset = targetCenter - (tooltipTop + (tooltipHeight / 2));
      return (verticalOffset / (tooltipHeight / 2)).clamp(-1.0, 1.0);
    }

    return 0.0;
  }

  final GlobalKey _customContainerKey = GlobalKey();
  final ValueNotifier<double> _customContainerWidth = ValueNotifier<double>(1);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.container != null &&
          _customContainerKey.currentContext != null &&
          _customContainerKey.currentContext?.size != null) {
        setState(() {
          _customContainerWidth.value =
              _customContainerKey.currentContext!.size!.width;
        });
      }
    });
    _movingAnimationController = AnimationController(
      duration: widget.movingAnimationDuration,
      vsync: this,
    );
    _movingAnimation = CurvedAnimation(
      parent: _movingAnimationController,
      curve: Curves.easeInOut,
    );
    _scaleAnimationController = AnimationController(
      duration: widget.scaleAnimationDuration,
      vsync: this,
      lowerBound: widget.disableScaleAnimation ? 1 : 0,
    );
    _scaleAnimation = CurvedAnimation(
      parent: _scaleAnimationController,
      curve: widget.scaleAnimationCurve,
    );
    if (widget.disableScaleAnimation) {
      movingAnimationListener();
    } else {
      _scaleAnimationController
        ..addStatusListener((scaleAnimationStatus) {
          if (scaleAnimationStatus == AnimationStatus.completed) {
            movingAnimationListener();
          }
        })
        ..forward();
    }
    if (!widget.disableMovingAnimation) {
      _movingAnimationController.forward();
    }
  }

  void movingAnimationListener() {
    _movingAnimationController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _movingAnimationController.reverse();
      }
      if (_movingAnimationController.isDismissed) {
        if (!widget.disableMovingAnimation) {
          _movingAnimationController.forward();
        }
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _getTooltipSize();
  }

  @override
  void didUpdateWidget(covariant ToolTipWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    _getTooltipSize();
  }

  @override
  void dispose() {
    _movingAnimationController.dispose();
    _scaleAnimationController.dispose();

    super.dispose();
  }

  Offset _getSlideOffset() {
    switch (_currentPosition) {
      case TooltipPosition.top:
        return Offset(0, -widget.toolTipSlideEndDistance);
      case TooltipPosition.bottom:
        return Offset(0, widget.toolTipSlideEndDistance);
      case TooltipPosition.left:
        return Offset(-widget.toolTipSlideEndDistance, 0);
      case TooltipPosition.right:
        return Offset(widget.toolTipSlideEndDistance, 0);
      default:
        return Offset(0, widget.toolTipSlideEndDistance);
    }
  }

  @override
  Widget build(BuildContext context) {
    position = widget.offset;
    _currentPosition = findPositionForContent(position!);

    // Set arrow direction flags
    isArrowUp = _currentPosition == TooltipPosition.bottom;
    isArrowDown = _currentPosition == TooltipPosition.top;
    isArrowLeft = _currentPosition == TooltipPosition.right;
    isArrowRight = _currentPosition == TooltipPosition.left;

    if (!widget.disableScaleAnimation && widget.isTooltipDismissed) {
      _scaleAnimationController.reverse();
    }

    // Constants for arrow dimensions
    const arrowWidth = 18.0;
    const arrowHeight = 9.0;

    // Calculate padding based on arrow position
    var paddingTop = isArrowUp ? widget.heightBetweenTargetAndTooltip : 0.0;
    var paddingBottom =
        isArrowDown ? widget.heightBetweenTargetAndTooltip : 0.0;
    var paddingLeft = isArrowLeft ? widget.widthBetweenTargetAndTooltip : 0.0;
    var paddingRight = isArrowRight ? widget.widthBetweenTargetAndTooltip : 0.0;

    if (!widget.showArrow) {
      paddingTop = paddingBottom = paddingLeft = paddingRight = 10.0;
    }

    if (widget.container == null) {
      return Positioned(
        top: _getTop(),
        left: _getLeft(),
        right: _getRight(),
        child: ScaleTransition(
          scale: _scaleAnimation,
          alignment: widget.scaleAnimationAlignment ??
              Alignment(
                _getAlignmentX(),
                _getAlignmentY(),
              ),
          child: ToolTipSlideTransition(
            position: Tween<Offset>(
              begin: Offset.zero,
              end: _getSlideOffset(),
            ).animate(_movingAnimation),
            child: Material(
              type: MaterialType.transparency,
              child: Container(
                padding: widget.showArrow
                    ? EdgeInsets.only(
                        top: paddingTop - (isArrowUp ? arrowHeight : 0),
                        bottom: paddingBottom - (isArrowDown ? arrowHeight : 0),
                        left: paddingLeft - (isArrowLeft ? arrowHeight : 0),
                        right: paddingRight - (isArrowRight ? arrowHeight : 0),
                      )
                    : null,
                child: Stack(
                  alignment: _getArrowAlignment(),
                  children: [
                    if (widget.showArrow) _buildArrow(arrowWidth, arrowHeight),
                    _buildTooltipContent(arrowWidth, arrowHeight),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    // Custom container case - less modifications needed
    return Stack(
      children: <Widget>[
        Positioned(
          left: _getSpace(),
          top: _getTop() ?? 0,
          child: FractionalTranslation(
            translation: Offset(
                0.0, _currentPosition == TooltipPosition.top ? -1.0 : 0.0),
            child: ToolTipSlideTransition(
              position: Tween<Offset>(
                begin: Offset.zero,
                end: _getSlideOffset(),
              ).animate(_movingAnimation),
              child: Material(
                color: Colors.transparent,
                child: GestureDetector(
                  onTap: widget.onTooltipTap,
                  child: Container(
                    padding: EdgeInsets.only(
                      top: paddingTop,
                      bottom: paddingBottom,
                      left: paddingLeft,
                      right: paddingRight,
                    ),
                    color: Colors.transparent,
                    child: Center(
                      child: MeasureSize(
                        onSizeChange: onSizeChange,
                        child: widget.container,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Helper method to get the alignment for the arrow
  AlignmentGeometry _getArrowAlignment() {
    if (isArrowUp) return Alignment.topLeft;
    if (isArrowDown) return Alignment.bottomLeft;
    if (isArrowLeft) return Alignment.centerLeft;
    if (isArrowRight) return Alignment.centerRight;

    // Default fallback
    return _getLeft() == null ? Alignment.bottomRight : Alignment.bottomLeft;
  }

  // Helper method to build the arrow
  Widget _buildArrow(double arrowWidth, double arrowHeight) {
    return Positioned(
      left: _isHorizontalArrow() ? 0 : _getArrowLeft(arrowWidth),
      right: _isHorizontalArrow() ? 0 : _getArrowRight(arrowWidth),
      top: _isVerticalArrow() ? 0 : _getArrowTop(arrowWidth),
      bottom: _isVerticalArrow() ? 0 : _getArrowBottom(arrowWidth),
      child: CustomPaint(
        painter: _Arrow(
          strokeColor: widget.tooltipBackgroundColor!,
          strokeWidth: 10,
          paintingStyle: PaintingStyle.fill,
          isUpArrow: isArrowUp,
          isDownArrow: isArrowDown,
          isLeftArrow: isArrowLeft,
          isRightArrow: isArrowRight,
        ),
        child: SizedBox(
          height: _isVerticalArrow() ? arrowHeight : arrowWidth,
          width: _isVerticalArrow() ? arrowWidth : arrowHeight,
        ),
      ),
    );
  }

  bool _isVerticalArrow() => isArrowUp || isArrowDown;
  bool _isHorizontalArrow() => isArrowLeft || isArrowRight;

  // Helper method to build the tooltip content
  Widget _buildTooltipContent(double arrowWidth, double arrowHeight) {
    return Padding(
      padding: EdgeInsets.only(
        top: isArrowUp ? arrowHeight - 1 : 0,
        bottom: isArrowDown ? arrowHeight - 1 : 0,
        left: isArrowLeft ? arrowHeight - 1 : 0,
        right: isArrowRight ? arrowHeight - 1 : 0,
      ),
      child: ClipRRect(
        borderRadius: widget.tooltipBorderRadius ?? BorderRadius.circular(8.0),
        child: GestureDetector(
          onTap: widget.onTooltipTap,
          child: Container(
            width: _isHorizontalArrow() ? null : tooltipWidth,
            padding: widget.tooltipPadding,
            color: widget.tooltipBackgroundColor,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: widget.titleDesCrossAxisAlignment ??
                  (widget.title != null
                      ? CrossAxisAlignment.start
                      : CrossAxisAlignment.center),
              children: <Widget>[
                // if (widget.toolTipWidget != null) widget.toolTipWidget!,
                if (widget.title != null)
                  Padding(
                    padding: widget.titlePadding ?? EdgeInsets.zero,
                    child: Text(
                      widget.title!,
                      textAlign: widget.titleAlignment,
                      textDirection: widget.titleTextDirection,
                      style: widget.titleTextStyle ??
                          Theme.of(context).textTheme.titleLarge!.merge(
                                TextStyle(
                                  color: widget.textColor,
                                ),
                              ),
                    ),
                  ),
                if (widget.description != null)
                  Padding(
                    padding: widget.descriptionPadding ?? EdgeInsets.zero,
                    child: Text(
                      widget.description!,
                      textAlign: widget.descriptionAlignment,
                      textDirection: widget.descriptionTextDirection,
                      style: widget.descTextStyle ??
                          Theme.of(context).textTheme.titleSmall!.merge(
                                TextStyle(
                                  color: widget.textColor,
                                ),
                              ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void onSizeChange(Size? size) {
    var tempPos = position;
    tempPos = Offset(position!.dx, position!.dy + size!.height);
    setState(() => position = tempPos);
  }

  Size _textSize(String text, TextStyle style) {
    final textPainter = TextPainter(
      text: TextSpan(text: text, style: style),
      maxLines: 1,
      // TODO: replace this once we support sdk v3.12.
      // ignore: deprecated_member_use
      textScaleFactor: MediaQuery.of(context).textScaleFactor,
      textDirection: TextDirection.ltr,
    )..layout();
    return textPainter.size;
  }

  double? _getArrowLeft(double arrowWidth) {
    if (isArrowLeft || isArrowRight) return null;

    final left = _getLeft();
    if (left == null) return null;
    return (widget.position!.getCenter() - (arrowWidth / 2) - left);
  }

  double? _getArrowRight(double arrowWidth) {
    if (isArrowLeft || isArrowRight) return null;

    if (_getLeft() != null) return null;
    return (widget.screenSize.width - widget.position!.getCenter()) -
        (_getRight() ?? 0) -
        (arrowWidth / 2);
  }

  double? _getArrowTop(double arrowWidth) {
    if (isArrowUp || isArrowDown) return null;

    final top = _getTop() ?? 0;
    return (widget.position!.getCenter() - (arrowWidth / 2) - top);
  }

  double? _getArrowBottom(double arrowWidth) {
    if (isArrowUp || isArrowDown) return null;

    return null; // Not currently needed but kept for consistency
  }
}

class _Arrow extends CustomPainter {
  final Color strokeColor;
  final PaintingStyle paintingStyle;
  final double strokeWidth;
  final bool isUpArrow;
  final bool isDownArrow;
  final bool isLeftArrow;
  final bool isRightArrow;
  final Paint _paint;

  _Arrow({
    this.strokeColor = Colors.black,
    this.strokeWidth = 3,
    this.paintingStyle = PaintingStyle.stroke,
    this.isUpArrow = false,
    this.isDownArrow = false,
    this.isLeftArrow = false,
    this.isRightArrow = false,
  }) : _paint = Paint()
          ..color = strokeColor
          ..strokeWidth = strokeWidth
          ..style = paintingStyle;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(getTrianglePath(size.width, size.height), _paint);
  }

  Path getTrianglePath(double x, double y) {
    if (isUpArrow) {
      return Path()
        ..moveTo(0, y)
        ..conicTo(x / 2, -y / 2, x, y, 3);
    } else if (isDownArrow) {
      return Path()
        ..moveTo(0, 0)
        ..conicTo(x / 2, y * 1.5, x, 0, 3);
    } else if (isLeftArrow) {
      return Path()
        ..moveTo(x, 0)
        ..conicTo(-x / 2.5, y / 2, x, y, 3);
    } else if (isRightArrow) {
      return Path()
        ..moveTo(0, 0)
        ..conicTo(x * 1.5, y / 2, 0, y, 3);
    }

    // Default case
    return Path()
      ..moveTo(0, y)
      ..conicTo(x / 2, -y / 2, x, y, 3);
  }

  @override
  bool shouldRepaint(covariant _Arrow oldDelegate) {
    return oldDelegate.strokeColor != strokeColor ||
        oldDelegate.paintingStyle != paintingStyle ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.isUpArrow != isUpArrow ||
        oldDelegate.isDownArrow != isDownArrow ||
        oldDelegate.isLeftArrow != isLeftArrow ||
        oldDelegate.isRightArrow != isRightArrow;
  }
}
