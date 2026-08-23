import 'package:flutter/material.dart';

class BrandMark extends StatelessWidget {
  const BrandMark({
    super.key,
    this.size = 52,
    this.showShadow = true,
  });

  final double size;
  final bool showShadow;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final radius = size * .31;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [scheme.primary, scheme.secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(radius),
        boxShadow: showShadow
            ? [
                BoxShadow(
                  color: scheme.primary.withValues(alpha: .20),
                  blurRadius: size * .30,
                  offset: Offset(0, size * .12),
                ),
              ]
            : null,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: size * .48,
            height: size * .58,
            decoration: BoxDecoration(
              border: Border.all(
                color: Colors.white,
                width: size * .055,
              ),
              borderRadius: BorderRadius.circular(size * .09),
            ),
          ),
          Positioned(
            top: size * .17,
            child: Container(
              width: size * .22,
              height: size * .09,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(size),
              ),
            ),
          ),
          Positioned(
            bottom: size * .24,
            child: Icon(
              Icons.check_rounded,
              color: Colors.white,
              size: size * .30,
            ),
          ),
        ],
      ),
    );
  }
}
