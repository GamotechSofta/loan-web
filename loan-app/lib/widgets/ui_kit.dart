import 'package:flutter/material.dart';

import '../config/animations.dart';
import '../config/theme.dart';

/// Centred screen header: back chevron on the left, title and caption centred.
class AppScreenHeader extends StatelessWidget {
  const AppScreenHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.onBack,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final VoidCallback? onBack;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 40,
            child: onBack == null
                ? null
                : IconButton(
                    onPressed: onBack,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: 40,
                      height: 40,
                    ),
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 18,
                    ),
                    color: AppColors.slate800,
                  ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Column(
                children: [
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppColors.slate900,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      subtitle!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.slate500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          SizedBox(width: 40, child: trailing),
        ],
      ),
    );
  }
}

/// Numbered step rail with a connector line and captions underneath.
class StepProgress extends StatelessWidget {
  const StepProgress({
    super.key,
    required this.steps,
    required this.activeStep,
  });

  /// Captions in order; the first entry is step 1.
  final List<String> steps;
  final int activeStep;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final slot = constraints.maxWidth / steps.length;
        return Stack(
          children: [
            Positioned(
              left: slot / 2,
              right: slot / 2,
              top: 13,
              child: Container(height: 2, color: AppColors.line),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < steps.length; i++)
                  SizedBox(
                    width: slot,
                    child: _StepNode(
                      index: i + 1,
                      label: steps[i],
                      active: i + 1 == activeStep,
                      done: i + 1 < activeStep,
                    ),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _StepNode extends StatelessWidget {
  const _StepNode({
    required this.index,
    required this.label,
    required this.active,
    required this.done,
  });

  final int index;
  final String label;
  final bool active;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final filled = active || done;
    return Column(
      children: [
        AnimatedContainer(
          duration: AppMotion.card,
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: filled ? AppColors.brand : AppColors.slate100,
          ),
          child: done
              ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
              : Text(
                  '$index',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: filled ? Colors.white : AppColors.slate400,
                  ),
                ),
        ),
        const SizedBox(height: 7),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 10.5,
            height: 1.25,
            fontWeight: active ? FontWeight.w600 : FontWeight.w500,
            color: active ? AppColors.slate900 : AppColors.slate400,
          ),
        ),
      ],
    );
  }
}

/// Plain white surface with a hairline border, used for grouped content.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.radius = AppRadius.card,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final double radius;

  @override
  Widget build(BuildContext context) {
    if (onTap == null) return _surface(lifted: false);
    return LiftOnInteract(
      onTap: onTap,
      lift: 2,
      builder: (context, active) => _surface(lifted: active),
    );
  }

  Widget _surface({required bool lifted}) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AppColors.line),
        boxShadow: lifted ? shadowCardHover : shadowCard,
      ),
      child: child,
    );
  }
}

/// Blue gradient card used for the primary call to action.
class FeatureCard extends StatelessWidget {
  const FeatureCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        gradient: brandCardGradient,
        borderRadius: BorderRadius.circular(AppRadius.feature),
        boxShadow: shadowBrandCard,
      ),
      child: child,
    );
  }
}

/// Decorative coin/money illustration that sits in the corner of a feature card.
class MoneyGlyph extends StatelessWidget {
  const MoneyGlyph({super.key, this.size = 56});

  final double size;

  @override
  Widget build(BuildContext context) {
    return FloatSoft(
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          children: [
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: size * 0.62,
                height: size * 0.62,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.gold.withValues(alpha: 0.9),
                ),
              ),
            ),
            Positioned(
              left: 0,
              top: 0,
              child: Container(
                width: size * 0.78,
                height: size * 0.78,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.amber200,
                  border: Border.all(color: AppColors.gold, width: 2),
                ),
                child: Icon(
                  Icons.currency_rupee_rounded,
                  size: size * 0.38,
                  color: AppColors.goldDeep,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// White pill button used on top of the blue feature cards.
class OnBrandButton extends StatelessWidget {
  const OnBrandButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 46,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: AppColors.brand,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.button),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        child: Text(label),
      ),
    );
  }
}

