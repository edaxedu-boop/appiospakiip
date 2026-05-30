import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/restaurant_models.dart';
import '../../services/cart_service.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/api_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:pakiip/screens/common/cart_screen.dart';

// --- Screen ---

class RestaurantDetailScreen extends StatefulWidget {
  final String id;
  final String name;
  final String heroImage;
  final int rating;
  final int minTime;
  final int maxTime;
  final List<String> categories;
  final bool isOpen;
  final double? restLat;
  final double? restLng;

  const RestaurantDetailScreen({
    super.key,
    required this.id,
    required this.name,
    required this.heroImage,
    required this.categories,
    this.rating = 5,
    this.minTime = 20,
    this.maxTime = 40,
    this.isOpen = true,
    this.restLat,
    this.restLng,
  });

  @override
  State<RestaurantDetailScreen> createState() => _RestaurantDetailScreenState();
}

class _RestaurantDetailScreenState extends State<RestaurantDetailScreen> {
  int _selectedCategoryIndex = 0;
  List<String> _categories = ['Todos'];
  bool _loading = true;

  Map<String, List<Product>> _productsByCategory = {};
  double? _restLat;
  double? _restLng;
  double? _distanceM;
  double _baseCost1Km = 4.00;
  double _priceIntermediate = 1.00;
  double _priceLong = 2.00;
  late String _heroImageUrl; // imagen de portada, se actualiza desde API
  String? _restPhone;

  bool get _isHotel => widget.categories.any((c) => c.toLowerCase().contains('hotel'));

  @override
  void initState() {
    super.initState();
    _heroImageUrl = widget.heroImage; // valor inicial del padre
    _restLat = widget.restLat;
    _restLng = widget.restLng;
    _loadMenu();
  }

