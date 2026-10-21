import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:slipstream/app/app_assets.dart';
import 'package:slipstream/core/theme/app_colors.dart';

class SubscriptionSearchBar extends StatefulWidget {
  const SubscriptionSearchBar({
    super.key,
    required this.colors,
    required this.controller,
  });

  final AppColors colors;
  final TextEditingController controller;

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
    final border = OutlineInputBorder(
      borderRadius: .circular(14),
      borderSide: BorderSide(color: colors.border),
    );

    return TextField(
      controller: widget.controller,
      textInputAction: .search,
      style: TextStyle(
        fontSize: 13.5,
        fontWeight: .w500,
        color: colors.textPrimary,
      ),
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: colors.surface,
        border: border,
        enabledBorder: border,
        focusedBorder: border,
        contentPadding: const .symmetric(vertical: 13),
        hintText: 'Search servers, countries or protocols',
        prefixIcon: Padding(
          padding: const .fromLTRB(14, 0, 9, 0),
          child: SvgPicture.asset(
            AppAssets.search,
            width: 15,
            height: 15,
            colorFilter: .mode(colors.textSecondary, .srcIn),
          ),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 38),
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
    );
  }
}