/// White card with a tinted icon tile, supporting copy and a trailing arrow.
class ActionCard extends StatelessWidget {
  const ActionCard({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String description;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.slate900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      description,
                      style: const TextStyle(
                        fontSize: 12.5,
                        height: 1.4,
                        color: AppColors.slate500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.brandSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 21, color: AppColors.brand),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Align(
            alignment: Alignment.centerRight,
            child: Icon(
              Icons.arrow_forward_rounded,
              size: 18,
              color: AppColors.slate400,
            ),
          ),
        ],
      ),
    );
  }
}

/// Centred reassurance line, e.g. "Your data is 100% secure with us".
class SecureNote extends StatelessWidget {
  const SecureNote({
    super.key,
    required this.text,
    this.icon = Icons.verified_user_outlined,
  });

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 14, color: AppColors.slate400),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(fontSize: 11.5, color: AppColors.slate500),
        ),
      ],
    );
  }
}

class SectionHeading extends StatelessWidget {
  const SectionHeading(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w700,
              color: AppColors.slate900,
            ),
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

/// Label/value row used inside the loan detail cards.
class DetailRow extends StatelessWidget {
  const DetailRow({
    super.key,
    required this.label,
    required this.value,
    this.emphasise = false,
  });

  final String label;
  final String value;
  final bool emphasise;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, color: AppColors.slate500),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: emphasise ? AppColors.green700 : AppColors.slate900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum StatusTone { success, pending, rejected, info }

/// Tinted status card with an icon, headline, supporting copy and an arrow.
class StatusBanner extends StatelessWidget {
  const StatusBanner({
    super.key,
    required this.tone,
    required this.title,
    required this.message,
    this.onTap,
  });

  final StatusTone tone;
  final String title;
  final String message;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final (bg, border, fg, icon) = switch (tone) {
      StatusTone.success => (
        AppColors.green50,
        AppColors.green200,
        AppColors.green700,
        Icons.check_circle_outline_rounded,
      ),
      StatusTone.pending => (
        AppColors.amber50,
        AppColors.amber200,
        AppColors.amber700,
        Icons.schedule_rounded,
      ),
      StatusTone.rejected => (
        AppColors.red50,
        AppColors.red200,
        AppColors.red600,
        Icons.error_outline_rounded,
      ),
      StatusTone.info => (
        AppColors.brandSoft,
        AppColors.brandSoftDeep,
        AppColors.brandDeep,
        Icons.info_outline_rounded,
      ),
    };

    final body = Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 22, color: fg),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: fg,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  message,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    color: fg.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
          if (onTap != null) ...[
            const SizedBox(width: 8),
            Icon(Icons.arrow_forward_rounded, size: 18, color: fg),
          ],
        ],
      ),
    );

    if (onTap == null) return body;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: body,
      ),
    );
  }
}

class AppNavDestination {
  const AppNavDestination(this.icon, this.label);

  final IconData icon;
  final String label;
}

/// Compact floating pill bar; the selected item expands to show its label.
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    super.key,
    required this.destinations,
    required this.currentIndex,
    required this.onSelect,
  });

  final List<AppNavDestination> destinations;
  final int currentIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 6, 24, 12 + bottomInset),
      child: Center(
        heightFactor: 1,
        child: Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: AppColors.line),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1F0F172A),
                blurRadius: 20,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < destinations.length; i++)
                _NavItem(
                  destination: destinations[i],
                  selected: i == currentIndex,
                  onTap: () => onSelect(i),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final AppNavDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? Colors.white : AppColors.slate500;
    return Semantics(
      selected: selected,
      button: true,
      label: destination.label,
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: AnimatedContainer(
          duration: AppMotion.card,
          curve: Curves.easeOutCubic,
          height: 42,
          padding: EdgeInsets.symmetric(horizontal: selected ? 16 : 14),
          decoration: BoxDecoration(
            color: selected ? AppColors.brand : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
          ),
          child: AnimatedSize(
            duration: AppMotion.card,
            curve: Curves.easeOutCubic,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(destination.icon, size: 20, color: color),
                if (selected) ...[
                  const SizedBox(width: 6),
                  Text(
                    destination.label,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