  Future<void> _loadMenu() async {
    setState(() => _loading = true);
    try {
      // Siempre obtener datos del perfil público para asegurar tener el teléfono (WhatsApp)
      try {
        final restData = await ApiService.get(
          '/restaurants/public/${widget.id}',
        );
        if (_restLat == null || _restLng == null) {
          _restLat = restData['lat'] != null
              ? double.tryParse(restData['lat'].toString())
              : null;
          _restLng = restData['lng'] != null
              ? double.tryParse(restData['lng'].toString())
              : null;
        }
        
        if (mounted) {
          setState(() {
            _restPhone = restData['phone']?.toString();
            
            final logoUrl = restData['logo_url'] as String?;
            if (logoUrl != null && logoUrl.isNotEmpty) {
              _heroImageUrl = logoUrl.startsWith('http')
                  ? logoUrl
                  : '${ApiService.baseUrl}$logoUrl';
            }
          });
        }
      } catch (_) {}

      // Calcular distancia si tenemos coordenadas del usuario y del restaurante
      if (!mounted) return;
      final cartService = Provider.of<CartService>(context, listen: false);
      if (_restLat != null &&
          _restLng != null &&
          cartService.userLat != null &&
          cartService.userLng != null) {
        _distanceM = Geolocator.distanceBetween(
          cartService.userLat!,
          cartService.userLng!,
          _restLat!,
          _restLng!,
        );
      }

      try {
        final config = await ApiService.get('/config/public');
        _baseCost1Km =
            double.tryParse((config['base_cost_1km'] ?? '4.00').toString()) ??
            4.00;
        _priceIntermediate =
            double.tryParse(
              (config['price_per_km_intermediate'] ?? '1.00').toString(),
            ) ??
            1.00;
        _priceLong =
            double.tryParse(
              (config['price_per_km_long'] ?? '2.00').toString(),
            ) ??
            2.00;
      } catch (_) {}

      final list = await ApiService.getList(
        '/products/restaurant/${widget.id}',
      );

      final List<Product> products = list.map((item) {
        final p = item as Map<String, dynamic>;
        final rawGroups = p['groups'] as List?;

        List<OptionGroup> groups = [];
        if (rawGroups != null) {
          groups = rawGroups.map((g) {
            final rawOptions = g['options'] as List?;
            return OptionGroup(
              title: g['title'] ?? '',
              isMandatory: g['required'] ?? false,
              isMultiSelect: g['multiSelect'] ?? false,
              maxSelection: g['maxSelect'] ?? 1,
              options: (rawOptions ?? [])
                  .map(
                    (o) => ProductOption(
                      name: o['name'] ?? '',
                      price: (o['price'] ?? 0).toDouble(),
                    ),
                  )
                  .toList(),
            );
          }).toList();
        }

        final img = p['image_url'] as String?;
        final fullProductImg = (img == null || img.isEmpty)
            ? _heroImageUrl
            : (img.startsWith('http') ? img : '${ApiService.baseUrl}$img');

        return Product(
          id: p['id'].toString(),
          name: p['name'] ?? '',
          description: p['description'] ?? '',
          price: double.tryParse(p['price'].toString()) ?? 0.0,
          imageUrl: fullProductImg,
          category: p['category'] ?? 'General',
          optionGroups: groups,
        );
      }).toList();

      // Agrupar por categorías
      final tempProductsByCategory = {'Todos': products};
      for (var p in products) {
        final cat = p.category.isEmpty ? 'General' : p.category;
        if (!tempProductsByCategory.containsKey(cat)) {
          tempProductsByCategory[cat] = [];
        }
        tempProductsByCategory[cat]!.add(p);
      }

      // Intentar obtener categorías ordenadas del restaurante
      List<String> finalCategories = [];
      try {
        final catList = await ApiService.getList(
          '/categories/restaurant/${widget.id}',
        );
        final List<String> orderedNames = ['Todos'];
        for (var c in catList) {
          final name = c['name'] as String;
          if (tempProductsByCategory.containsKey(name)) {
            orderedNames.add(name);
          }
        }
        // Añadir cualquier categoría que tenga productos pero no esté en la lista oficial
        for (var cat in tempProductsByCategory.keys) {
          if (!orderedNames.contains(cat)) {
            orderedNames.add(cat);
          }
        }
        finalCategories = orderedNames;
      } catch (_) {
        finalCategories = tempProductsByCategory.keys.toList();
      }

      if (mounted) {
        setState(() {
          _productsByCategory = tempProductsByCategory;
          _categories = finalCategories;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
      // print('Error cargando menú: $e');
    }
  }

  List<Product> get _currentProducts {
    final cat = _categories[_selectedCategoryIndex];
    return _productsByCategory[cat] ?? [];
  }

  void _addToCart(Product product, [List<ProductOption>? options]) {
    final cartService = Provider.of<CartService>(context, listen: false);
    final ok = cartService.tryAddItem(
      CartItem(product: product, selectedOptions: options ?? [], quantity: 1),
      widget.id,
      widget.name,
      widget.minTime,
      widget.maxTime,
      restLat: _restLat,
      restLng: _restLng,
    );

    if (!ok) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1F222A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            '⚠️ Pedido en cola',
            style: GoogleFonts.poppins(
              color: Colors.black87,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'Ya tienes un pedido de "${cartService.currentRestaurantName}" en tu carrito.\n\n¿Deseas descartarlo y empezar un nuevo pedido de "${widget.name}"?',
            style: GoogleFonts.poppins(color: Colors.black54, fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'Cancelar',
                style: GoogleFonts.poppins(color: Colors.black45),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                cartService.forceAddItem(
                  CartItem(
                    product: product,
                    selectedOptions: options ?? [],
                    quantity: 1,
                  ),
                  widget.id,
                  widget.name,
                  widget.minTime,
                  widget.maxTime,
                  restLat: _restLat,
                  restLng: _restLng,
                );
                _showSuccessSnack();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFA7516),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Sí, nuevo pedido',
                style: GoogleFonts.poppins(
                  color: Colors.black87,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      );
      return;
    }
    _showSuccessSnack();
  }

  void _showSuccessSnack() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('¡${widget.name} agregado al carrito!'),
        backgroundColor: const Color(0xFF4CAF50),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _showProductOptions(Product product) {
    if (!widget.isOpen) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.lock_clock, color: Colors.black87, size: 16),
              const SizedBox(width: 8),
              Text(
                'El restaurante está cerrado ahora',
                style: GoogleFonts.poppins(color: Colors.white),
              ),
            ],
          ),
          backgroundColor: Colors.white,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }
    if (product.optionGroups.isEmpty) {
      _addToCart(product);
      return;
    }

