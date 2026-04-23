import 'package:flutter/material.dart';

/// App Store の primaryGenreName（英語）→ 日本語表示名
const Map<String, String> kGenreNames = {
  'Games': 'ゲーム',
  'Productivity': '仕事効率化',
  'Social Networking': 'SNS',
  'Photo & Video': '写真/ビデオ',
  'Music': 'ミュージック',
  'Entertainment': 'エンターテインメント',
  'Utilities': 'ユーティリティ',
  'Travel': '旅行',
  'Finance': 'ファイナンス',
  'Shopping': 'ショッピング',
  'News': 'ニュース',
  'Education': '教育',
  'Health & Fitness': 'ヘルス/フィットネス',
  'Food & Drink': 'フード/ドリンク',
  'Sports': 'スポーツ',
  'Business': 'ビジネス',
  'Lifestyle': 'ライフスタイル',
  'Weather': '天気',
  'Medical': '医療',
  'Navigation': 'ナビゲーション',
  'Book': 'ブック',
  'Books': 'ブック',
  'Reference': '辞書/辞典',
  'Catalogs': 'カタログ',
  'Developer Tools': '開発ツール',
  'Graphics & Design': 'グラフィック/デザイン',
  'Magazines & Newspapers': '雑誌/新聞',
  'Kids': 'キッズ',
  'Stickers': 'ステッカー',
};

String genreJa(String english) => kGenreNames[english] ?? english;

/// ジャンル → アイコン
const Map<String, IconData> kGenreIcons = {
  'Games': Icons.sports_esports,
  'Productivity': Icons.work_outline,
  'Social Networking': Icons.people_outline,
  'Photo & Video': Icons.photo_camera_outlined,
  'Music': Icons.music_note,
  'Entertainment': Icons.movie_outlined,
  'Utilities': Icons.build_outlined,
  'Travel': Icons.flight,
  'Finance': Icons.account_balance_outlined,
  'Shopping': Icons.shopping_bag_outlined,
  'News': Icons.newspaper,
  'Education': Icons.school_outlined,
  'Health & Fitness': Icons.fitness_center,
  'Food & Drink': Icons.restaurant_outlined,
  'Sports': Icons.sports,
  'Business': Icons.business_center_outlined,
  'Lifestyle': Icons.spa_outlined,
  'Weather': Icons.wb_sunny_outlined,
  'Medical': Icons.local_hospital_outlined,
  'Navigation': Icons.navigation_outlined,
  'Book': Icons.menu_book,
  'Books': Icons.menu_book,
  'Reference': Icons.menu_book_outlined,
  'Developer Tools': Icons.code,
  'Graphics & Design': Icons.palette_outlined,
  'Magazines & Newspapers': Icons.article_outlined,
  'Kids': Icons.child_care,
};

IconData genreIcon(String english) =>
    kGenreIcons[english] ?? Icons.category_outlined;
