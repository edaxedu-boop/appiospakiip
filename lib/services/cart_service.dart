import 'package:flutter/material.dart';
import '../models/restaurant_models.dart';

class CartService extends ChangeNotifier {
  static final CartService _instance = CartService._internal();
  factory CartService() => _instance;
  CartService._internal();

  final List<CartItem> _items = [];
  String? _currentRestaurantId;
  String? _currentRestaurantName;
  int? _minTime;
  int? _maxTime;
  String _address = '';
  double? _userLat;
  double? _userLng;
  double? _restaurantLat;
  double? _restaurantLng;

  List<CartItem> get items => List.unmodifiable(_items);
  String? get currentRestaurantId => _currentRestaurantId;
  String? get currentRestaurantName => _currentRestaurantName;
  int? get minTime => _minTime;
  int? get maxTime => _maxTime;
  String get address => _address;
  double? get userLat => _userLat;
  double? get userLng => _userLng;
  double? get restaurantLat => _restaurantLat;
  double? get restaurantLng => _restaurantLng;

  void setAddress(String newAddress, {double? lat, double? lng}) {
    _address = newAddress;
    _userLat = lat;
    _userLng = lng;
    notifyListeners();
  }

  /// Returns true if the item was added successfully.
  /// Returns false if there is a restaurant conflict (caller should show dialog).
  bool tryAddItem(
    CartItem newItem,
    String restaurantId,
    String restaurantName,
    int minTime,
    int maxTime, {
    double? restLat,
    double? restLng,
  }) {
    if (_currentRestaurantId != null && _currentRestaurantId != restaurantId) {
      // Conflict — different restaurant
      return false;
    }
    _addItemInternal(
      newItem,
      restaurantId,
      restaurantName,
      minTime,
      maxTime,
      restLat: restLat,
      restLng: restLng,
    );
    return true;
  }

  /// Force-add: clears the old cart and adds the new item.
  void forceAddItem(
    CartItem newItem,
    String restaurantId,
    String restaurantName,
    int minTime,
    int maxTime, {
    double? restLat,
    double? restLng,
  }) {
    _items.clear();
    _addItemInternal(
      newItem,
      restaurantId,
      restaurantName,
      minTime,
      maxTime,
      restLat: restLat,
      restLng: restLng,
    );
  }

  void _addItemInternal(
    CartItem newItem,
    String restaurantId,
    String restaurantName,
    int minTime,
    int maxTime, {
    double? restLat,
    double? restLng,
  }) {
    _currentRestaurantId = restaurantId;
    _currentRestaurantName = restaurantName;
    _minTime = minTime;
    _maxTime = maxTime;
    _restaurantLat = restLat;
    _restaurantLng = restLng;

    // If same product + same options already in cart, just increment quantity
    int existingIndex = _items.indexWhere(
      (item) =>
          item.product.id == newItem.product.id &&
          _areOptionsEqual(item.selectedOptions, newItem.selectedOptions),
    );

    if (existingIndex != -1) {
      _items[existingIndex].quantity += newItem.quantity;
    } else {
      _items.add(newItem);
    }
    notifyListeners();
  }

  void removeItem(CartItem item) {
    _items.remove(item);
    if (_items.isEmpty) {
      _currentRestaurantName = null;
    }
    notifyListeners();
  }

  void updateQuantity(CartItem item, int quantity) {
    if (quantity <= 0) {
      removeItem(item);
    } else {
      item.quantity = quantity;
      notifyListeners();
    }
  }

  void clear() {
    _items.clear();
    _currentRestaurantId = null;
    _currentRestaurantName = null;
    _minTime = null;
    _maxTime = null;
    _restaurantLat = null;
    _restaurantLng = null;
    notifyListeners();
  }

  int get totalItems => _items.fold(0, (sum, item) => sum + item.quantity);

  double get totalPrice => _items.fold(0, (sum, item) => sum + item.totalPrice);

  bool _areOptionsEqual(List<ProductOption> a, List<ProductOption> b) {
    if (a.length != b.length) return false;
    final listA = a.map((e) => e.name).toList()..sort();
    final listB = b.map((e) => e.name).toList()..sort();
    for (int i = 0; i < listA.length; i++) {
      if (listA[i] != listB[i]) return false;
    }
    return true;
  }
}