    final Map<int, List<ProductOption>> selections = {};
    for (int i = 0; i < product.optionGroups.length; i++) {
      selections[i] = [];
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFFF9FAFB),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          bool canConfirm = true;
          double currentTotal = product.price;
          for (int i = 0; i < product.optionGroups.length; i++) {
            final g = product.optionGroups[i];
            if (g.isMandatory && selections[i]!.isEmpty) {
              canConfirm = false;
            }
            // Sumar el precio de las opciones seleccionadas
            for (var opt in selections[i]!) {
              currentTotal += opt.price;
            }
          }

          return Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.85,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            product.name,
                            style: GoogleFonts.poppins(
                              color: Colors.black87,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Personaliza tu pedido',
                            style: GoogleFonts.poppins(
                              color: Colors.black45,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      'S/ ${currentTotal.toStringAsFixed(2)}',
                      style: GoogleFonts.poppins(
                        color: const Color(0xFFFA7516),
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(color: Colors.black12),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: product.optionGroups.length,
                    itemBuilder: (ctx, gIdx) {
                      final group = product.optionGroups[gIdx];
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              Text(
                                group.title,
                                style: GoogleFonts.poppins(
                                  color: Colors.black87,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Spacer(),
                              if (group.isMandatory)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFFFA7516,
                                    ).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'OBLIGATORIO',
                                    style: GoogleFonts.poppins(
                                      color: const Color(0xFFFA7516),
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                )
                              else
                                Text(
                                  'OPCIONAL',
                                  style: GoogleFonts.poppins(
                                    color: Colors.black26,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                            ],
                          ),
                          Text(
                            group.isMultiSelect
                                ? 'Selecciona hasta ${group.maxSelection}'
                                : 'Selecciona 1 opción',
                            style: GoogleFonts.poppins(
                              color: Colors.black38,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ...group.options.map((opt) {
                            final isSel = selections[gIdx]!.contains(opt);
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: InkWell(
                                onTap: () {
                                  setS(() {
                                    if (group.isMultiSelect) {
                                      if (isSel) {
                                        selections[gIdx]!.remove(opt);
                                      } else if (selections[gIdx]!.length <
                                          group.maxSelection) {
                                        selections[gIdx]!.add(opt);
                                      }
                                    } else {
                                      selections[gIdx] = [opt];
                                    }
                                  });
                                },
                                borderRadius: BorderRadius.circular(16),
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: isSel
                                        ? const Color(
                                            0xFFFA7516,
                                          ).withValues(alpha: 0.05)
                                        : const Color(0xFFF5F5F5),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: isSel
                                          ? const Color(
                                              0xFFFA7516,
                                            ).withValues(alpha: 0.3)
                                          : Colors.black.withValues(
                                              alpha: 0.05,
                                            ),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          opt.name,
                                          style: GoogleFonts.poppins(
                                            color: isSel
                                                ? Colors.black87
                                                : Colors.black54,
                                            fontWeight: isSel
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                          ),
                                        ),
                                      ),
                                      if (opt.price > 0)
                                        Text(
                                          '+ S/ ${opt.price.toStringAsFixed(2)}',
                                          style: GoogleFonts.poppins(
                                            color: isSel
                                                ? const Color(0xFFFA7516)
                                                : Colors.black38,
                                            fontSize: 13,
                                          ),
                                        ),
                                      const SizedBox(width: 12),
                                      Icon(
                                        isSel
                                            ? Icons.check_circle_rounded
                                            : Icons.circle_outlined,
                                        color: isSel
                                            ? const Color(0xFFFA7516)
                                            : Colors.black12,
                                        size: 22,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }),
                          const SizedBox(height: 10),
                        ],
                      );
                    },
                  ),
                ),
                const Divider(color: Colors.black12),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: canConfirm
                        ? () {
                            final List<ProductOption> allSelected = [];
                            for (var list in selections.values) {
                              allSelected.addAll(list);
                            }
                            Navigator.pop(ctx);
                            _addToCart(product, allSelected);
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFA7516),
                      disabledBackgroundColor: Colors.black12,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      canConfirm
                          ? 'Agregar al carrito'
                          : 'Selecciona las opciones obligatorias',
                      style: GoogleFonts.poppins(
                        color: canConfirm ? Colors.white : Colors.black26,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cartService = Provider.of<CartService>(context);
    final cartCount = cartService.totalItems;
    final cartTotal = cartService.totalPrice;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          _loading
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFFFA7516)),
                )
              : CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    _buildSliverAppBar(),
                    if (!widget.isOpen && !_isHotel)
                      SliverToBoxAdapter(
                        child: Container(
                          margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: const Color(
                                0xFFFA7516,
                              ).withOpacity(0.1),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(
                                  0xFFFA7516,
                                ).withOpacity(0.1),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFFFA7516,
                                  ).withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.lock_clock_rounded,
                                  color: Color(0xFFFA7516),
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Restaurante cerrado',
                                      style: GoogleFonts.poppins(
                                        color: Colors.black87,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    Text(
                                      'Ahora mismo no estamos tomando pedidos. Vuelve más tarde.',
                                      style: GoogleFonts.poppins(
                                        color: Colors.black45,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    // ── Pestañas de Categoría con Estilo 3D ──
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: _CategoryHeaderDelegate(
                        categories: _categories,
                        selectedIndex: _selectedCategoryIndex,
                        onCategorySelected: (idx) {
                          setState(() => _selectedCategoryIndex = idx);
                        },
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 120),
                      sliver: _selectedCategoryIndex == 0
                          ? _buildAllSections()
                          : _buildSingleSection(),
                    ),
                  ],
                ),
          if (cartCount > 0 && !_isHotel) _buildFloatingCart(cartCount, cartTotal),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar() {
    final deliveryCost = _calculateDeliveryCost();
    return SliverAppBar(
      expandedHeight: 320,
      pinned: true,
      backgroundColor: Colors.white,
      elevation: 0,
      leading: Padding(
        padding: const EdgeInsets.all(8.0),
        child: CircleAvatar(
          backgroundColor: Colors.white,
          child: BackButton(color: Colors.black87),
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            _heroImageUrl.isNotEmpty
                ? Image.network(
                    _heroImageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(color: Colors.black12),
                  )
                : Container(color: Colors.black12),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.3),
                    Colors.transparent,
                    Colors.black.withOpacity(0.7),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: 40,
              left: 20,
              right: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.name,
                    style: GoogleFonts.poppins(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          color: Colors.black26,
                          blurRadius: 10,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 30,
                          offset: const Offset(0, 15),
                        ),
                        // Efecto 3D de profundidad
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          offset: const Offset(0, 6),
                          blurRadius: 0,
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: _isHotel ? MainAxisAlignment.center : MainAxisAlignment.spaceBetween,
                          children: [
                            if (!_isHotel)
                              _infoItem(
                                Icons.star_rounded,
                                widget.rating.toDouble().toStringAsFixed(1),
                                'Rating',
                                Colors.amber,
                              ),
                            if (!_isHotel)
                              _infoItem(
                                Icons.access_time_filled_rounded,
                                '${widget.minTime}-${widget.maxTime} min',
                                'Tiempo',
                                const Color(0xFFFA7516),
                              ),
                            _infoItem(
                              Icons.location_on_rounded,
                              _distanceM != null 
                                ? '${(_distanceM! / 1000).toStringAsFixed(1)} km'
                                : '-- km',
                              'Distancia',
                              Colors.redAccent,
                            ),
                            if (!_isHotel)
                              _infoItem(
                                Icons.delivery_dining_rounded,
                                'S/ ${deliveryCost.toStringAsFixed(2)}',
                                'Delivery',
                                Colors.blue,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoItem(IconData icon, String value, String label, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: Colors.black87,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.poppins(
            color: Colors.black38,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildAllSections() {
    List<Widget> slivers = [];
    final cats = _categories.where((c) => c != 'Todos').toList();
    for (var cat in cats) {
      slivers.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: 24, bottom: 16),
            child: Row(
              children: [
                Text(
                  cat,
                  style: GoogleFonts.poppins(
                    color: Colors.black87,
                    fontWeight: FontWeight.bold,
                    fontSize: 22,
                  ),
                ),
                if (cat.toLowerCase().contains('populares') ||
                    cat.toLowerCase().contains('combos')) ...[
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.fireplace,
                    color: Color(0xFFFA7516),
                    size: 20,
                  ),
                ],
              ],
            ),
          ),
        ),
      );
      slivers.add(_buildProductList(_productsByCategory[cat] ?? []));
    }
    return SliverMainAxisGroup(slivers: slivers);
  }

  Widget _buildSingleSection() {
    return _buildProductList(_currentProducts);
  }

  Widget _buildProductList(List<Product> products) {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) => _buildProductCard(products[index]),
        childCount: products.length,
      ),
    );
  }

