import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../config/animations.dart';
import '../config/company_content.dart';
import '../config/theme.dart';
import '../state/app_state.dart';
import '../utils/user_notifications.dart';
import '../widgets/brand_icon.dart';
import '../widgets/notification_bell.dart';
import '../widgets/ui_kit.dart';
import 'applications_screen.dart';
import 'support_screen.dart';

const List<AppNavDestination> _destinations = [
  AppNavDestination(Icons.headset_mic_outlined, 'Support'),
  AppNavDestination(Icons.home_rounded, 'Home'),
  AppNavDestination(Icons.person_outline_rounded, 'Profile'),
];

/// Signed-in shell: Support / Home / Profile behind a bottom bar.
class HomeShell extends StatelessWidget {
  const HomeShell({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Scaffold(
      backgroundColor: AppColors.surfaceMuted,
      extendBody: true,
      body: IndexedStack(
        sizing: StackFit.expand,
        index: state.homeTab,
        children: const [
          SafeArea(bottom: false, child: SupportView()),
          AnnotatedRegion<SystemUiOverlayStyle>(
            value: SystemUiOverlayStyle.light,
            child: HomeDashboard(),
          ),
          SafeArea(bottom: false, child: ProfileView()),
        ],
      ),
      bottomNavigationBar: AppBottomNav(
        destinations: _destinations,
        currentIndex: state.homeTab,
        onSelect: state.setHomeTab,
      ),
    );
  }
}

bool _hasApplication(Map<String, dynamic> profile) {
  if (profile['application'] is Map) return true;
  final applications = profile['applications'];
  return applications is List && applications.isNotEmpty;
}

/// Mirrors `frontend/src/website/pages/HomePage.jsx` at mobile width.
class HomeDashboard extends StatefulWidget {
  const HomeDashboard({super.key});

  @override
  State<HomeDashboard> createState() => _HomeDashboardState();
}

class _HomeDashboardState extends State<HomeDashboard> {
  final _aboutKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  Future<void> _refresh() async {
    final state = context.read<AppState>();
    if (state.userToken.isEmpty) return;
    final result = await state.api.getProfile(state.userToken);
    if (!mounted) return;
    if (result.statusCode == 401 || result.statusCode == 403) {
      await state.clearUserSession();
      return;
    }
    if (result.ok) state.setUserProfile(result.data);
  }

  void _scrollToAbout() {
    final target = _aboutKey.currentContext;
    if (target == null) return;
    Scrollable.ensureVisible(
      target,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final profile = state.userProfile ?? const <String, dynamic>{};
    final hasApplication = _hasApplication(profile);
    final VoidCallback primaryAction = hasApplication
        ? () => state.setHomeTab(HomeTab.profile)
        : state.startApplication;
    final primaryLabel = hasApplication ? 'View Application' : 'Apply Now';

    final topInset = MediaQuery.paddingOf(context).top;

    return ColoredBox(
      color: AppColors.siteSurface,
      child: RefreshIndicator(
        onRefresh: _refresh,
        edgeOffset: topInset,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DecoratedBox(
                decoration: const BoxDecoration(gradient: siteHeroGradient),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: EdgeInsets.fromLTRB(20, 16 + topInset, 20, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _Greeting(profile: profile),
                          const SizedBox(height: 16),
                          _ApplicationStatus(profile: profile),
                        ],
                      ),
                    ),
                    _Hero(
                      primaryLabel: primaryLabel,
                      onPrimary: primaryAction,
                      onKnowMore: _scrollToAbout,
                    ),
                  ],
                ),
              ),
              _Section(
                key: _aboutKey,
                title: 'About Sakaar Foundation',
                subtitle:
                    'Building Financial Independence for Every Individual',
                child: const _AboutBody(),
              ),
              _Section(
                title: 'Why Choose Sakaar Foundation',
                subtitle: 'Trusted Financial Solutions Designed Around You',
                white: true,
                child: _CardList(items: whyChoose),
              ),
              _Section(
                title: 'Our Services',
                subtitle: 'Financial Solutions That Empower Growth',
                child: _CardList(items: services),
              ),
              _Section(
                title: 'Our Process',
                subtitle: 'Four Simple Steps',
                white: true,
                child: Column(
                  children: [
                    for (var i = 0; i < processSteps.length; i++) ...[
                      if (i > 0) const SizedBox(height: 14),
                      _ProcessCard(step: processSteps[i], index: i),
                    ],
                  ],
                ),
              ),
              const _Section(
                child: Column(
                  children: [
                    _StatementCard(
                      icon: 'spark',
                      title: 'Our Vision',
                      text:
                          "To become one of India's most trusted organizations in financial inclusion by empowering individuals, encouraging entrepreneurship, and contributing to sustainable economic development.",
                    ),
                    SizedBox(height: 14),
                    _StatementCard(
                      icon: 'heart',
                      title: 'Our Mission',
                      text:
                          'To provide transparent, accessible, and responsible financial solutions that improve lives, promote self-reliance, and strengthen communities through ethical business practices and customer-focused services.',
                    ),
                  ],
                ),
              ),
              _Section(
                title: 'Our Core Values',
                white: true,
                child: _CardList(items: coreValues, fallbackIcon: 'check'),
              ),
              _Section(
                title: 'What Makes Us Different',
                child: Column(
                  children: [
                    for (var i = 0; i < differentiators.length; i++) ...[
                      if (i > 0) const SizedBox(height: 10),
                      _BulletRow(text: differentiators[i]),
                    ],
                  ],
                ),
              ),
              const _TestimonialsSection(),
              _Section(
                title: 'Frequently Asked Questions',
                white: true,
                child: Column(
                  children: [
                    for (var i = 0; i < homeFaq.length; i++) ...[
                      if (i > 0) const SizedBox(height: 10),
                      _FaqTile(item: homeFaq[i]),
                    ],
                  ],
                ),
              ),
              _CtaBanner(
                primaryLabel: primaryLabel,
                onPrimary: primaryAction,
                onContact: () => state.setHomeTab(HomeTab.support),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting({required this.profile});

  final Map<String, dynamic> profile;

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final fullName = '${profile['fullName'] ?? ''}'.trim();
    final firstName = fullName.isEmpty ? 'there' : fullName.split(' ').first;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hello, $firstName 👋',
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 3),
              const Text(
                'Welcome to Sakaar Foundation',
                style: TextStyle(fontSize: 12.5, color: Color(0xB3FFFFFF)),
              ),
            ],
          ),
        ),
        if (profile.isNotEmpty)
          NotificationBell(
            profile: profile,
            onDark: true,
            onViewProfile: () => state.setHomeTab(HomeTab.profile),
          ),
      ],
    );
  }
}

