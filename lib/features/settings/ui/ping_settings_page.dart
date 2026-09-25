import 'package:flutter/material.dart';
import 'package:slipstream/core/theme/app_theme.dart';
import 'package:slipstream/features/ping/presentation/ui/ping_settings_section.dart';
import 'package:slipstream/features/settings/ui/widgets/help_sheet.dart';
import 'package:slipstream/features/settings/ui/widgets/settings_card.dart';

class PingSettingsPage extends StatelessWidget {
  const PingSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ping'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: 'Об этих настройках',
            onPressed: () => showHelpSheet(
              context,
              title: 'Пинг',
              entries: const [
                HelpEntry(
                  title: 'Замер',
                  body:
                      'TCP-подключение к серверу, для Hysteria2 — UDP (QUIC). '
                      'До 3 попыток, итог — медиана.\n'
                      'Проверяет только доступность сервера, не '
                      'работоспособность VPN.',
                ),
                HelpEntry(
                  title: 'Обозначения',
                  body:
                      'зелёный — до 80 мс\n'
                      'жёлтый — 80–160 мс\n'
                      'красный — больше 160 мс\n'
                      'timeout — сервер не ответил\n'
                      'refused — подключение отклонено, порт закрыт\n'
                      'no dns — адрес сервера не найден\n'
                      'error — сетевая ошибка, обычно на стороне устройства\n'
                      'n/a — замер для этого протокола недоступен (mKCP)',
                ),
                HelpEntry(
                  title: 'Ping on launch',
                  body:
                      'Замер всех серверов при запуске. Вручную — кнопка у '
                      'подписки или свайп вниз по списку.',
                ),
                HelpEntry(
                  title: 'Sort servers by latency',
                  body:
                      'Сортировка по пингу после завершения замера. Во время '
                      'замера порядок не меняется.',
                ),
                HelpEntry(
                  title: 'Latency display',
                  body: 'Numbers — значение в мс. Dots — только цвет.',
                ),
              ],
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppDims.horizontalPadding,
          AppDims.gapS,
          AppDims.horizontalPadding,
          AppDims.gapXxl,
        ),
        children: [
          const SectionHeader('Ping'),
          const PingSettingsSection(),
        ],
      ),
    );
  }
}
