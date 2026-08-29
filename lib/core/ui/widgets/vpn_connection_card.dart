
import 'package:flutter/material.dart';
import 'package:slipstream/app/di/injector.dart';
import 'package:slipstream/core/theme/app_colors.dart';

class VPNConectionCard extends StatelessWidget {
  const VPNConectionCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 160,
      width: double.infinity,
      decoration: BoxDecoration(
        color: getIt<AppColors>().surface,
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }
}