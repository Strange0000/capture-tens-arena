import 'package:flutter/material.dart';

/// Non-web placeholder for the Google Identity Services button.
/// The GIS button only exists on web; off-web the login screen uses its own
/// native Google button instead.
class GisButton extends StatelessWidget {
  const GisButton({
    super.key,
    required this.minimumWidth,
    required this.compact,
  });

  final double minimumWidth;
  final bool compact;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
