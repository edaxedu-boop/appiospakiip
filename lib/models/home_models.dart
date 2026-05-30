import '../services/api_service.dart';

class RestaurantModel {
  final String id;
  final String name;
  final String address;
  final String? logoUrl;
  final List<String> categories;
  final int rating;
  final int minTime;
  final int maxTime;
  final bool isOpen;
  final double? lat;
  final double? lng;
  final double? distanceM;

  RestaurantModel({
    required this.id,
    required this.name,
    required this.address,
    this.logoUrl,
    required this.categories,
    this.rating = 5,
    this.minTime = 20,
    this.maxTime = 40,
    this.isOpen = true,
    this.lat,
    this.lng,
    this.distanceM,
  });

  factory RestaurantModel.fromJson(Map<String, dynamic> j) => RestaurantModel(
    id: j['id'].toString(),
    name: j['name'] ?? '',
    address: j['address'] ?? '',
    logoUrl: j['logo_url'],
    categories:
        (j['categories'] as List?)?.cast<String>() ??
        (j['category'] != null ? [j['category'] as String] : []),
    rating: (j['rating'] as num?)?.toInt().clamp(1, 5) ?? 5,
    minTime: (j['min_time'] as num?)?.toInt() ?? 20,
    maxTime: (j['max_time'] as num?)?.toInt() ?? 40,
    isOpen: j['is_open'] as bool? ?? true,
    lat: j['lat'] != null ? double.tryParse(j['lat'].toString()) : null,
    lng: j['lng'] != null ? double.tryParse(j['lng'].toString()) : null,
    distanceM: j['distance_m'] != null
        ? double.tryParse(j['distance_m'].toString())
        : null,
  );

  bool get isHotel => categories.any((c) => c.toLowerCase().contains('hotel'));

  String get fullLogoUrl {
    if (logoUrl == null || logoUrl!.isEmpty) return '';
    if (logoUrl!.startsWith('http')) return logoUrl!;
    return '${ApiService.baseUrl}$logoUrl';
  }
}

class PromoModel {
  final int id;
  final String title;
  final String? description;
  final String imageUrl;
  final int? restaurantId;
  final String? restaurantName;
  final String? restaurantAddress;
  final String? restaurantCategory;
  final int? restaurantRating;
  final int? restaurantMinTime;
  final int? restaurantMaxTime;
  final String? restaurantLogoUrl;
  final String? link;
  final double? restaurantLat;
  final double? restaurantLng;

  PromoModel({
    required this.id,
    required this.title,
    this.description,
    required this.imageUrl,
    this.restaurantId,
    this.restaurantName,
    this.restaurantAddress,
    this.restaurantCategory,
    this.restaurantRating,
    this.restaurantMinTime,
    this.restaurantMaxTime,
    this.restaurantLogoUrl,
    this.link,
    this.restaurantLat,
    this.restaurantLng,
  });

  factory PromoModel.fromJson(Map<String, dynamic> j) => PromoModel(
    id: j['id'] as int,
    title: j['title'] as String,
    description: j['description'] as String?,
    imageUrl: j['image_url'] as String,
    restaurantId: j['restaurant_id'] as int?,
    restaurantName: j['restaurant_name'] as String?,
    restaurantAddress: j['restaurant_address'] as String?,
    restaurantCategory: j['restaurant_category'] as String?,
    restaurantRating: (j['restaurant_rating'] as num?)?.toInt(),
    restaurantMinTime: (j['restaurant_min_time'] as num?)?.toInt(),
    restaurantMaxTime: (j['restaurant_max_time'] as num?)?.toInt(),
    restaurantLogoUrl: j['restaurant_logo_url'] as String?,
    link: j['link'] as String?,
    restaurantLat: j['restaurant_lat'] != null
        ? double.tryParse(j['restaurant_lat'].toString())
        : null,
    restaurantLng: j['restaurant_lng'] != null
        ? double.tryParse(j['restaurant_lng'].toString())
        : null,
  );

  String get fullImageUrl {
    if (imageUrl.startsWith('http')) return imageUrl;
    return '${ApiService.baseUrl}$imageUrl';
  }
}






