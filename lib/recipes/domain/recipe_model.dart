/// Equivalente a `recipes/domain/recipe.model.ts`.
class Recipe {
  const Recipe({
    required this.id,
    required this.title,
    this.description,
    this.image,
    this.rating,
    this.level,
    this.type,
    this.time,
    this.ingredients = const [],
    this.steps = const [],
  });

  final int id;
  final String title;
  final String? description;
  final String? image;
  final double? rating;
  final String? level;
  final String? type;
  final String? time;
  final List<String> ingredients;
  final List<String> steps;

  factory Recipe.fromJson(Map<String, dynamic> json) => Recipe(
    id: (json['id'] as num).toInt(),
    title: json['title'] as String? ?? '',
    description: json['description'] as String?,
    image: json['image'] as String?,
    rating: (json['rating'] as num?)?.toDouble(),
    level: json['level'] as String?,
    type: json['type'] as String?,
    time: json['time']?.toString(),
    ingredients: (json['ingredients'] as List? ?? []).map((e) => '$e').toList(),
    steps: (json['steps'] as List? ?? []).map((e) => '$e').toList(),
  );

  Map<String, dynamic> toJson() => {
    'title': title,
    'description': description,
    'image': image,
    'rating': rating,
    'level': level,
    'type': type,
    'time': time,
    'ingredients': ingredients,
    'steps': steps,
  };
}
