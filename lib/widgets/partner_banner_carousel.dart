import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_images.dart';
import '../theme/app_theme.dart';

class _Slide {
  final String image;
  final String tag;
  final String title;
  final String body;
  final IconData icon;
  // Photos with detail on the left need a stronger dark fade behind text.
  final bool darkPhoto;
  const _Slide({
    required this.image,
    required this.tag,
    required this.title,
    required this.body,
    required this.icon,
    this.darkPhoto = true,
  });
}

// Banner strip on the technician's Home: short, practical reminders for doing
// a job well, on CityCalls' own photos. Auto-advances every few seconds and
// can be swiped.
class PartnerBannerCarousel extends StatefulWidget {
  const PartnerBannerCarousel({super.key});

  @override
  State<PartnerBannerCarousel> createState() => _PartnerBannerCarouselState();
}

class _PartnerBannerCarouselState extends State<PartnerBannerCarousel> {
  static const _slides = [
    _Slide(
      image: AppImages.fieldService,
      tag: 'ON THE WAY',
      title: 'Keep location on while travelling',
      body: 'Customers see you arriving live on their map.',
      icon: Icons.near_me_rounded,
    ),
    _Slide(
      image: AppImages.partnerMascot,
      tag: '5-STAR SERVICE',
      title: 'Greet, explain, clean up',
      body: 'Tell the customer what you fixed before you leave.',
      icon: Icons.star_rounded,
      darkPhoto: false,
    ),
    _Slide(
      image: AppImages.appliancesDark,
      tag: 'CLOSE THE JOB',
      title: 'Finish with the customer OTP',
      body: 'Verified completions protect you and your payment.',
      icon: Icons.verified_user_rounded,
    ),
  ];

  final _controller = PageController();
  Timer? _timer;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || !_controller.hasClients) return;
      final next = (_page + 1) % _slides.length;
      _controller.animateToPage(next,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOutCubic);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Grows with the phone's font-size setting so the text never clips.
    final textScale =
        (MediaQuery.textScalerOf(context).scale(16) / 16).clamp(1.0, 2.0);
    return Column(
      children: [
        SizedBox(
          height: 156 + (textScale - 1) * 130,
          child: PageView.builder(
            controller: _controller,
            itemCount: _slides.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (context, i) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _BannerCard(slide: _slides[i]),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < _slides.length; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: i == _page ? 20 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: i == _page ? AppColors.green : AppColors.slate300,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _BannerCard extends StatelessWidget {
  final _Slide slide;
  const _BannerCard({required this.slide});

  @override
  Widget build(BuildContext context) {
    final light = !slide.darkPhoto;
    final titleColor = light ? AppColors.ink : Colors.white;
    final bodyColor =
        light ? AppColors.slate600 : Colors.white.withValues(alpha: 0.78);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        boxShadow: AppShadows.raised,
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(slide.image,
              fit: BoxFit.cover, alignment: Alignment.centerRight),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                stops: const [0, 0.55, 1],
                colors: light
                    ? [
                        const Color(0xFFEFF7E6),
                        const Color(0xFFEFF7E6).withValues(alpha: 0.75),
                        const Color(0xFFEFF7E6).withValues(alpha: 0),
                      ]
                    : [
                        AppColors.heroDark.withValues(alpha: 0.94),
                        AppColors.heroDark.withValues(alpha: 0.72),
                        AppColors.heroDark.withValues(alpha: 0.05),
                      ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 110, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: light
                        ? AppColors.green.withValues(alpha: 0.12)
                        : AppColors.lime400.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(slide.icon,
                          size: 12,
                          color: light ? AppColors.green : AppColors.lime400),
                      const SizedBox(width: 4),
                      Text(slide.tag,
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                              color:
                                  light ? AppColors.greenDark : AppColors.lime400)),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Text(slide.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 17,
                        height: 1.2,
                        letterSpacing: -0.3,
                        fontWeight: FontWeight.w800,
                        color: titleColor)),
                const SizedBox(height: 5),
                Text(slide.body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 12.5,
                        height: 1.35,
                        fontWeight: FontWeight.w500,
                        color: bodyColor)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
