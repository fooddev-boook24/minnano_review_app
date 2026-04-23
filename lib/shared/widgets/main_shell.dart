import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';

// ブレークポイント定数
const double _kTablet = 600;
const double _kDesktop = 1200;
const double _kCenterWidth = 630;
const double _kBottomNavHeight = 75;

class MainShell extends StatelessWidget {
  const MainShell({super.key, required this.child});

  final Widget child;

  static const _tabs = [
    _TabItem(path: '/home',     icon: Icons.home_outlined,    activeIcon: Icons.home,    label: 'ホーム'),
    _TabItem(path: '/explore',  icon: Icons.explore_outlined, activeIcon: Icons.explore, label: '探索'),
    _TabItem(path: '/search',   icon: Icons.search,           activeIcon: Icons.search,  label: '検索'),
    _TabItem(path: '/settings', icon: Icons.settings_outlined,activeIcon: Icons.settings,label: '設定'),
  ];

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    for (var i = 0; i < _tabs.length; i++) {
      if (location.startsWith(_tabs[i].path)) return i;
    }
    return 0;
  }

  static bool isDetailRoute(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    return location.startsWith('/app/');
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = width < _kTablet;
    final currentIndex = _currentIndex(context);
    final isDetail = isDetailRoute(context);

    if (isMobile) {
      if (isDetail) {
        // アプリ詳細はモバイルでフルスクリーン（底部ナビ非表示）
        return Scaffold(backgroundColor: AppColors.white, body: child);
      }
      return _MobileLayout(
        tabs: _tabs,
        currentIndex: currentIndex,
        child: child,
      );
    }

    if (width < _kDesktop) {
      return _WebLayout(
        tabs: _tabs,
        currentIndex: currentIndex,
        showLeftAd: false,
        child: child,
      );
    }

    return _WebLayout(
      tabs: _tabs,
      currentIndex: currentIndex,
      showLeftAd: true,
      child: child,
    );
  }
}

// ─── モバイルレイアウト ────────────────────────────────────────────

class _MobileLayout extends StatelessWidget {
  const _MobileLayout({
    required this.tabs,
    required this.currentIndex,
    required this.child,
  });

  final Widget child;
  final List<_TabItem> tabs;
  final int currentIndex;

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: AppColors.white,
      // SnackBar を BottomNav の上に表示
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      body: Stack(
        children: [
          // コンテンツ（BottomNav 分だけ bottom に余白、StatusBar 分を top に確保）
          Positioned.fill(
            bottom: _kBottomNavHeight + bottomPadding,
            child: SafeArea(bottom: false, child: child),
          ),
          // BottomNav（bottom: 0 固定）
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _BottomNav(
              tabs: tabs,
              currentIndex: currentIndex,
              bottomPadding: bottomPadding,
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({
    required this.tabs,
    required this.currentIndex,
    required this.bottomPadding,
  });

  final List<_TabItem> tabs;
  final int currentIndex;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border(top: BorderSide(color: AppColors.ink12, width: 0.5)),
      ),
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: Row(
        children: tabs.asMap().entries.map((e) {
          final i = e.key;
          final tab = e.value;
          final active = i == currentIndex;
          return Expanded(
            child: GestureDetector(
              onTap: () => context.go(tab.path),
              behavior: HitTestBehavior.opaque,
              child: SizedBox(
                height: _kBottomNavHeight,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      active ? tab.activeIcon : tab.icon,
                      color: active ? AppColors.orange : AppColors.ink30,
                      size: 24,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      tab.label,
                      style: AppTextStyles.caption.copyWith(
                        color: active ? AppColors.orange : AppColors.ink30,
                        fontSize: 10,
                        fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─── Web レイアウト ───────────────────────────────────────────────

class _WebLayout extends StatelessWidget {
  const _WebLayout({
    required this.tabs,
    required this.currentIndex,
    required this.showLeftAd,
    required this.child,
  });

  final Widget child;
  final List<_TabItem> tabs;
  final int currentIndex;
  final bool showLeftAd;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 左広告エリア（≥1200px のみ）
          if (showLeftAd)
            Expanded(
              child: Container(
                color: AppColors.bg,
                alignment: Alignment.topCenter,
                padding: const EdgeInsets.only(top: 80),
                child: const _AdBanner(width: 120, height: 600),
              ),
            ),

          // センターカラム（固定幅 630px）
          Container(
            width: _kCenterWidth,
            color: AppColors.white,
            child: child,
          ),

          // 右サイドバー（≥600px で常時表示）
          Expanded(
            child: _RightSidebar(
              tabs: tabs,
              currentIndex: currentIndex,
            ),
          ),
        ],
      ),
    );
  }
}

class _RightSidebar extends StatelessWidget {
  const _RightSidebar({
    required this.tabs,
    required this.currentIndex,
  });

  final List<_TabItem> tabs;
  final int currentIndex;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.bg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // サービス名
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 48, 20, 20),
            child: Row(
              children: [
                Image.asset('asstes/favicon_review.png', width: 36, height: 36),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'APP DEVELOPER REVIEW',
                      style: AppTextStyles.sectionLabel.copyWith(fontSize: 8),
                    ),
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: 'みんなの',
                            style: AppTextStyles.screenTitle.copyWith(
                              fontSize: 16,
                              color: AppColors.ink,
                            ),
                          ),
                          WidgetSpan(
                            child: ShaderMask(
                              shaderCallback: (bounds) =>
                                  AppColors.primaryGradient.createShader(bounds),
                              blendMode: BlendMode.srcIn,
                              child: Text(
                                'レビュー',
                                style: AppTextStyles.screenTitle.copyWith(
                                  fontSize: 16,
                                  color: AppColors.ink,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ナビゲーション項目
          ...tabs.map((tab) {
            final active = tab.path == _activePathFrom(context);
            return _SidebarNavItem(
              tab: tab,
              active: active,
              onTap: () => context.go(tab.path),
            );
          }),

          const Spacer(),

          // 下部広告枠（100px）
          Container(
            height: 100,
            margin: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.ink06,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Text('広告', style: AppTextStyles.sectionLabel),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  String _activePathFrom(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    for (final tab in tabs) {
      if (location.startsWith(tab.path)) return tab.path;
    }
    return '/home';
  }
}

class _SidebarNavItem extends StatelessWidget {
  const _SidebarNavItem({
    required this.tab,
    required this.active,
    required this.onTap,
  });

  final _TabItem tab;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: active ? AppColors.orangeBg : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              active ? tab.activeIcon : tab.icon,
              color: active ? AppColors.orange : AppColors.ink55,
              size: 20,
            ),
            const SizedBox(width: 10),
            Text(
              tab.label,
              style: AppTextStyles.body.copyWith(
                color: active ? AppColors.orange : AppColors.ink55,
                fontWeight: active ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdBanner extends StatelessWidget {
  const _AdBanner({required this.width, required this.height});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width.toDouble(),
      height: height.toDouble(),
      decoration: BoxDecoration(
        color: AppColors.ink06,
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.center,
      child: Text('広告', style: AppTextStyles.sectionLabel),
    );
  }
}

// ─── タブ定義 ─────────────────────────────────────────────────────

class _TabItem {
  const _TabItem({
    required this.path,
    required this.icon,
    required this.activeIcon,
    required this.label,
  });

  final String path;
  final IconData icon;
  final IconData activeIcon;
  final String label;
}
