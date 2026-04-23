import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'core/config/firebase_options.dart';
import 'core/config/router.dart';
import 'core/constants/app_colors.dart';

void main() async {
  usePathUrlStrategy();
  WidgetsFlutterBinding.ensureInitialized();

  // CanvasKit / WebGL レンダリングエラーをキャッチしてクラッシュを防ぐ
  FlutterError.onError = (FlutterErrorDetails details) {
    if (details.toString().contains('makeTexture') ||
        details.toString().contains('ImageCodec')) {
      return;
    }
    FlutterError.presentError(details);
  };

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // AdMob 初期化（モバイルのみ）
  if (!kIsWeb) {
    await MobileAds.instance.initialize();
  }

  runApp(const ProviderScope(child: App()));
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'みんなのレビュー',
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.bg,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.orange,
          surface: AppColors.bg,
        ),
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        snackBarTheme: const SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
        ),
      ),
    );
  }
}
