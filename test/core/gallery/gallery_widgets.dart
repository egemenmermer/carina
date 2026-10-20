/// Component-gallery compositions rendered by gallery_screenshot_test.dart.
///
/// Test-only code.
library;

import 'package:flutter/material.dart';

import 'package:carina/core/core.dart';

// ------------------------------------------------------------------ sample data

class GalleryChannel {
  const GalleryChannel(
    this.name,
    this.badge,
    this.programme,
    this.time,
    this.progress, {
    this.archive = false,
    this.reminder = false,
    this.locked = false,
    this.recording = false,
  });

  final String name;
  final String badge;
  final String programme;
  final String time;
  final double progress;
  final bool archive;
  final bool reminder;
  final bool locked;
  final bool recording;
}

const galleryChannels = <GalleryChannel>[
  GalleryChannel(
    'TRT 1',
    'HD',
    'Akşam Haberleri',
    '7:20 PM – 7:45 PM',
    0.82,
    archive: true,
  ),
  GalleryChannel(
    'Show TV',
    'FHD',
    'Sıcak Kafa – S1 E2',
    '7:20 PM – 8:10 PM',
    0.34,
    reminder: true,
  ),
  GalleryChannel('Kanal D', 'SD', 'Kış Uykusu', '7:40 PM – 8:15 PM', 0.12),
  GalleryChannel(
    'Star TV',
    'HD',
    'Kitchen Stories – Episode 4',
    '7:40 PM – 8:15 PM',
    0.18,
    locked: true,
  ),
  GalleryChannel(
    'Haber Global',
    'FHD',
    'Evening Bulletin',
    '7:24 PM – 8:18 PM',
    0.41,
    archive: true,
  ),
  GalleryChannel(
    'Belgesel+',
    'SD',
    'Anatolia from Above',
    '7:24 PM – 8:18 PM',
    0.40,
  ),
  GalleryChannel(
    'Spor Arena',
    '4K',
    'Champions Night – Live',
    '7:15 PM – 9:10 PM',
    0.27,
    recording: true,
  ),
  GalleryChannel(
    'Çocuk Kanalı',
    'HD',
    'Cartoon Hour',
    '7:15 PM – 9:10 PM',
    0.27,
    locked: true,
  ),
  GalleryChannel(
    'Müzik TV',
    'SD',
    'EPG not available',
    '7:00 PM – 8:00 PM',
    0.0,
  ),
  GalleryChannel(
    'Yaşam TV',
    'SD',
    'EPG not available',
    '7:00 PM – 8:00 PM',
    0.0,
  ),
  GalleryChannel(
    'Motor TV',
    'FHD',
    'Garage Classics',
    '7:00 PM – 8:00 PM',
    0.55,
  ),
  GalleryChannel(
    'Motor TV',
    'HD',
    'Garage Classics',
    '7:00 PM – 8:00 PM',
    0.55,
  ),
];

const _artGradients = <List<Color>>[
  [Color(0xFF3B2B5E), Color(0xFF0F0B1F)],
  [Color(0xFF5E2B2B), Color(0xFF1F0B0B)],
  [Color(0xFF2B4A5E), Color(0xFF0B141F)],
  [Color(0xFF2B5E3E), Color(0xFF0B1F12)],
  [Color(0xFF5E4A2B), Color(0xFF1F160B)],
  [Color(0xFF4A2B5E), Color(0xFF170B1F)],
];

Widget galleryArt(int i, {String? label}) {
  final colors = _artGradients[i % _artGradients.length];
  return DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: colors,
      ),
    ),
    child: label == null
        ? const SizedBox.expand()
        : Center(
            child: Text(
              label,
              style: KText.heroTitle.copyWith(
                fontSize: 30,
                color: const Color(0x40FFFFFF),
              ),
            ),
          ),
  );
}

class GalleryLabel extends StatelessWidget {
  const GalleryLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(text.toUpperCase(), style: KText.sectionLabel),
  );
}

const galleryTabs = <KNavTab>[
  KNavTab(id: 'movies', label: 'Movies'),
  KNavTab(id: 'shows', label: 'Shows'),
  KNavTab(id: 'live', label: 'TV Live'),
  KNavTab(id: 'guide', label: 'TV Guide'),
  KNavTab.icon(
    id: 'search',
    icon: PhosphorIconsRegular.magnifyingGlass,
    label: 'Search',
  ),
  KNavTab(id: 'settings', label: 'Settings'),
];

KTopNav galleryNav(String active, {List<Widget> trailing = const []}) =>
    KTopNav(
      tabs: galleryTabs,
      activeTabId: active,
      onTabSelected: (_) {},
      dateTimeText: 'Wed, May 20 • 00:26',
      avatar: const KAvatar('animal-fox', 44),
      onAvatarTap: (_) {},
      onLogoTap: () {},
      trailing: trailing,
      showCaptionButtons: true,
    );