class _ApplicationStatus extends StatelessWidget {
  const _ApplicationStatus({required this.profile});

  final Map<String, dynamic> profile;

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();

    if (!_hasApplication(profile)) {
      return _HeaderStatusCard(
        icon: Icons.info_outline_rounded,
        accent: AppColors.siteGold,
        title: 'No Application Yet',
        message: 'Start your loan application and get approval in minutes.',
        onTap: state.startApplication,
      );
    }

    if (isLoanFullyApproved(profile)) {
      return _HeaderStatusCard(
        icon: Icons.check_circle_outline_rounded,
        accent: const Color(0xFF34D399),
        title: 'Application Approved',
        message: 'Congratulations! Your loan has been approved.',
        onTap: () => state.setHomeTab(HomeTab.profile),
      );
    }

    final application = profile['application'];
    final counts = application is Map ? application['counts'] : null;
    final rejected = counts is Map
        ? (counts['rejected'] as num?)?.toInt() ?? 0
        : 0;
    final status = application is Map ? '${application['status'] ?? ''}' : '';
    if (status == 'rejected' || rejected > 0) {
      return _HeaderStatusCard(
        icon: Icons.error_outline_rounded,
        accent: const Color(0xFFF87171),
        title: 'Action Needed',
        message:
            'Some documents were rejected. Please re-upload them to continue.',
        onTap: () => state.setHomeTab(HomeTab.profile),
      );
    }

    return _HeaderStatusCard(
      icon: Icons.schedule_rounded,
      accent: const Color(0xFFFBBF24),
      title: 'Application Under Review',
      message: 'We are verifying your details. This usually takes a few hours.',
      onTap: () => state.setHomeTab(HomeTab.profile),
    );
  }
}

/// Translucent status card that sits on the navy header.
class _HeaderStatusCard extends StatelessWidget {
  const _HeaderStatusCard({
    required this.icon,
    required this.accent,
    required this.title,
    required this.message,
    required this.onTap,
  });

