import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_genres.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/services/analytics_service.dart';
import '../../core/services/functions_service.dart';
import '../../core/services/rewarded_ad_service.dart';
import '../../features/app_detail/app_detail_provider.dart';
import '../../shared/models/app_model.dart';
import '../../shared/widgets/app_snack_bar.dart';
import 'services/share_unlock_service.dart';

// ─── Providers ────────────────────────────────────────────

final _unlockServiceProvider = Provider((_) => ShareUnlockService());

// ─── Screen ───────────────────────────────────────────────

class ShareCardScreen extends ConsumerStatefulWidget {
  const ShareCardScreen({super.key, required this.trackId});
  final String trackId;

  @override
  ConsumerState<ShareCardScreen> createState() => _ShareCardScreenState();
}

class _ShareCardScreenState extends ConsumerState<ShareCardScreen> {
  static const _templates = [
    _Template(id: 'A', label: 'スタンダード'),
    _Template(id: 'B', label: 'オレンジ'),
    _Template(id: 'C', label: 'ダーク'),
  ];

  static const _suggestions = [
    'レビューお願いします！',
    '使ってみてね✨',
    '新作リリースしました！',
    'ぜひ試してみて🙏',
  ];

  String _selectedTemplateId = 'A';
  final _messageController = TextEditingController(text: 'レビューお願いします！');
  bool _isSharing = false;
  bool _isUnlocking = false;

  // ロック解除状態（起動時に非同期読み込み、アンロック後に更新）
  bool _unlocked = false;

  @override
  void initState() {
    super.initState();
    _loadUnlockState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(analyticsServiceProvider)
          .logShareCardOpened(widget.trackId);
    });
  }

  Future<void> _loadUnlockState() async {
    final unlocked =
        await ref.read(_unlockServiceProvider).isUnlocked();
    if (mounted) setState(() => _unlocked = unlocked);
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _watchAd(AppModel app) async {
    if (_isUnlocking) return;
    setState(() => _isUnlocking = true);

    ref.read(analyticsServiceProvider).logShareCardAdStarted(widget.trackId);

    final rewarded = await ref.read(rewardedAdServiceProvider).show();
    if (!mounted) return;

    if (rewarded) {
      await ref.read(_unlockServiceProvider).unlock();
      ref
          .read(analyticsServiceProvider)
          .logShareCardAdCompleted(widget.trackId);
      setState(() {
        _unlocked = true;
        _isUnlocking = false;
      });
    } else {
      ref
          .read(analyticsServiceProvider)
          .logShareCardAdFailed(widget.trackId);
      setState(() => _isUnlocking = false);
      if (mounted) showAppSnackBar(context, '広告の視聴が完了しませんでした');
    }
  }

  Future<void> _share(AppModel app, {bool useDefault = false}) async {
    if (_isSharing) return;
    setState(() => _isSharing = true);

    final template = useDefault ? 'A' : _selectedTemplateId;
    final message = useDefault
        ? 'App Storeで公開中'
        : _messageController.text.trim();

    try {
      // Generate OGP via Cloud Function
      final deviceId = kIsWeb ? 'web' : defaultTargetPlatform.name;

      final url = await ref.read(functionsServiceProvider).generateShareOgp(
            trackId: int.parse(widget.trackId),
            template: template,
            message: message,
            deviceId: deviceId,
          );

      if (!mounted) return;

      await Share.share(
        '${app.trackName}\n$message\n$url',
        subject: app.trackName,
      );

      if (useDefault) {
        ref
            .read(analyticsServiceProvider)
            .logShareCardDefaultShared(widget.trackId);
      } else {
        ref
            .read(analyticsServiceProvider)
            .logShareCardShared(widget.trackId, template, _unlocked);
      }
    } catch (_) {
      // Fallback: share app store URL without OGP image
      if (!mounted) return;
      await Share.share(
        '${app.trackName}\n$message\n${app.trackViewUrl}',
        subject: app.trackName,
      );
      if (useDefault) {
        ref
            .read(analyticsServiceProvider)
            .logShareCardDefaultShared(widget.trackId);
      } else {
        ref
            .read(analyticsServiceProvider)
            .logShareCardShared(widget.trackId, template, _unlocked);
      }
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appAsync = ref.watch(appDetailProvider(widget.trackId));

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              size: 18, color: AppColors.ink),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ShaderMask(
              shaderCallback: (bounds) =>
                  AppColors.primaryGradient.createShader(bounds),
              blendMode: BlendMode.srcIn,
              child: Text('みんなのレビュー',
                  style: AppTextStyles.caption.copyWith(fontSize: 10)),
            ),
            Text('シェアカードを作る', style: AppTextStyles.sectionHeading),
          ],
        ),
        titleSpacing: 0,
      ),
      body: appAsync.when(
        data: (app) {
          if (app == null) {
            return Center(
                child: Text('アプリが見つかりません',
                    style: AppTextStyles.bodySubtle));
          }
          return _ShareCardBody(
            app: app,
            templates: _templates,
            suggestions: _suggestions,
            selectedTemplateId: _selectedTemplateId,
            message: _messageController.text,
            unlocked: _unlocked,
            isUnlocking: _isUnlocking,
            isSharing: _isSharing,
            onTemplateSelected: (id) {
              if (_unlocked) setState(() => _selectedTemplateId = id);
            },
            onMessageChanged: (v) => setState(() {}),
            messageController: _messageController,
            onWatchAd: () => _watchAd(app),
            onShare: () => _share(app),
            onDefaultShare: () => _share(app, useDefault: true),
          );
        },
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.orange)),
        error: (_, __) => Center(
            child: Text('エラーが発生しました', style: AppTextStyles.bodySubtle)),
      ),
    );
  }
}