// ------------------------------------------------------------ 1. nav + controls

class GalleryNavControls extends StatelessWidget {
  const GalleryNavControls({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            galleryNav(
              'movies',
              trailing: const [
                KProgressChip(label: 'Updating 45%', progress: 0.45),
              ],
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(48, 20, 48, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const GalleryLabel('Pills · segmented'),
                    Row(
                      children: [
                        KPill(label: 'Movies', selected: true, onTap: () {}),
                        const SizedBox(width: 10),
                        KPill(label: 'Shows', onTap: () {}),
                        const SizedBox(width: 10),
                        KPill(
                          label: 'Recently added',
                          trailing: '128',
                          onTap: () {},
                        ),
                        const SizedBox(width: 10),
                        KPill(
                          label: 'Ulusal',
                          outlined: true,
                          large: true,
                          leading: const Text('🇹🇷'),
                          onTap: () {},
                        ),
                        const Spacer(),
                        KSegmented<String>(
                          value: 'live',
                          onChanged: (_) {},
                          segments: const [
                            KSegment(value: 'movies', label: 'Movies'),
                            KSegment(value: 'shows', label: 'Shows'),
                            KSegment(value: 'live', label: 'TV Live'),
                            KSegment(value: 'guide', label: 'TV Guide'),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 26),
                    const GalleryLabel('Buttons'),
                    Row(
                      children: [
                        KButton.ghostIconLabel(
                          label: 'Favorites',
                          icon: PhosphorIconsLight.star,
                          onPressed: () {},
                        ),
                        const SizedBox(width: 28),
                        KButton.primaryWhite(
                          label: 'Play',
                          icon: PhosphorIconsFill.play,
                          size: KButtonSize.large,
                          minWidth: 150,
                          onPressed: () {},
                        ),
                        const SizedBox(width: 28),
                        KButton.ghostIconLabel(
                          label: 'Info',
                          icon: PhosphorIconsLight.info,
                          onPressed: () {},
                        ),
                        const SizedBox(width: 40),
                        KButton.accent(
                          label: 'Add playlist',
                          icon: PhosphorIconsBold.plus,
                          onPressed: () {},
                        ),
                        const SizedBox(width: 12),
                        KButton.secondary(
                          label: 'From the beginning',
                          onPressed: () {},
                        ),
                        const SizedBox(width: 12),
                        KButton.destructive(label: 'Remove', onPressed: () {}),
                        const SizedBox(width: 12),
                        const KButton.secondary(label: 'Disabled'),
                        const SizedBox(width: 24),
                        KIconButton(
                          icon: PhosphorIconsLight.arrowsClockwise,
                          tooltip: 'Switch player',
                          onPressed: () {},
                        ),
                        const SizedBox(width: 10),
                        KIconButton(
                          icon: PhosphorIconsLight.speakerHigh,
                          tooltip: 'Audio',
                          onPressed: () {},
                        ),
                        const SizedBox(width: 10),
                        KIconButton(
                          icon: PhosphorIconsLight.subtitles,
                          tooltip: 'Subtitles',
                          selected: true,
                          onPressed: () {},
                        ),
                      ],
                    ),
                    const SizedBox(height: 26),
                    const GalleryLabel('Badges · chips · age tab'),
                    Row(
                      children: [
                        for (final b in [
                          'SD',
                          'HD',
                          'FHD',
                          '4K',
                          'H265',
                          '50FPS',
                        ])
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: KBadge(b),
                          ),
                        const SizedBox(width: 18),
                        const KNewBadge.movie(),
                        const SizedBox(width: 8),
                        const KNewBadge.show(),
                        const SizedBox(width: 8),
                        const KNewBadge.episodes(),
                        const SizedBox(width: 22),
                        const KLivePill(),
                        const SizedBox(width: 8),
                        const KLivePill(large: true),
                        const SizedBox(width: 16),
                        const KChip('1920x1080'),
                        const SizedBox(width: 6),
                        const KChip('25 fps'),
                        const Spacer(),
                        const KAgeTab('PG-13'),
                      ],
                    ),
                    const SizedBox(height: 26),
                    const GalleryLabel('Progress · spinner · link'),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(
                          width: 280,
                          child: Column(
                            children: [
                              KProgressBar(value: 0.3),
                              SizedBox(height: 14),
                              KProgressBar(value: 0.65, height: 6),
                              SizedBox(height: 14),
                              KProgressBar(value: 0.9, height: 3),
                            ],
                          ),
                        ),
                        const SizedBox(width: 56),
                        KSpinner(label: KStrings.of(context).buffering(43)),
                        const SizedBox(width: 56),
                        KLink(label: 'See All', onTap: () {}),
                      ],
                    ),
                    const SizedBox(height: 18),
                  ],
                ),
              ),
            ),
            KSectionHeader(title: 'Continue watching', onSeeAll: () {}),
            KHorizontalRow(
              itemCount: 8,
              itemWidth: 300,
              itemHeight: 169,
              itemBuilder: (context, i) => GalleryContinueCard(index: i),
            ),
            const SizedBox(height: 26),
          ],
        ),
        Positioned(right: 32, bottom: 32, child: KFab(onPressed: () {})),
      ],
    );
  }
}