  final IconData icon;
  final Color accent;
  final String title;
  final String message;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0x14FFFFFF),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0x33FFFFFF)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 20, color: accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      message,
                      style: const TextStyle(
                        fontSize: 12.5,
                        height: 1.4,
                        color: Color(0xCCFFFFFF),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right_rounded,
                size: 22,
                color: Color(0x99FFFFFF),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({
    required this.primaryLabel,
    required this.onPrimary,
    required this.onKnowMore,
  });

  final String primaryLabel;
  final VoidCallback onPrimary;
  final VoidCallback onKnowMore;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const FadeUp(
            child: Text(
              HomeHero.title,
              style: TextStyle(
                fontSize: 34,
                height: 1.08,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
          FadeUp.delayed(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 18),
                const Text(
                  HomeHero.subtitle,
                  style: TextStyle(
                    fontSize: 16,
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  HomeHero.note,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.55,
                    color: Color(0xE6FFFFFF),
                  ),
                ),
                const SizedBox(height: 26),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _GoldButton(label: primaryLabel, onPressed: onPrimary),
                    _OutlineLightButton(
                      label: 'Know More',
                      onPressed: onKnowMore,
                    ),
                  ],
                ),
                const SizedBox(height: 26),
                const _LoanAmountCard(),
                const SizedBox(height: 22),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    border: Border.symmetric(
                      horizontal: BorderSide(
                        color: AppColors.siteGold.withValues(alpha: 0.35),
                      ),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var i = 0; i < HomeHero.highlights.length; i++) ...[
                        if (i > 0) const SizedBox(height: 10),
                        Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: AppColors.siteGold,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              HomeHero.highlights[i],
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LoanAmountCard extends StatelessWidget {
  const _LoanAmountCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.siteGold,
        borderRadius: BorderRadius.circular(24),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Get Loans up to',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 4),
          Text(
            '₹2,00,000',
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Get cash in your account in just 5 minutes.',
            style: TextStyle(fontSize: 14, color: Color(0xF2FFFFFF)),
          ),
        ],
      ),
    );
  }
}

class _GoldButton extends StatelessWidget {
  const _GoldButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.siteGold,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        splashColor: AppColors.siteGoldDeep,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              const BrandIcon('arrow', size: 16, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}

class _OutlineLightButton extends StatelessWidget {
  const _OutlineLightButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Colors.white, width: 2),
      ),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    super.key,
    this.title,
    this.subtitle,
    this.white = false,
    required this.child,
  });

  final String? title;
  final String? subtitle;
  final bool white;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: white ? Colors.white : AppColors.siteSurface,
      padding: const EdgeInsets.fromLTRB(20, 36, 20, 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null)
            Text(
              title!,
              style: const TextStyle(
                fontSize: 26,
                height: 1.2,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(
              subtitle!,
              style: const TextStyle(fontSize: 15, color: AppColors.slate600),
            ),
          ],
          if (title != null) const SizedBox(height: 22),
          child,
        ],
      ),
    );
  }
}

class _AboutBody extends StatelessWidget {
  const _AboutBody();

  static const _stats = [
    ('Founded', '2016'),
    ('Organization Type', 'Section 8 Foundation'),
    ('Focus', 'Financial Inclusion'),
    ('Approach', 'Transparent & Digital'),
  ];

  @override
  Widget build(BuildContext context) {
    const bodyStyle = TextStyle(
      fontSize: 14,
      height: 1.6,
      color: AppColors.slate600,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Established in 2016, Sakaar Foundation is a professionally managed Section 8 Microcredit Foundation dedicated to promoting financial inclusion and socio-economic development across India. Our objective is to empower individuals and small entrepreneurs by providing responsible financial services that improve livelihoods and encourage self-reliance.',
          style: bodyStyle,
        ),
        const SizedBox(height: 14),
        const Text(
          'Guided by our commitment to integrity, transparency, and customer satisfaction, we strive to bridge the gap between underserved communities and accessible financial services. As a not-for-profit organization, our focus remains on creating sustainable economic opportunities while supporting socially and economically marginalized communities, especially women and families in rural and semi-urban areas.',
          style: bodyStyle,
        ),
        const SizedBox(height: 22),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.slate200),
            boxShadow: shadowSm,
          ),
          child: Column(
            children: [
              for (var i = 0; i < _stats.length; i++) ...[
                if (i > 0) const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.siteSoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _stats[i].$1.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 11,
                          letterSpacing: 0.6,
                          fontWeight: FontWeight.w600,
                          color: AppColors.siteGold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _stats[i].$2,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _IconTile extends StatelessWidget {
  const _IconTile(this.icon);

  final String icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.siteSoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: BrandIcon(icon, size: 20, color: AppColors.siteNavy),
    );
  }
}

class _CardList extends StatelessWidget {
  const _CardList({required this.items, this.fallbackIcon});

  final List<ContentCard> items;
  final String? fallbackIcon;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(height: 14),
          _InfoCard(card: items[i], icon: items[i].icon ?? fallbackIcon),
        ],
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.card, this.icon});

  final ContentCard card;
  final String? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.slate200),
        boxShadow: shadowCard,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[_IconTile(icon!), const SizedBox(height: 14)],
          Text(
            card.title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: AppColors.slate900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            card.text,
            style: const TextStyle(
              fontSize: 14,
              height: 1.55,
              color: AppColors.slate600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProcessCard extends StatelessWidget {
  const _ProcessCard({required this.step, required this.index});

  final ProcessStep step;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.slate200),
        boxShadow: shadowSm,
      ),
      child: Stack(
        children: [
          Positioned(
            right: -6,
            top: -16,
            child: Text(
              '${index + 1}',
              style: const TextStyle(
                fontSize: 64,
                fontWeight: FontWeight.w700,
                color: AppColors.slate100,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step.step.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 12,
                    letterSpacing: 2,
                    fontWeight: FontWeight.w700,
                    color: AppColors.siteNavy,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  step.title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: AppColors.slate900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  step.text,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.55,
                    color: AppColors.slate600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatementCard extends StatelessWidget {
  const _StatementCard({
    required this.icon,
    required this.title,
    required this.text,
  });

  final String icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.slate200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _IconTile(icon),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.slate900,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              height: 1.6,
              color: AppColors.slate600,
            ),
          ),
        ],
      ),
    );
  }
}