// ─── Body ─────────────────────────────────────────────────

class _ShareCardBody extends StatelessWidget {
  const _ShareCardBody({
    required this.app,
    required this.templates,
    required this.suggestions,
    required this.selectedTemplateId,
    required this.message,
    required this.unlocked,
    required this.isUnlocking,
    required this.isSharing,
    required this.onTemplateSelected,
    required this.onMessageChanged,
    required this.messageController,
    required this.onWatchAd,
    required this.onShare,
    required this.onDefaultShare,
  });

  final AppModel app;
  final List<_Template> templates;
  final List<String> suggestions;
  final String selectedTemplateId;
  final String message;
  final bool unlocked;
  final bool isUnlocking;
  final bool isSharing;
  final ValueChanged<String> onTemplateSelected;
  final ValueChanged<String> onMessageChanged;
  final TextEditingController messageController;
  final VoidCallback onWatchAd;
  final VoidCallback onShare;
  final VoidCallback onDefaultShare;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      children: [
        // App info card
        _AppInfoCard(app: app),
        const SizedBox(height: 14),

        // OGP Preview
        _SectionLabel('プレビュー'),
        const SizedBox(height: 10),
        _OgpPreviewCard(
          app: app,
          templateId: selectedTemplateId,
          message: message,
          unlocked: unlocked,
        ),
        const SizedBox(height: 14),

        // Template selector
        _TemplateSelector(
          templates: templates,
          selectedId: selectedTemplateId,
          unlocked: unlocked,
          onSelect: onTemplateSelected,
        ),
        const SizedBox(height: 14),

        // Message editor
        _MessageEditor(
          controller: messageController,
          suggestions: suggestions,
          unlocked: unlocked,
          onChanged: onMessageChanged,
        ),
        const SizedBox(height: 14),

        // Unlock / Share buttons
        if (!unlocked) ...[
          _UnlockCard(isUnlocking: isUnlocking, onWatchAd: onWatchAd),
          const SizedBox(height: 12),
          _DefaultShareButton(isSharing: isSharing, onTap: onDefaultShare),
        ] else ...[
          _UnlockedBadge(),
          const SizedBox(height: 12),
          _ShareButton(isSharing: isSharing, onTap: onShare),
        ],
      ],
    );
  }
}

// ─── App Info Card ────────────────────────────────────────