  Widget _buildProductCard(Product p) {
    String priceDisplay = 'S/ ${p.price.toStringAsFixed(2)}';
    if (p.price == 0 && p.optionGroups.isNotEmpty) {
      double minOptionPrice = double.infinity;
      for (var group in p.optionGroups) {
        if (group.isMandatory) {
          for (var opt in group.options) {
            if (opt.price < minOptionPrice) minOptionPrice = opt.price;
          }
        }
      }
      if (minOptionPrice != double.infinity) {
        priceDisplay = 'Desde S/ ${minOptionPrice.toStringAsFixed(2)}';
      }
    }

    return GestureDetector(
      onTap: () => _isHotel ? _openWhatsApp(p) : _showProductOptions(p),
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            // Efecto 3D de profundidad
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              offset: const Offset(0, 6),
              blurRadius: 0,
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(24),
              ),
              child: Image.network(
                p.imageUrl,
                width: 110,
                height: 110,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  width: 110,
                  height: 110,
                  color: Colors.black.withValues(alpha: 0.05),
                  child: const Icon(
                    Icons.fastfood_rounded,
                    color: Colors.black12,
                    size: 32,
                  ),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.name,
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.black87,
                        letterSpacing: -0.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      p.description,
                      style: GoogleFonts.poppins(
                        color: Colors.black45,
                        fontSize: 11,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          priceDisplay,
                          style: GoogleFonts.poppins(
                            color: const Color(0xFFFA7516),
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        if (_isHotel)
                          GestureDetector(
                            onTap: () => _openWhatsApp(p),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF25D366), // WhatsApp Green
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF25D366).withOpacity(0.2),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.chat, color: Colors.white, size: 16),
                                  const SizedBox(width: 6),
                                  Text(
                                    'RESERVAR',
                                    style: GoogleFonts.poppins(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFA7516),
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(
                                    0xFFFA7516,
                                  ).withValues(alpha: 0.2),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.add_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openWhatsApp(Product p) async {
    if (_restPhone == null) {
      // Re-intentar obtener el teléfono si falló antes
      try {
        final restData = await ApiService.get('/restaurants/public/${widget.id}');
        _restPhone = restData['phone']?.toString();
      } catch (_) {}
    }

    final phone = _restPhone ?? '51900000000'; 
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    final fullPhone = cleanPhone.startsWith('51') ? cleanPhone : '51$cleanPhone';
    
    final message = 'Hola ${widget.name}, me gustaría reservar: ${p.name}.';
    
    // Intentar primero con el esquema de la app, luego con el link web
    final whatsappUrl = Uri.parse('whatsapp://send?phone=$fullPhone&text=${Uri.encodeComponent(message)}');
    final webUrl = Uri.parse('https://api.whatsapp.com/send?phone=$fullPhone&text=${Uri.encodeComponent(message)}');
    
    try {
      if (await canLaunchUrl(whatsappUrl)) {
        await launchUrl(whatsappUrl);
      } else {
        await launchUrl(webUrl, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo abrir WhatsApp')),
        );
      }
    }
  }

  Widget _buildFloatingCart(int count, double total) {
    return Positioned(
      bottom: 24,
      left: 16,
      right: 16,
      child: GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CartScreen(
              cartItems: Provider.of<CartService>(context, listen: false).items,
              restaurantName: widget.name,
            ),
          ),
        ),
        child: Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: const Color(0xFFFA7516), // Color sólido como captura
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFA7516).withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.25),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '$count',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              const Expanded(
                child: Center(
                  child: Text(
                    'Ver Carrito',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              Text(
                'S/ ${total.toStringAsFixed(2)}',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  double _calculateDeliveryCost() {
    double deliveryCost = _baseCost1Km;
    if (_distanceM != null) {
      double distanceKm = _distanceM! / 1000;
      if (distanceKm > 1.0 && distanceKm <= 3.0) {
        deliveryCost = _baseCost1Km + ((distanceKm - 1.0) * _priceIntermediate);
      } else if (distanceKm > 3.0) {
        deliveryCost =
            _baseCost1Km +
            (2.0 * _priceIntermediate) +
            ((distanceKm - 3.0) * _priceLong);
      }
    }
    return double.parse(deliveryCost.toStringAsFixed(2));
  }
}

class _CategoryHeaderDelegate extends SliverPersistentHeaderDelegate {
  final List<String> categories;
  final int selectedIndex;
  final Function(int) onCategorySelected;

  _CategoryHeaderDelegate({
    required this.categories,
    required this.selectedIndex,
    required this.onCategorySelected,
  });

  @override
  double get minExtent => 80;
  @override
  double get maxExtent => 80;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: categories.length,
        itemBuilder: (ctx, i) {
          final sel = selectedIndex == i;
          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: () => onCategorySelected(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: sel ? const Color(0xFFFA7516) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: sel
                        ? const Color(0xFFFA7516)
                        : Colors.black.withValues(alpha: 0.08),
                    width: 1.5,
                  ),
                  boxShadow: [
                    if (sel)
                      BoxShadow(
                        color: const Color(0xFFFA7516).withOpacity(0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    // Efecto 3D suave
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      offset: const Offset(0, 4),
                      blurRadius: 0,
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    categories[i],
                    style: GoogleFonts.poppins(
                      color: sel ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _CategoryHeaderDelegate oldDelegate) {
    return oldDelegate.selectedIndex != selectedIndex ||
        oldDelegate.categories != categories;
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final double minHeight;
  final double maxHeight;
  final Widget child;
  _SliverAppBarDelegate({
    required this.minHeight,
    required this.maxHeight,
    required this.child,
  });
  @override
  double get minExtent => minHeight;
  @override
  double get maxExtent => maxHeight;
  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => SizedBox.expand(child: child);
  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) =>
      maxHeight != oldDelegate.maxHeight ||
      minHeight != oldDelegate.minHeight ||
      child != oldDelegate.child;
}