class GalleryContinueCard extends StatelessWidget {
  const GalleryContinueCard({super.key, required this.index});

  final int index;

  static const _titles = [
    ('Sıcak Kafa', 'S1 E2 · Episode 2'),
    ('Kış Uykusu', '1h 49m left'),
    ('Mavi Gece', 'S2 E7 · Episode 7'),
    ('The Long Road', '32m left'),
    ('Kuzey Rüzgârı', 'S1 E5 · Episode 5'),
    ('Night Signal', '1h 2m left'),
    ('Deniz Feneri', 'S3 E1 · Episode 1'),
    ('Paper Kites', '54m left'),
  ];

  @override
  Widget build(BuildContext context) {
    final (title, subtitle) = _titles[index % _titles.length];
    return FocusableCard(
      onTap: () {},
      onContextMenu: (_) {},
      showStroke: false,
      child: Stack(
        fit: StackFit.expand,
        children: [
          galleryArt(index),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0.45, 1],
                colors: [Color(0x00000000), Color(0xCC000000)],
              ),
            ),
          ),
          Center(
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0x40000000),
                border: Border.all(color: Colors.white, width: 2.5),
              ),
              child: const Icon(
                PhosphorIconsFill.play,
                size: 20,
                color: Colors.white,
              ),
            ),
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 14,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: KText.cardTitle, maxLines: 1),
                Text(subtitle, style: KText.cardSubtitle, maxLines: 1),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: KProgressBar(
              value: 0.15 + (index * 0.13) % 0.8,
              rounded: false,
            ),
          ),
          if (index == 0)
            const Positioned(top: 10, right: 10, child: KNewBadge.show()),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------- 2. TV Live (horiz.)

class GalleryLive extends StatelessWidget {
  const GalleryLive({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        galleryNav('live'),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 400,
                  child: Column(
                    children: [
                      for (var i = 0; i < 5; i++) ...[
                        if (i > 0) const SizedBox(height: 10),
                        Expanded(
                          child: GalleryHorizontalChannelCard(
                            channel: galleryChannels[i],
                            selected: i == 2,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                const Expanded(child: _LiveRight()),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class GalleryHorizontalChannelCard extends StatelessWidget {
  const GalleryHorizontalChannelCard({
    super.key,
    required this.channel,
    this.selected = false,
  });

  final GalleryChannel channel;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return FocusableCard(
      selected: selected,
      ringWidth: KFocusRingWidth.tv,
      onTap: () {},
      onContextMenu: (_) {},
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: KLogoTile(name: channel.name, size: 72),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(2, 12, 12, 12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      KBadge(channel.badge),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          channel.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: KText.channelName.copyWith(fontSize: 20),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    channel.programme,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: KText.programme.copyWith(
                      color: KColors.textSecondary,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    channel.time,
                    style: KText.time.copyWith(
                      color: KColors.textPrimary,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 7),
                  KProgressBar(value: channel.progress, height: 5),
                ],
              ),
            ),
          ),
          Container(width: 1, color: KColors.stroke),
          SizedBox(
            width: 52,
            child: _StatusIcons(channel: channel, axis: Axis.vertical),
          ),
        ],
      ),
    );
  }
}

class _StatusIcons extends StatelessWidget {
  const _StatusIcons({required this.channel, required this.axis});

  final GalleryChannel channel;
  final Axis axis;

  @override
  Widget build(BuildContext context) {
    const dim = Color(0xFF3E434A);
    final icons = [
      Icon(
        PhosphorIconsLight.record,
        size: 20,
        color: channel.recording ? KColors.accent : dim,
      ),
      Icon(
        PhosphorIconsLight.clockCounterClockwise,
        size: 20,
        color: channel.archive ? KColors.textPrimary : dim,
      ),
      Icon(
        PhosphorIconsLight.bell,
        size: 20,
        color: channel.reminder ? KColors.accent : dim,
      ),
      Icon(
        PhosphorIconsLight.lockSimple,
        size: 20,
        color: channel.locked ? KColors.success : dim,
      ),
    ];
    return Flex(
      direction: axis,
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: icons,
    );
  }
}

class _LiveRight extends StatelessWidget {
  const _LiveRight();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 11,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(KRadii.video),
            child: Stack(
              fit: StackFit.expand,
              children: [
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF26402B), Color(0xFF0C140D)],
                    ),
                  ),
                ),
                const Positioned(
                  left: 16,
                  top: 16,
                  child: Row(
                    children: [
                      KLivePill(large: true),
                      SizedBox(width: 10),
                      KChip('HD', overlay: true, large: true),
                      SizedBox(width: 10),
                      KChip('25 FPS', overlay: true, large: true),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Expanded(
          flex: 10,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _NowOnAir()),
              SizedBox(width: 12),
              Expanded(child: _Upcoming()),
            ],
          ),
        ),
      ],
    );
  }
}