class _AppInfoCard extends StatelessWidget {
  const _AppInfoCard({required this.app});
  final AppModel app;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0D16121D), blurRadius: 18, offset: Offset(0, 4))
        ],
      ),
      child: Row(
        children: [
          if (app.artworkUrl100 != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(11),
              child: Image.network(app.artworkUrl100!,
                  width: 44, height: 44, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _IconPlaceholder()),
            )
          else
            _IconPlaceholder(),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(app.trackName,
                    style: AppTextStyles.body
                        .copyWith(fontWeight: FontWeight.w700, fontSize: 14)),
                Text(app.developerName,
                    style: AppTextStyles.bodySubtle.copyWith(fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _IconPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.orangeBg,
        borderRadius: BorderRadius.circular(11),
      ),
      child: const Icon(Icons.apps, color: AppColors.orange, size: 22),
    );
  }
}

// ─── OGP Preview Card ────────────────────────────────────

class _OgpPreviewCard extends StatelessWidget {
  const _OgpPreviewCard({
    required this.app,
    required this.templateId,
    required this.message,
    required this.unlocked,
  });

  final AppModel app;
  final String templateId;
  final String message;
  final bool unlocked;

  @override
  Widget build(BuildContext context) {
    final isGrad = templateId == 'B';
    final isDark = templateId == 'C';

    BoxDecoration bg;
    if (isGrad) {
      bg = BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(16),
      );
    } else if (isDark) {
      bg = BoxDecoration(
        color: const Color(0xFF16121D),
        borderRadius: BorderRadius.circular(16),
      );
    } else {
      bg = BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.ink06),
      );
    }

    final textColor =
        (isGrad || isDark) ? AppColors.white : AppColors.ink;
    final subColor = (isGrad || isDark)
        ? AppColors.white.withValues(alpha: 0.7)
        : AppColors.ink55;
    final starColor = isDark ? const Color(0xFFFFAC33) : AppColors.orange;

    return AspectRatio(
      aspectRatio: 1200 / 630,
      child: Container(
        decoration: bg,
        padding: const EdgeInsets.all(20),
        child: Stack(
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // App info row
                Row(
                  children: [
                    if (app.artworkUrl100 != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(app.artworkUrl100!,
                            width: 44, height: 44, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                _OgpIconPlaceholder(isGrad: isGrad || isDark)),
                      )
                    else
                      _OgpIconPlaceholder(isGrad: isGrad || isDark),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(app.trackName,
                              style: TextStyle(
                                fontFamily: 'Zen Maru Gothic',
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: textColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          Text(
                            '${app.developerName} · ${genreJa(app.primaryGenreName)}',
                            style: TextStyle(fontSize: 10, color: subColor),
                          ),
                          if (app.averageUserRating != null)
                            Row(
                              children: [
                                ...List.generate(
                                    5,
                                    (i) => Icon(
                                          i < app.averageUserRating!.round()
                                              ? Icons.star
                                              : Icons.star_border,
                                          size: 9,
                                          color: starColor,
                                        )),
                                const SizedBox(width: 3),
                                Text(
                                    app.averageUserRating!.toStringAsFixed(1),
                                    style: TextStyle(
                                        fontSize: 10, color: subColor)),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ],
                ),

                // Message
                AnimatedOpacity(
                  opacity: unlocked ? 1.0 : 0.3,
                  duration: const Duration(milliseconds: 200),
                  child: Text(
                    message.isNotEmpty
                        ? message
                        : 'ここにカスタム文言が入ります',
                    style: TextStyle(
                      fontFamily: 'Zen Maru Gothic',
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: textColor,
                      height: 1.5,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

                // Bottom row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'App Store',
                      style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'DM Sans',
                          letterSpacing: 1,
                          color: subColor),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: isGrad
                            ? AppColors.white.withValues(alpha: 0.25)
                            : isDark
                                ? AppColors.orange.withValues(alpha: 0.25)
                                : null,
                        gradient: (!isGrad && !isDark)
                            ? AppColors.primaryGradient
                            : null,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'ダウンロード',
                        style: TextStyle(
                          fontFamily: 'DM Sans',
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: isDark ? const Color(0xFFFFAC33) : AppColors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // Lock overlay
            if (!unlocked)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.bg.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: const [
                          BoxShadow(
                              color: Color(0x0D16121D),
                              blurRadius: 18,
                              offset: Offset(0, 4))
                        ],
                      ),
                      child: Text(
                        '🔒 動画を見てカスタマイズ',
                        style: AppTextStyles.caption.copyWith(
                            color: AppColors.ink55,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _OgpIconPlaceholder extends StatelessWidget {
  const _OgpIconPlaceholder({required this.isGrad});
  final bool isGrad;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: isGrad
            ? AppColors.white.withValues(alpha: 0.15)
            : AppColors.orangeBg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(Icons.apps,
          size: 22,
          color: isGrad ? AppColors.white : AppColors.orange),
    );
  }
}

// ─── Template Selector ────────────────────────────────────

class _TemplateSelector extends StatelessWidget {
  const _TemplateSelector({
    required this.templates,
    required this.selectedId,
    required this.unlocked,
    required this.onSelect,
  });

  final List<_Template> templates;
  final String selectedId;
  final bool unlocked;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0D16121D), blurRadius: 18, offset: Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _SectionLabel('テンプレート'),
              if (!unlocked) ...[
                const Spacer(),
                Text('🔒 要アンロック',
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.orange, fontWeight: FontWeight.w700)),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: templates.map((t) {
              final selected = t.id == selectedId;
              return Expanded(
                child: GestureDetector(
                  onTap: () => onSelect(t.id),
                  child: AnimatedOpacity(
                    opacity: unlocked ? 1.0 : 0.5,
                    duration: const Duration(milliseconds: 150),
                    child: Container(
                      margin: EdgeInsets.only(
                          right: t.id != templates.last.id ? 10 : 0),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _templateBg(t.id),
                        gradient: t.id == 'B' ? AppColors.primaryGradient : null,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selected ? AppColors.orange : AppColors.ink12,
                          width: selected ? 2 : 1.5,
                        ),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Text(
                            t.label,
                            style: TextStyle(
                              fontFamily: 'DM Sans',
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: t.id == 'A'
                                  ? AppColors.ink55
                                  : AppColors.white,
                            ),
                          ),
                          if (!unlocked)
                            const Positioned.fill(
                              child: Center(
                                child: Text('🔒', style: TextStyle(fontSize: 14)),
                              ),
                            ),
                          if (selected)
                            Positioned(
                              top: 4,
                              right: 4,
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                    color: AppColors.orange,
                                    shape: BoxShape.circle),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Color? _templateBg(String id) {
    if (id == 'B') return null; // gradient handles it
    if (id == 'C') return const Color(0xFF16121D);
    return AppColors.white;
  }
}

// ─── Message Editor ───────────────────────────────────────

class _MessageEditor extends StatelessWidget {
  const _MessageEditor({
    required this.controller,
    required this.suggestions,
    required this.unlocked,
    required this.onChanged,
  });

  final TextEditingController controller;
  final List<String> suggestions;
  final bool unlocked;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0D16121D), blurRadius: 18, offset: Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _SectionLabel('文言'),
              if (!unlocked) ...[
                const Spacer(),
                Text('🔒 要アンロック',
                    style: AppTextStyles.caption.copyWith(
                        color: AppColors.orange, fontWeight: FontWeight.w700)),
              ],
            ],
          ),
          const SizedBox(height: 12),

          if (unlocked) ...[
            TextField(
              controller: controller,
              maxLength: 80,
              maxLines: 3,
              onChanged: onChanged,
              style: AppTextStyles.body
                  .copyWith(fontFamily: 'Zen Maru Gothic', height: 1.6),
              decoration: InputDecoration(
                filled: true,
                fillColor: AppColors.bg,
                counterStyle:
                    AppTextStyles.caption.copyWith(color: AppColors.ink30),
                contentPadding: const EdgeInsets.all(12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.ink12),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.ink12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: AppColors.orange, width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text('候補文言',
                style:
                    AppTextStyles.caption.copyWith(color: AppColors.ink30)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: suggestions.map((s) {
                return GestureDetector(
                  onTap: () {
                    controller.text = s;
                    onChanged(s);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.orange.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                          color: AppColors.orange.withValues(alpha: 0.2)),
                    ),
                    child: Text(s,
                        style: AppTextStyles.caption.copyWith(
                            color: AppColors.orange,
                            fontWeight: FontWeight.w600)),
                  ),
                );
              }).toList(),
            ),
          ] else ...[
            // Blurred locked state
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.bg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Opacity(
                opacity: 0.3,
                child: Text(
                  'レビューお願いします！\nぜひ使ってみてください🙏',
                  style: AppTextStyles.body.copyWith(
                      color: AppColors.ink,
                      fontFamily: 'Zen Maru Gothic',
                      height: 1.6),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Unlock Card ──────────────────────────────────────────

class _UnlockCard extends StatelessWidget {
  const _UnlockCard({required this.isUnlocking, required this.onWatchAd});
  final bool isUnlocking;
  final VoidCallback onWatchAd;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.orange.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0D16121D), blurRadius: 18, offset: Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ShaderMask(
            shaderCallback: (bounds) =>
                AppColors.primaryGradient.createShader(bounds),
            blendMode: BlendMode.srcIn,
            child: Text('✦ カスタマイズをアンロック',
                style: AppTextStyles.body
                    .copyWith(fontWeight: FontWeight.w700, fontSize: 13)),
          ),
          const SizedBox(height: 6),
          Text(
            '動画を1本見ると、文言・テンプレートを自由に変更できます。アンロックは当日中有効です。',
            style: AppTextStyles.caption
                .copyWith(color: AppColors.ink55, height: 1.6),
          ),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: isUnlocking ? null : onWatchAd,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(999),
                boxShadow: const [
                  BoxShadow(
                      color: Color(0x5CFF9500),
                      blurRadius: 22,
                      offset: Offset(0, 6)),
                ],
              ),
              child: Center(
                child: isUnlocking
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.white))
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.play_circle_outline,
                              size: 18, color: AppColors.white),
                          const SizedBox(width: 8),
                          Text('動画を見てアンロック',
                              style: AppTextStyles.body.copyWith(
                                  color: AppColors.white,
                                  fontWeight: FontWeight.w700)),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Unlocked Badge ───────────────────────────────────────

class _UnlockedBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF22C55E).withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF22C55E).withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle_outline,
              size: 16, color: Color(0xFF16A34A)),
          const SizedBox(width: 6),
          Text('カスタマイズがアンロックされました（本日中有効）',
              style: AppTextStyles.caption.copyWith(
                  color: const Color(0xFF16A34A), fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ─── Share Buttons ────────────────────────────────────────

class _ShareButton extends StatelessWidget {
  const _ShareButton({required this.isSharing, required this.onTap});
  final bool isSharing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isSharing ? null : onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(999),
          boxShadow: const [
            BoxShadow(
                color: Color(0x5CFF9500),
                blurRadius: 22,
                offset: Offset(0, 6)),
          ],
        ),
        child: Center(
          child: isSharing
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.white))
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.ios_share, size: 18, color: AppColors.white),
                    const SizedBox(width: 8),
                    Text('シェアする',
                        style: AppTextStyles.body.copyWith(
                            color: AppColors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 15)),
                  ],
                ),
        ),
      ),
    );
  }
}

class _DefaultShareButton extends StatelessWidget {
  const _DefaultShareButton({required this.isSharing, required this.onTap});
  final bool isSharing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isSharing ? null : onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.ink12, width: 1.5),
          boxShadow: const [
            BoxShadow(
                color: Color(0x0D16121D), blurRadius: 18, offset: Offset(0, 4))
          ],
        ),
        child: Center(
          child: Text('デフォルトのままシェア',
              style: AppTextStyles.body.copyWith(
                  color: AppColors.ink55, fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }
}

// ─── Helpers ─────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: AppTextStyles.caption.copyWith(
          color: AppColors.ink30,
          fontFamily: 'DM Sans',
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.8),
    );
  }
}

class _Template {
  const _Template({required this.id, required this.label});
  final String id;
  final String label;
}
