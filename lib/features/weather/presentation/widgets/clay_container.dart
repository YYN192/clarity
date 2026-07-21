import 'package:flutter/material.dart' hide BoxShadow, BoxDecoration;
import 'package:flutter_inset_shadow/flutter_inset_shadow.dart';
import '../../../../core/theme/app_colors.dart';

/// The Clarity neumorphic surface.
///
/// Raised ("extruded") by default. Pass [inset] `true` for a sunken
/// ("pressed into the clay") surface — used for grouped/molded containers,
/// badges, inset icon chips, and input fields.
class ClayContainer extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final Color? color;
  final EdgeInsetsGeometry? padding;
  final BoxShape shape;
  final bool inset;

  const ClayContainer({
    super.key,
    required this.child,
    this.borderRadius = 32,
    this.color,
    this.padding,
    this.shape = BoxShape.rectangle,
    this.inset = false,
  });

  @override
  Widget build(BuildContext context) {
    final baseColor = color ?? AppColors.getCardColor();

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: baseColor,
        shape: shape,
        borderRadius: shape == BoxShape.rectangle ? BorderRadius.circular(borderRadius) : null,
        boxShadow: inset
            ? [
                // Sunken — shadows cast inward for a "pressed" look.
                BoxShadow(
                  inset: true,
                  color: AppColors.shadowDark,
                  offset: const Offset(3, 3),
                  blurRadius: 6,
                ),
                const BoxShadow(
                  inset: true,
                  color: AppColors.shadowLight,
                  offset: Offset(-3, -3),
                  blurRadius: 6,
                ),
              ]
            : [
                // Raised — bottom-right depth + top-left highlight.
                BoxShadow(
                  color: AppColors.shadowDark,
                  offset: const Offset(8, 8),
                  blurRadius: 16,
                  spreadRadius: 1,
                ),
                const BoxShadow(
                  color: AppColors.shadowLight,
                  offset: Offset(-8, -8),
                  blurRadius: 16,
                  spreadRadius: 1,
                ),
              ],
      ),
      child: child,
    );
  }
}