class _NowOnAir extends StatelessWidget {
  const _NowOnAir();

  @override
  Widget build(BuildContext context) {
    return KPanel(
      padding: const EdgeInsets.fromLTRB(18, 18, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PanelHeader('Now on Air'),
          const SizedBox(height: 10),
          Text(
            'Sıcak Kafa – S1 E2',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: KText.largeTitle.copyWith(fontSize: 24),
          ),
          const SizedBox(height: 6),
          const Expanded(
            child: Text(
              'A retired detective is pulled back into one last case when a '
              'quiet seaside town wakes up to an unexplained blackout. – EPG '
              'by guide.example',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: KText.family,
                fontSize: 13,
                height: 1.35,
                color: Color(0xFFB7B7B7),
              ),
            ),
          ),
          const Row(
            children: [
              Expanded(
                child: KInfoTile(
                  icon: PhosphorIconsLight.clock,
                  label: 'Time',
                  value: '3:15 PM – 4:15 PM',
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: KInfoTile(
                  icon: PhosphorIconsLight.hourglassMedium,
                  label: 'Duration',
                  value: '60 min',
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const PanelHeader('Channel functions', showBar: false),
          const SizedBox(height: 6),
          const Row(
            children: [
              Expanded(
                child: KInfoTile(
                  icon: PhosphorIconsLight.clockCounterClockwise,
                  label: 'TV Archive',
                  value: 'Not available',
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: KInfoTile(
                  icon: PhosphorIconsLight.lockSimple,
                  label: 'Parental',
                  value: 'Inactive',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Upcoming extends StatelessWidget {
  const _Upcoming();

  static const _rows = [
    ('4:15 PM', 'Sıcak Kafa – S1 E3', '60 min'),
    ('5:15 PM', 'Evening Bulletin', '60 min'),
    ('6:15 PM', 'Anatolia from Above', '45 min'),
    ('7:00 PM', 'Kitchen Stories', '30 min'),
  ];

  @override
  Widget build(BuildContext context) {
    return KPanel(
      padding: const EdgeInsets.fromLTRB(18, 18, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const PanelHeader('Upcoming'),
          const SizedBox(height: 12),
          for (final (time, title, duration) in _rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                height: 58,
                decoration: BoxDecoration(
                  color: KColors.tile,
                  borderRadius: BorderRadius.circular(KRadii.tile),
                  border: Border.all(color: KColors.stroke),
                ),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 40,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Icon(
                            PhosphorIconsLight.calendarPlus,
                            size: 16,
                            color: Color(0xFF4A4F55),
                          ),
                          Icon(
                            PhosphorIconsLight.bell,
                            size: 16,
                            color: Color(0xFF4A4F55),
                          ),
                        ],
                      ),
                    ),
                    Container(width: 1, color: KColors.stroke),
                    const SizedBox(width: 12),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'TODAY',
                          style: KText.badge.copyWith(
                            color: KColors.accent,
                            fontSize: 11,
                          ),
                        ),
                        Text(
                          time,
                          style: KText.timeLarge.copyWith(fontSize: 19),
                        ),
                      ],
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: KText.cardTitle,
                      ),
                    ),
                    Text(duration, style: KText.caption),
                    const SizedBox(width: 12),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// --------------------------------------------- 3. TV Live grid + context menu

class GalleryLiveGrid extends StatelessWidget {
  const GalleryLiveGrid({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        galleryNav('live'),
        Expanded(
          child: Stack(
            children: [
              GridView.builder(
                padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  mainAxisExtent: 168,
                ),
                itemCount: galleryChannels.length,
                itemBuilder: (context, i) =>
                    GalleryGridChannelCard(channel: galleryChannels[i]),
              ),
              Positioned(
                top: 2,
                left: 0,
                right: 0,
                child: Center(
                  child: KPill(
                    label: 'Ulusal',
                    outlined: true,
                    large: true,
                    leading: const Text('🇹🇷'),
                    onTap: () {},
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class GalleryGridChannelCard extends StatelessWidget {
  const GalleryGridChannelCard({super.key, required this.channel});

  final GalleryChannel channel;

  static const _menuEntries = <KMenuEntry<String>>[
    KMenuEntry(
      label: 'Add to favorite with tags',
      icon: PhosphorIconsLight.tag,
      value: 'tags',
    ),
    KMenuEntry(
      label: 'Add to favorites',
      icon: PhosphorIconsLight.star,
      value: 'fav',
    ),
    KMenuEntry(
      label: 'Assign Custom EPG',
      icon: PhosphorIconsLight.article,
      value: 'epg',
    ),
    KMenuEntry(
      label: 'Start recording now',
      icon: PhosphorIconsLight.record,
      value: 'rec',
      enabled: false,
    ),
    KMenuEntry(
      label: 'Schedule Reminder',
      icon: PhosphorIconsLight.bellSimpleRinging,
      value: 'remind',
    ),
    KMenuEntry(
      label: 'Add to Parental Control',
      icon: PhosphorIconsLight.lockSimple,
      value: 'lock',
    ),
    KMenuEntry(
      label: 'Add category to Parental Control',
      icon: PhosphorIconsLight.lockSimple,
      value: 'lockcat',
    ),
    KMenuEntry(
      label: 'Hide channel',
      icon: PhosphorIconsLight.eyeSlash,
      value: 'hide',
    ),
    KMenuEntry(
      label: 'Hide category',
      icon: PhosphorIconsLight.eyeSlash,
      value: 'hidecat',
    ),
    KMenuEntry(
      label: "Change category's name",
      icon: PhosphorIconsLight.textAa,
      value: 'rename',
    ),
    KMenuEntry.separator(),
    KMenuEntry(
      label: 'Dump Channel',
      icon: PhosphorIconsLight.fileMagnifyingGlass,
      value: 'dump',
    ),
    KMenuEntry(
      label: 'Remove from Last watched',
      icon: PhosphorIconsLight.trash,
      value: 'remove',
      destructive: true,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    const dim = Color(0xFF3E434A);
    return FocusableCard(
      onTap: () {},
      onContextMenu: (pos) => showKContextMenu<String>(
        context,
        position: pos,
        entries: _menuEntries,
      ),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              KLogoTile(name: channel.name, size: 48),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      channel.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: KText.channelName.copyWith(fontSize: 16),
                    ),
                    const SizedBox(height: 4),
                    KBadge(channel.badge),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(channel.time, style: KText.time),
          const SizedBox(height: 2),
          Text(
            channel.programme,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: KText.programme,
          ),
          const SizedBox(height: 7),
          KProgressBar(value: channel.progress, height: 3),
          const Spacer(),
          Container(height: 1, color: KColors.stroke),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final (icon, on, color) in [
                (PhosphorIconsLight.record, channel.recording, KColors.accent),
                (
                  PhosphorIconsLight.clockCounterClockwise,
                  channel.archive,
                  KColors.textPrimary,
                ),
                (PhosphorIconsLight.bell, channel.reminder, KColors.accent),
                (
                  PhosphorIconsLight.lockSimple,
                  channel.locked,
                  KColors.success,
                ),
              ])
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Icon(icon, size: 18, color: on ? color : dim),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ------------------------------------- 4. settings, wizard form, playlist manager

class GallerySettings extends StatelessWidget {
  const GallerySettings({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        galleryNav('settings'),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 380,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(32, 28, 24, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final (label, icon) in const [
                        ('General', PhosphorIconsFill.gearSix),
                        ('Playlist Management', PhosphorIconsFill.listBullets),
                        ('Player', PhosphorIconsFill.play),
                        ('TV Live & TV Guide', PhosphorIconsFill.television),
                        ('Parental Control', PhosphorIconsFill.lockSimple),
                        ('Reminders', PhosphorIconsFill.bellSimple),
                        ('Cache & Diagnostics', PhosphorIconsFill.database),
                        ('About', PhosphorIconsFill.info),
                      ])
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: SettingsSectionTile(
                            label: label,
                            icon: icon,
                            selected: label == 'Player',
                            onTap: () {},
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 30, 48, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Player',
                        textAlign: TextAlign.center,
                        style: KText.title,
                      ),
                      const SettingsSectionHeader('Engine'),
                      SettingsGroup(
                        children: [
                          SettingsRow(
                            title: "VOD player's type",
                            value: 'MPV · Hardware',
                            onTap: () {},
                          ),
                          SettingsRow(
                            title: "Live player's type",
                            value: 'MPV · Low latency',
                            onTap: () {},
                          ),
                          SettingsRow(
                            title: "TV Archive player's type",
                            value: 'Auto',
                            onTap: () {},
                          ),
                          SettingsRow(
                            title: 'Subtitle size',
                            value: 'Medium',
                            onTap: () {},
                          ),
                          SettingsRow(
                            title: 'Aspect ratio',
                            value: 'Auto',
                            onTap: () {},
                          ),
                          SettingsRow(
                            key: const Key('resolution-row'),
                            title: 'Resolution indicator',
                            value: 'Label (ex. "HD")',
                            onTap: () {},
                          ),
                          SettingsSwitchRow(
                            title: 'Hardware acceleration',
                            value: true,
                            onChanged: (_) {},
                          ),
                          SettingsSwitchRow(
                            title: 'AutoPlay when closing progress bar',
                            subtitle: 'Resume playback when the bar hides',
                            value: false,
                            onChanged: (_) {},
                          ),
                        ],
                      ),
                      const SettingsSectionHeader('Danger zone'),
                      SettingsRow(
                        title: 'Clear EPG database',
                        icon: PhosphorIconsLight.trash,
                        destructive: true,
                        showChevron: false,
                        onTap: () {},
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class GalleryForms extends StatelessWidget {
  const GalleryForms({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        galleryNav('settings'),
        const Expanded(
          child: Padding(
            padding: EdgeInsets.fromLTRB(120, 20, 200, 0),
            child: _WizardForm(),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 0, 48, 28),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: Container(height: 2, color: KColors.accent)),
              const SizedBox(width: 16),
              const CarinaMark(size: 34),
            ],
          ),
        ),
      ],
    );
  }
}

class GalleryPlaylistManager extends StatelessWidget {
  const GalleryPlaylistManager({super.key});

  static const playlists = [
    ('Home IPTV', 'animal-fox'),
    ('Spor Paketi', 'obj-football'),
    ('Kids', 'char-robot'),
    ('Ev TV', null),
  ];

  static const menuEntries = <KMenuEntry<String>>[
    KMenuEntry(
      label: 'Choose Avatar',
      icon: PhosphorIconsLight.userCircle,
      value: 'avatar',
    ),
    KMenuEntry(
      label: 'Playlist details',
      icon: PhosphorIconsLight.info,
      value: 'details',
    ),
    KMenuEntry(
      label: 'Force reload',
      icon: PhosphorIconsLight.arrowClockwise,
      value: 'reload',
    ),
    KMenuEntry(
      label: 'Set Playlist Access PIN',
      icon: PhosphorIconsLight.lockSimple,
      value: 'pin',
    ),
    KMenuEntry(
      label: 'Force reload EPG',
      icon: PhosphorIconsLight.calendarDots,
      value: 'epg',
    ),
    KMenuEntry(
      label: 'Edit',
      icon: PhosphorIconsLight.pencilSimple,
      value: 'edit',
    ),
    KMenuEntry(
      label: "Open playlist's settings",
      icon: PhosphorIconsLight.gearSix,
      value: 'settings',
    ),
    KMenuEntry(
      label: 'Remove',
      icon: PhosphorIconsLight.trash,
      value: 'remove',
      destructive: true,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 72,
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            children: [
              const CarinaMark(size: 44),
              const SizedBox(height: 36),
              for (final (icon, tip) in const [
                (PhosphorIconsLight.plus, 'Add playlist'),
                (PhosphorIconsLight.downloadSimple, 'Downloads'),
                (PhosphorIconsLight.gearSix, 'Settings'),
                (PhosphorIconsLight.info, 'About'),
              ])
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: KIconButton(
                    icon: icon,
                    tooltip: tip,
                    size: 40,
                    iconSize: 22,
                    background: const Color(0x00000000),
                    onPressed: () {},
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: Center(
            child: Wrap(
              spacing: 48,
              runSpacing: 32,
              children: [
                for (final (name, avatar) in playlists)
                  Builder(
                    builder: (context) => SizedBox(
                      width: 170,
                      child: Column(
                        children: [
                          KFocusable(
                            key: ValueKey('playlist-$name'),
                            borderRadius: 70,
                            onTap: () {},
                            onContextMenu: (pos) => showKContextMenu<String>(
                              context,
                              position: pos,
                              title: name,
                              entries: menuEntries,
                              iconPosition: KMenuIconPosition.leading,
                              separators: false,
                              width: 280,
                            ),
                            child: KAvatar(avatar, 140, fallbackName: name),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            name,
                            textAlign: TextAlign.center,
                            style: KText.cardTitle,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _WizardForm extends StatelessWidget {
  const _WizardForm();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 28),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 220,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '04 / Server address',
                    style: KText.title.copyWith(fontSize: 22),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Include the scheme and port',
                    style: KText.bodySecondary,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  KTextField(
                    label: 'Name',
                    controller: TextEditingController(text: 'Home IPTV'),
                  ),
                  const SizedBox(height: 14),
                  const KTextField(
                    label: 'Server',
                    hint: 'https://domain.com:port',
                    autofocus: true,
                    status: KFieldStatus.ok(
                      'Server reachable · account active · expires 2027-03-01 · 1 connection',
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: KTextField(
                          label: 'Username',
                          controller: TextEditingController(text: 'kanal'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: KTextField(
                          label: 'Password',
                          obscure: true,
                          controller: TextEditingController(text: 'test123'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  KTextField(
                    label: 'EPG URL',
                    controller: TextEditingController(
                      text: 'http://dom***:8080/xmltv.php',
                    ),
                    status: const KFieldStatus.checking(),
                  ),
                  const SizedBox(height: 14),
                  KTextField(
                    label: 'Playlist URL',
                    controller: TextEditingController(
                      text: 'http://example.invalid/list.m3u',
                    ),
                    errorText: 'Unreachable: the connection timed out',
                  ),
                  const SizedBox(height: 22),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      KButton.secondary(label: 'Cancel', onPressed: () {}),
                      const SizedBox(width: 12),
                      KButton.accent(
                        label: 'Save',
                        onPressed: () {},
                        minWidth: 120,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ------------------------------------------------------------- 5. player popover

class GalleryPlayer extends StatelessWidget {
  const GalleryPlayer({super.key, required this.audioButtonKey});

  final GlobalKey audioButtonKey;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF2A3540), Color(0xFF0B0E12)],
            ),
          ),
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: [0.5, 1],
              colors: [Color(0x00000000), Color(0xE6000000)],
            ),
          ),
        ),
        const Positioned(
          left: 48,
          top: 40,
          child: Row(
            children: [
              KLivePill(large: true),
              SizedBox(width: 10),
              KChip('1920x1080', overlay: true, large: true),
              SizedBox(width: 10),
              KChip('25 fps', overlay: true, large: true),
            ],
          ),
        ),
        const Center(child: KSpinner(size: 48, label: 'Buffering 43%')),
        Positioned(
          left: 48,
          right: 48,
          bottom: 40,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Kış Uykusu',
                      style: KText.largeTitle.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  for (final (icon, tip) in [
                    (PhosphorIconsLight.arrowsClockwise, 'Switch player'),
                    (PhosphorIconsLight.speakerHigh, 'Audio'),
                    (PhosphorIconsLight.subtitles, 'Subtitles'),
                    (PhosphorIconsLight.frameCorners, 'Picture'),
                    (PhosphorIconsLight.gauge, 'Speed'),
                    (PhosphorIconsLight.dotsThree, 'More'),
                  ])
                    Padding(
                      padding: const EdgeInsets.only(left: 12),
                      child: KIconButton(
                        key: tip == 'Audio' ? audioButtonKey : null,
                        icon: icon,
                        tooltip: tip,
                        onPressed: () {},
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              const KProgressBar(value: 0.08, height: 5),
              const SizedBox(height: 8),
              const Row(
                children: [
                  Text('0:13', style: KText.time),
                  Spacer(),
                  Text('-2:46', style: KText.time),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

List<KPopoverSection> galleryAudioSections(double delay) => [
  KPopoverSection(
    header: 'Audio',
    items: [
      KPopoverItem.check(
        label: 'English',
        detail: 'AC3 5.1',
        checked: true,
        onTap: () {},
      ),
      KPopoverItem.check(
        label: 'Türkçe',
        detail: 'AAC stereo',
        checked: false,
        onTap: () {},
      ),
      KPopoverItem.stepper(
        label: 'Audio delay',
        valueText:
            '${delay >= 0 ? '+' : '−'}${delay.abs().toStringAsFixed(1)} s',
        onDecrement: () {},
        onIncrement: () {},
      ),
    ],
  ),
  KPopoverSection(
    header: 'External subtitles',
    items: [
      KPopoverItem.action(
        label: 'Load from file…',
        icon: PhosphorIconsLight.folderSimpleDashed,
        onTap: () {},
      ),
    ],
  ),
];

// ------------------------------------------------------------ 6. archive sheet

class GalleryArchiveSheet extends StatelessWidget {
  const GalleryArchiveSheet({super.key});

  static const _rows = [
    (
      '11:30 PM – ON AIR',
      'Gece Haberleri – Son dakika',
      'The day’s headlines with analysis from the studio and reports from',
    ),
    (
      '10:30 PM',
      'Bilgi Yarışması – 20/07/2026',
      'Twelve contestants compete in a fast general-knowledge quiz show',
    ),
    (
      '10:00 PM',
      'Akşam Bülteni',
      'It wasn’t possible to find any overview about this programme',
    ),
    (
      '8:40 PM',
      'Zincirleme – 20/07/2026',
      'A word-association game where every answer unlocks the next round',
    ),
    (
      '6:10 PM',
      'Canlı Yayın – Hafta İçi',
      'Daily magazine with guests, music and the latest from the city',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 28, 28, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'TV ARCHIVE • CATCH-UP',
            textAlign: TextAlign.center,
            style: KText.title.copyWith(letterSpacing: 0.2),
          ),
          const SizedBox(height: 26),
          Text(
            'Monday, 20 July',
            style: KText.sectionTitle.copyWith(color: KColors.accent),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            decoration: BoxDecoration(
              color: const Color(0xFF0F0F0F),
              borderRadius: BorderRadius.circular(KRadii.panel),
            ),
            child: Column(
              children: [
                for (var i = 0; i < _rows.length; i++)
                  _ArchiveRow(
                    time: _rows[i].$1,
                    title: _rows[i].$2,
                    description: _rows[i].$3,
                    last: i == _rows.length - 1,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ArchiveRow extends StatelessWidget {
  const _ArchiveRow({
    required this.time,
    required this.title,
    required this.description,
    required this.last,
  });

  final String time;
  final String title;
  final String description;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return KInteractive(
      onTap: () {},
      builder: (context, state, _) => Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: state.highlighted ? KColors.rowHover : null,
          border: last
              ? null
              : const Border(bottom: BorderSide(color: Color(0xFF2C2C2C))),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    time,
                    style: KText.time.copyWith(
                      color: KColors.accent,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: KText.channelName,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: KText.bodySecondary.copyWith(fontSize: 14),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            const Icon(
              PhosphorIconsLight.arrowCircleDown,
              size: 28,
              color: KColors.textPrimary,
            ),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ 7. avatars

class GalleryAvatarPicker extends StatelessWidget {
  const GalleryAvatarPicker({super.key});

  @override
  Widget build(BuildContext context) {
    final avatars = AvatarCatalog.byCategory(AvatarCategory.animals);
    return Column(
      children: [
        const SizedBox(height: 28),
        Text('Choose Avatar', style: KText.title.copyWith(fontSize: 24)),
        const SizedBox(height: 28),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(width: 40),
              SizedBox(
                width: 260,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final c in AvatarCategory.values)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: KPill(
                            label: c.label(context),
                            selected: c == AvatarCategory.animals,
                            trailing: '${AvatarCatalog.byCategory(c).length}',
                            onTap: () {},
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 40),
              Expanded(
                child: Wrap(
                  spacing: 36,
                  runSpacing: 30,
                  children: [
                    for (final a in avatars)
                      KFocusable(
                        borderRadius: 70,
                        onTap: () {},
                        child: KAvatar(a.id, 132),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 40),
            ],
          ),
        ),
      ],
    );
  }
}

class GalleryAvatarsAll extends StatelessWidget {
  const GalleryAvatarsAll({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(40, 28, 40, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final column in const [
                [
                  AvatarCategory.characters,
                  AvatarCategory.animals,
                  AvatarCategory.cars,
                ],
                [
                  AvatarCategory.objects,
                  AvatarCategory.abstract,
                  AvatarCategory.initials,
                ],
              ])
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final c in column) ...[
                        GalleryLabel(
                          '${c.label(context)} · '
                          '${AvatarCatalog.byCategory(c).length}',
                        ),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            for (final a in AvatarCatalog.byCategory(c))
                              KAvatar(
                                a.id,
                                56,
                                fallbackName: c == AvatarCategory.initials
                                    ? 'Ev TV'
                                    : null,
                              ),
                          ],
                        ),
                        const SizedBox(height: 14),
                      ],
                    ],
                  ),
                ),
            ],
          ),
          const GalleryLabel('Logo tiles (monogram fallback)'),
          Row(
            children: [
              for (final n in [
                'TRT 1 HD',
                'Show TV FHD',
                'Kanal D SD',
                'TR: Haber Canlı',
                'UHD Test 4K',
                'Çocuk Kilitli',
                'NTV',
                '|TR| Spor Arena',
              ])
                Padding(
                  padding: const EdgeInsets.only(right: 14),
                  child: KLogoTile(name: n),
                ),
              const SizedBox(width: 20),
              const KAvatar(null, 64, fallbackName: 'Kanal Test'),
              const SizedBox(width: 14),
              const KAvatar('unknown-id', 64),
            ],
          ),
          const SizedBox(height: 18),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: KPanel(
                    padding: EdgeInsets.zero,
                    child: KEmptyState(
                      message: 'Add your first playlist',
                      actionLabel: 'Add playlist',
                      actionIcon: PhosphorIconsBold.plus,
                      onAction: () {},
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: KPanel(
                    padding: EdgeInsets.zero,
                    child: KErrorState(
                      message: 'The server did not answer in 15 seconds.',
                      details: 'http://dom***:8080 · timeout',
                      onRetry: () {},
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: KPanel(
                    padding: EdgeInsets.zero,
                    child: KLoadingState(message: 'Loading…'),
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
