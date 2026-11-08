import 'package:dio/dio.dart';

import '../../environments/environment.dart';
import '../domain/recipe_model.dart';

/// Equivalente a `recipes/infrastructure/recipes-api.ts`.
class RecipesApi {
  RecipesApi(this._http);

  final Dio _http;
  static const _base = '${Environment.apiBaseUrl}/recipes';

  Future<List<Recipe>> getAll() async {
    final res = await _http.get(_base);
    return (res.data as List? ?? []).map((e) => Recipe.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Recipe> getById(int id) async {
    final res = await _http.get('$_base/$id');
    return Recipe.fromJson(res.data as Map<String, dynamic>);
  }

  Future<Recipe> create(Recipe recipe) async {
    final res = await _http.post(_base, data: recipe.toJson());
    return Recipe.fromJson(res.data as Map<String, dynamic>);
  }

  Future<List<Recipe>> generateBatch() async {
    final res = await _http.post('$_base/generate-batch', data: {});
    return (res.data as List? ?? []).map((e) => Recipe.fromJson(e as Map<String, dynamic>)).toList();
  }
}
