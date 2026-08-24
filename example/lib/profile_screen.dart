import 'package:flutter/material.dart';

/// A second screen with nothing but its own name — just enough for
/// `FlightRecorderNavigatorObserver` to record a real push/pop pair when
/// the home screen's "Navigate" button pushes it.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: const Center(child: Text('Edit Profile')),
    );
  }
}
