import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:slipstream/app/app_assets.dart';
import 'package:slipstream/core/theme/app_colors.dart';
import 'package:slipstream/core/ui/widgets/custom_icon_button.dart';

class SubscriptionSearchBar extends StatefulWidget {
  const SubscriptionSearchBar({
    super.key,
    required this.colors,
    required this.controller,
    required this.onAddSubscription,
  });

  final AppColors colors;
  final TextEditingController controller;
  final VoidCallback onAddSubscription;

  @override
  State<SubscriptionSearchBar> createState() => _SubscriptionSearchBarState();
}

class _SubscriptionSearchBarState extends State<SubscriptionSearchBar> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;

    return Row(
      spacing: 10,
      children: [
        Expanded(
          child: TextField(
            controller: widget.controller,
            textInputAction: .search,
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Search servers, countries or protocols',
              prefixIcon: Padding(
                padding: const .all(14),
                child: SvgPicture.asset(
                  AppAssets.search,
                  colorFilter: .mode(colors.textSecondary, .srcIn),
                ),
              ),
              prefixIconConstraints: const BoxConstraints(
                minWidth: 44,
                minHeight: 44,
              ),
              suffixIcon: widget.controller.text.isEmpty
                  ? null
                  : GestureDetector(
                      onTap: () => widget.controller.clear(),
                      child: Padding(
                        padding: const .all(15),
                        child: SvgPicture.asset(
                          AppAssets.close,
                          colorFilter: .mode(colors.textSecondary, .srcIn),
                        ),
                      ),
                    ),
              suffixIconConstraints: const BoxConstraints(
                minWidth: 44,
                minHeight: 44,
              ),
            ),
          ),
        ),
        CustomIconButton(
          onTap: widget.onAddSubscription,
          iconPath: AppAssets.plus,
          gradientColors: colors.brandGradient,
        ),
      ],
    );
  }
}
