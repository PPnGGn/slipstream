import 'package:flutter/material.dart';
import 'package:slipstream/app/theme.dart';

class EmptySubscriptions extends StatelessWidget {
  const EmptySubscriptions({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 80,
              width: 80,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.gray181F25,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.border),
              ),
              child: const Icon(
                Icons.cloud_off_rounded,
                size: 36,
                color: AppColors.grayA9BAC6,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Нет подписок',
              style: TextStyle(
                color: AppColors.white,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Добавьте подписку кнопкой + сверху:\nURL, vless://, ss:// или JSON',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.grayA9BAC6, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
