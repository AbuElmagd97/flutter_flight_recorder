import 'package:flutter/material.dart';

import '../config/floating_button_config.dart';

const Key floatingTriggerButtonKey = Key(
  'flutter_flight_recorder_reporter_floating_button',
);

class FloatingTriggerButton extends StatelessWidget {
  const FloatingTriggerButton({
    super.key,
    required this.config,
    required this.onPressed,
  });

  final FloatingButtonConfig config;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: config.alignment,
      child: Padding(
        padding: config.padding,
        child: Material(
          color: Colors.black87,
          shape: const CircleBorder(),
          elevation: 4,
          child: InkWell(
            key: floatingTriggerButtonKey,
            onTap: onPressed,
            customBorder: const CircleBorder(),
            child: const Padding(
              padding: EdgeInsets.all(14),
              child: Icon(
                Icons.bug_report,
                color: Colors.white,
                semanticLabel: 'Report a problem',
              ),
            ),
          ),
        ),
      ),
    );
  }
}