class _BulletRow extends StatelessWidget {
  const _BulletRow({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.slate200),
        boxShadow: shadowSm,
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.siteSoft,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const BrandIcon(
              'check',
              size: 16,
              color: AppColors.siteNavy,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.slate700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TestimonialsSection extends StatelessWidget {
  const _TestimonialsSection();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Customer Testimonials',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'What Our Customers Say',
                  style: TextStyle(fontSize: 15, color: AppColors.slate600),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < testimonials.length; i++) ...[
                    if (i > 0) const SizedBox(width: 14),
                    _TestimonialCard(item: testimonials[i]),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TestimonialCard extends StatelessWidget {
  const _TestimonialCard({required this.item});

  final Testimonial item;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 290,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.slate200),
        boxShadow: shadowTestimonial,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const BrandStars(),
          const SizedBox(height: 14),
          Expanded(
            child: Text(
              '"${item.quote}"',
              style: const TextStyle(
                fontSize: 14,
                height: 1.55,
                color: AppColors.slate600,
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: AppColors.slate100),
          const SizedBox(height: 14),
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: AppColors.siteSoft,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  item.initials,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.siteNavy,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.slate900,
                      ),
                    ),
                    Text(
                      item.role,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.slate500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FaqTile extends StatefulWidget {
  const _FaqTile({required this.item});

  final FaqItem item;

  @override
  State<_FaqTile> createState() => _FaqTileState();
}

class _FaqTileState extends State<_FaqTile> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _open ? AppColors.sky200 : AppColors.slate200,
        ),
        boxShadow: shadowSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() => _open = !_open),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.item.question,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.slate900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  AnimatedRotation(
                    turns: _open ? 0.125 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 32,
                      height: 32,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _open ? AppColors.siteSoft : AppColors.slate100,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.add,
                        size: 18,
                        color: _open ? AppColors.siteNavy : AppColors.slate500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            child: _open
                ? Container(
                    decoration: const BoxDecoration(
                      border: Border(
                        top: BorderSide(color: AppColors.slate100),
                      ),
                    ),
                    padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
                    child: Text(
                      widget.item.answer,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.55,
                        color: AppColors.slate600,
                      ),
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

class _CtaBanner extends StatelessWidget {
  const _CtaBanner({
    required this.primaryLabel,
    required this.onPrimary,
    required this.onContact,
  });

  final String primaryLabel;
  final VoidCallback onPrimary;
  final VoidCallback onContact;

  @override
  Widget build(BuildContext context) {
    final navClearance = MediaQuery.paddingOf(context).bottom;
    return Container(
      decoration: const BoxDecoration(gradient: siteHeroGradient),
      padding: EdgeInsets.fromLTRB(20, 36, 20, 40 + navClearance),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your Financial Growth Begins Here',
            style: TextStyle(
              fontSize: 28,
              height: 1.2,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            "Whether you're planning your future, expanding your business, or seeking reliable financial support, Sakaar Foundation is committed to helping you achieve your goals through responsible financial inclusion.",
            style: TextStyle(
              fontSize: 14,
              height: 1.55,
              color: Color(0xF2FFFFFF),
            ),
          ),
          const SizedBox(height: 22),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _GoldButton(label: primaryLabel, onPressed: onPrimary),
              _OutlineLightButton(
                label: 'Contact Us Today',
                onPressed: onContact,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
