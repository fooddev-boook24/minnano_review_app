import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/firestore_service.dart';
import '../../shared/models/app_model.dart';
import '../../shared/models/category_insight.dart';

final selectedCategoryProvider = StateProvider<String?>((ref) => null);

final categoriesProvider = FutureProvider<List<String>>((ref) async {
  return ref.read(firestoreServiceProvider).getCategories();
});

final categoryInsightProvider =
    FutureProvider.family<CategoryInsight?, String>((ref, categoryName) async {
  return ref.read(firestoreServiceProvider).getCategoryInsight(categoryName);
});

final categoryTopAppsProvider =
    FutureProvider.family<List<AppModel>, String>((ref, category) async {
  return ref.read(firestoreServiceProvider).getAppsByCategory(category);
});
