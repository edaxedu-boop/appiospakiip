import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../widgets/rider_request_sheet.dart';
import '../../services/api_service.dart';
import '../../services/cart_service.dart';
import '../../widgets/delivery_location_dialog.dart';
import 'package:pakiip/screens/common/cart_screen.dart';
import 'package:pakiip/screens/common/orders_screen.dart';
import 'package:pakiip/screens/common/profile_screen.dart';
import 'package:pakiip/screens/restaurant/restaurant_detail_screen.dart';
import 'package:pakiip/screens/auth/welcome_screen.dart';
import '../../models/home_models.dart';
import '../../widgets/restaurant_card.dart';
import '../../widgets/promo_slider.dart';
import '../../widgets/home_widgets.dart';

// ─────────────────────────────────────────────────────────────────────────────
// HomeScreen
// ─────────────────────────────────────────────────────────────────────────────
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();

  static const Color _card = Colors.white;
  static const Color _red = Color(0xFFFA7516);

  List<RestaurantModel> _restaurants = [];
  List<String> _categories = ['Todos'];
  String _selectedCategory = 'Todos';
  bool _loading = true;
  String? _error;
  String _deliveryAddress = '';
  String _clientName = '';
  double? _userLat;
  double? _userLng;
  String? _profileImageUrl;

  List<PromoModel> _promos = [];
  final PageController _promoCtrl = PageController(viewportFraction: 0.90);
  final int _promoPage = 0;
  String _selectedMenu = 'restaurantes'; // 'restaurantes', 'favor', 'hoteles'

  @override
  void initState() {
    super.initState();
    _initScreen();
  }

  // Carga perfil primero, luego verifica ubicación
  Future<void> _initScreen() async {
    await _loadClientProfile();
    // Si no tiene ubicación, mostrar el popup obligatorio
    if (mounted && (_userLat == null || _userLng == null)) {
      setState(() => _loading = false);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showForceLocationDialog();
      });
    } else {
      _loadRestaurants();
      _loadCategories();
    }
    _loadPromos();
  }

  /// Muestra el popup de ubicación que NO se puede cerrar sin poner dirección
  Future<void> _showForceLocationDialog() async {
    if (!mounted) return;
    final cartService = Provider.of<CartService>(context, listen: false);
    final result = await DeliveryLocationDialog.show(
      context,
      LocationDialogMode.login,
      initialAddress: cartService.address,
      initialLat: cartService.userLat,
      initialLng: cartService.userLng,
    );
    if (result != null && mounted) {
      cartService.setAddress(
        result['address'],
        lat: result['lat'],
        lng: result['lng'],
      );
      _loadClientProfile();
    } else if (mounted && (_userLat == null || _userLng == null)) {
      // Si sigue sin ubicación (no debería pasar), volver a mostrar
      _showForceLocationDialog();
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _promoCtrl.dispose();
    super.dispose();
  }

  // ── Data loading ───────────────────────────────────────────────────────────
  Future<void> _loadClientProfile() async {
    try {
      final data = await ApiService.get('/auth/clients/me');
      if (mounted) {
        final address = data['delivery_address'] ?? '';
        setState(() {
          _deliveryAddress = address;
          _clientName = data['name'] ?? '';
          _profileImageUrl = data['avatar_url'];
          _userLat = data['lat'] != null
              ? double.tryParse(data['lat'].toString())
              : null;
          _userLng = data['lng'] != null
              ? double.tryParse(data['lng'].toString())
              : null;
        });

        // Si tenemos ubicación, recargar restaurantes y categorías para filtrar por cercanía
        if (_userLat != null && _userLng != null) {
          _loadRestaurants();
          _loadCategories();
        }

        // Sincronizar con CartService
        Provider.of<CartService>(
          context,
          listen: false,
        ).setAddress(address, lat: _userLat, lng: _userLng);
      }
    } catch (e) {
      if (e is ApiException && e.statusCode == 401) {
        await ApiService.logout();
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const WelcomeScreen()),
            (route) => false,
          );
        }
      }
    }
  }

  Future<void> _loadPromos() async {
    try {
      String path = '/promotions/public';
      if (_userLat != null && _userLng != null) {
        path += '?lat=$_userLat&lng=$_userLng';
      }
      final list = await ApiService.getList(path);
      if (mounted) {
        setState(() {
          _promos = list
              .map((j) => PromoModel.fromJson(j as Map<String, dynamic>))
              .toList();
        });
        if (_promos.length > 1) _startPromoAutoScroll();
      }
    } catch (_) {}
  }

  void _startPromoAutoScroll() {
    Future.delayed(const Duration(seconds: 4), () {
      if (!mounted || _promos.isEmpty) return;
      final next = (_promoPage + 1) % _promos.length;
      _promoCtrl.animateToPage(
        next,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
      );
      _startPromoAutoScroll();
    });
  }

  String _fixUrl(String? url) {
    if (url == null || url.isEmpty) return '';
    if (url.startsWith('http')) return url;
    return '${ApiService.baseUrl}$url';
  }

  void _onPromoTap(PromoModel p) {
    if (p.restaurantId != null && p.restaurantName != null) {
      // Pasar heroImage vacío para que RestaurantDetailScreen cargue su propia imagen
      // Si hay logo del restaurante, usarlo; si no, el banner; si no, vacío
      final heroImg =
          p.restaurantLogoUrl != null && p.restaurantLogoUrl!.isNotEmpty
          ? _fixUrl(p.restaurantLogoUrl)
          : _fixUrl(p.imageUrl);

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RestaurantDetailScreen(
            id: p.restaurantId.toString(),
            name: p.restaurantName!,
            heroImage: heroImg,
            categories: p.restaurantCategory != null
                ? [p.restaurantCategory!]
                : [],
            rating: p.restaurantRating ?? 5,
            minTime: p.restaurantMinTime ?? 20,
            maxTime: p.restaurantMaxTime ?? 40,
            restLat: p.restaurantLat,
            restLng: p.restaurantLng,
          ),
        ),
      );
    }
  }

  Future<void> _loadCategories() async {
    try {
      String path = '/restaurants/categories';
      if (_userLat != null && _userLng != null) {
        path += '?lat=$_userLat&lng=$_userLng';
      }
      final list = await ApiService.getList(path);
      if (mounted) {
        setState(() {
          // Asegurar que 'Todos' esté primero y limpiar duplicados si los hay
          final unique = list.map((e) => e.toString()).toSet().toList();
          _categories = ['Todos', ...unique];
        });
      }
    } catch (_) {}
  }

  Future<void> _loadRestaurants() async {
    // Si no hay ubicación del cliente, NO cargamos restaurantes
    if (_userLat == null || _userLng == null) {
      setState(() {
        _loading = false;
        _restaurants = [];
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      String path = '/restaurants/nearby?lat=$_userLat&lng=$_userLng';

      // Lógica de filtrado por menú y categoría
      if (_selectedMenu == 'hoteles') {
        // En Hoteles, si es 'Todos', forzamos 'HOTEL'. Si es otra, usamos esa.
        String catToFetch = _selectedCategory == 'Todos'
            ? 'HOTEL'
            : _selectedCategory;
        path += '&category=${Uri.encodeComponent(catToFetch)}';
      } else {
        // En Restaurantes, si no es 'Todos', filtramos.
        if (_selectedCategory != 'Todos') {
          path += '&category=${Uri.encodeComponent(_selectedCategory)}';
        }
      }

      final list = await ApiService.getList(path);
      setState(() {
        _restaurants = list
            .map((j) => RestaurantModel.fromJson(j as Map<String, dynamic>))
            .toList();
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  // ── Address dialog ─────────────────────────────────────────────────────────
  Future<void> _changeAddress() async {
    final cartService = Provider.of<CartService>(context, listen: false);
    final result = await DeliveryLocationDialog.show(
      context,
      LocationDialogMode.login,
      initialAddress: cartService.address,
      initialLat: cartService.userLat,
      initialLng: cartService.userLng,
    );
    if (result != null && mounted) {
      cartService.setAddress(
        result['address'],
        lat: result['lat'],
        lng: result['lng'],
      );
      _loadRestaurants();
    }
  }

  // ── Filtered list ──────────────────────────────────────────────────────────
  List<RestaurantModel> get _filtered {
    final query = _searchQuery.toLowerCase().trim();
    final filtered = _restaurants.where((r) {
      // 1. Filtrar por tipo de servicio (Restaurantes vs Hoteles)
      final isHotel =
          r.categories.any((c) => c.toUpperCase() == 'HOTEL') ||
          r.name.toUpperCase().contains('HOTEL');

      if (_selectedMenu == 'hoteles') {
        if (!isHotel) return false;
      } else if (_selectedMenu == 'restaurantes') {
        if (isHotel) return false;
      }

      // 2. Búsqueda inteligente: Nombre, Categorías o Dirección
      final matchesSearch =
          query.isEmpty ||
          r.name.toLowerCase().contains(query) ||
          r.categories.any((c) => c.toLowerCase().contains(query)) ||
          r.address.toLowerCase().contains(query);

      return matchesSearch;
    }).toList();

    // Ordenar: abiertos primero, cerrados al final
    filtered.sort((a, b) {
      if (a.isOpen && !b.isOpen) return -1;
      if (!a.isOpen && b.isOpen) return 1;
      return 0;
    });

    return filtered;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: _selectedIndex == 0 ? _buildHome() : const OrdersScreen(),
      floatingActionButton: Consumer<CartService>(
        builder: (ctx, cart, _) => Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: _red.withValues(alpha: 0.3),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: FloatingActionButton(
            onPressed: () {
              if (cart.items.isNotEmpty) {
                Navigator.push(
                  ctx,
                  MaterialPageRoute(
                    builder: (_) => CartScreen(
                      cartItems: cart.items,
                      restaurantName:
                          cart.currentRestaurantName ?? 'Restaurante',
                      initialAddress: _deliveryAddress,
                    ),
                  ),
                );
              } else {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('El carrito está vacío')),
                );
              }
            },
            backgroundColor: _red,
            shape: CircleBorder(
              side: BorderSide(
                color: Colors.white.withValues(alpha: 0.2),
                width: 2,
              ),
            ),
            elevation: 0,
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                const Icon(
                  Icons.shopping_bag_rounded,
                  color: Colors.black87,
                  size: 28,
                ),
                if (cart.totalItems > 0)
                  Positioned(
                    top: -8,
                    right: -8,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: _red, width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: Text(
                        '${cart.totalItems}',
                        style: GoogleFonts.poppins(
                          color: _red,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: BottomAppBar(
          color: Colors.white,
          elevation: 0,
          notchMargin: 10,
          shape: const CircularNotchedRectangle(),
          child: SizedBox(
            height: 65,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Expanded(
                  child: NavItem(
                    icon: Icons.grid_view_rounded,
                    label: 'Inicio',
                    index: 0,
                    isSelected: _selectedIndex == 0,
                    onTap: () => setState(() => _selectedIndex = 0),
                  ),
                ),
                const SizedBox(width: 60), // Espacio para el FAB
                Expanded(
                  child: NavItem(
                    icon: Icons.receipt_long_rounded,
                    label: 'Pedidos',
                    index: 1,
                    isSelected: _selectedIndex == 1,
                    onTap: () => setState(() => _selectedIndex = 1),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Home Body
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildHome() {
    // Iniciales del cliente para el avatar (limpio de espacios y empty strings)
    final initials = _clientName.isNotEmpty
        ? _clientName
              .trim()
              .split(' ')
              .where((s) => s.isNotEmpty)
              .take(2)
              .map((w) => w[0])
              .join()
              .toUpperCase()
        : '?';

    return SafeArea(
      child: RefreshIndicator(
        color: _red,
        onRefresh: () async {
          if (_selectedMenu == 'restaurantes') {
            await _loadRestaurants();
          }
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            // ── Header ────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Pakiip 🍽️',
                            style: GoogleFonts.poppins(
                              color: _red,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ProfileScreen(),
                            ),
                          ),
                          child: Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: _red,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: _red.withValues(alpha: 0.35),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Center(
                              child:
                                  (_profileImageUrl != null &&
                                      _profileImageUrl!.isNotEmpty)
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(21),
                                      child: Image.network(
                                        _profileImageUrl!.startsWith('http')
                                            ? _profileImageUrl!
                                            : '${ApiService.baseUrl}${_profileImageUrl!}',
                                        width: 42,
                                        height: 42,
                                        fit: BoxFit.cover,
                                        errorBuilder: (ctx, _, _) => Text(
                                          initials,
                                          style: GoogleFonts.poppins(
                                            color: Colors.black87,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                    )
                                  : Text(
                                      initials,
                                      style: GoogleFonts.poppins(
                                        color: Colors.black87,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Tarjeta de dirección de entrega
                    GestureDetector(
                      onTap: _changeAddress,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.black.withValues(alpha: 0.05),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.02),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.location_on,
                              color: _red,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Entregar en',
                                    style: GoogleFonts.poppins(
                                      color: Colors.black45,
                                      fontSize: 11,
                                    ),
                                  ),
                                  Text(
                                    _deliveryAddress.isNotEmpty
                                        ? _deliveryAddress
                                        : 'Toca para agregar tu dirección',
                                    style: GoogleFonts.poppins(
                                      color: _deliveryAddress.isNotEmpty
                                          ? Colors.black87
                                          : Colors.black45,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.keyboard_arrow_down,
                              color: Colors.black45,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Buscador ───────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Container(
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(25),
                    border: Border.all(
                      color: Colors.black.withValues(alpha: 0.05),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchCtrl,
                    style: GoogleFonts.poppins(
                      color: Colors.black87,
                      fontSize: 14,
                    ),
                    onChanged: (v) => setState(() => _searchQuery = v),
                    decoration: InputDecoration(
                      hintText: '¿Qué se te antoja hoy?',
                      hintStyle: GoogleFonts.poppins(
                        color: Colors.black38,
                        fontSize: 13,
                      ),
                      prefixIcon: const Icon(
                        Icons.search,
                        color: Colors.black38,
                      ),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(
                                Icons.close,
                                color: Colors.black38,
                              ),
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ),
            ),

            // ── Banners promocionales ───────────────────────────────────
            if (_promos.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: PromoSlider(
                    promos: _promos,
                    controller: _promoCtrl,
                    currentPage: _promoPage,
                    onPromoTap: _onPromoTap,
                  ),
                ),
              ),

            // ── Main Service Cards ─────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                child: Row(
                  children: [
                    ServiceCard(
                      label: 'Restaurantes',
                      icon: Icons.restaurant_rounded,
                      isSelected: _selectedMenu == 'restaurantes',
                      onTap: () {
                        setState(() {
                          _selectedMenu = 'restaurantes';
                          _selectedCategory = 'Todos';
                        });
                        _loadRestaurants();
                      },
                    ),
                    const SizedBox(width: 12),
                    ServiceCard(
                      label: 'Pakiip Favor',
                      icon: Icons.delivery_dining_rounded,
                      isSelected: _selectedMenu == 'favor',
                      onTap: () => setState(() => _selectedMenu = 'favor'),
                    ),
                    const SizedBox(width: 12),
                    ServiceCard(
                      label: 'Reserva Hoteles',
                      icon: Icons.bed_rounded,
                      isSelected: _selectedMenu == 'hoteles',
                      onTap: () {
                        setState(() {
                          _selectedMenu = 'hoteles';
                          _selectedCategory = 'Todos';
                        });
                        _loadRestaurants();
                      },
                    ),
                  ],
                ),
              ),
            ),
            if (_selectedMenu == 'restaurantes' || _selectedMenu == 'hoteles')
              ..._buildBusinessList(),
            if (_selectedMenu == 'favor') ..._buildFavorView(),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Helper Views
  // ─────────────────────────────────────────────────────────────────────────────
  List<Widget> _buildBusinessList() {
    final list = _filtered;

    return [
      // ── Categorías ──────────────────────────────────────────────
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Categorías',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 16),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _categories
                      .where((c) {
                        if (_selectedMenu == 'restaurantes') {
                          return c.toUpperCase() != 'HOTEL';
                        }
                        if (_selectedMenu == 'hoteles') {
                          return c.toUpperCase() == 'HOTEL' || c == 'Todos';
                        }
                        return true;
                      })
                      .map((cat) {
                        final sel = _selectedCategory == cat;

                        // Mapeo selectivo de iconos
                        IconData icon;
                        switch (cat.toUpperCase()) {
                          case 'TODOS':
                            icon = Icons.grid_view_rounded;
                            break;
                          case 'PIZZAS':
                            icon = Icons.local_pizza_rounded;
                            break;
                          case 'HAMBURGUESAS':
                            icon = Icons.lunch_dining_rounded;
                            break;
                          case 'CHIFAS':
                            icon = Icons.rice_bowl_rounded;
                            break;
                          case 'POLLOS':
                            icon = Icons.kebab_dining_rounded;
                            break;
                          case 'MARISCOS':
                            icon = Icons.set_meal_rounded;
                            break;
                          case 'SALUDABLES':
                            icon = Icons.eco_rounded;
                            break;
                          case 'HOTEL':
                            icon = Icons.hotel_rounded;
                            break;
                          default:
                            icon = Icons.restaurant_rounded;
                        }

                        return Padding(
                          padding: const EdgeInsets.only(right: 16),
                          child: GestureDetector(
                            onTap: () {
                              if (_selectedCategory != cat) {
                                setState(() => _selectedCategory = cat);
                                _loadRestaurants();
                              }
                            },
                            child: SizedBox(
                              width: 70,
                              child: Column(
                                children: [
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    width: 60,
                                    height: 60,
                                    decoration: BoxDecoration(
                                      color: sel ? Colors.white : _red,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: _red,
                                        width: sel ? 2 : 0,
                                      ),
                                      boxShadow: [
                                        // Efecto 3D
                                        BoxShadow(
                                          color: Colors.black.withValues(
                                            alpha: 0.1,
                                          ),
                                          offset: const Offset(0, 3),
                                          blurRadius: 0,
                                        ),
                                        BoxShadow(
                                          color: Colors.black.withValues(
                                            alpha: 0.08,
                                          ),
                                          blurRadius: 8,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: Icon(
                                      icon,
                                      color: sel ? _red : Colors.white,
                                      size: 28,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    cat,
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.poppins(
                                      color: sel ? _red : Colors.black54,
                                      fontSize: 11,
                                      fontWeight: sel
                                          ? FontWeight.bold
                                          : FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      })
                      .toList(),
                ),
              ),
            ],
          ),
        ),
      ),

      // ── Título lista ───────────────────────────────────────────
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
          child: Row(
            children: [
              Text(
                _selectedMenu == 'hoteles'
                    ? 'Hoteles disponibles'
                    : 'Restaurantes disponibles',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                _selectedMenu == 'hoteles'
                    ? Icons.hotel_rounded
                    : Icons.local_fire_department,
                color: _selectedMenu == 'hoteles' ? Colors.blue : Colors.orange,
                size: 20,
              ),
            ],
          ),
        ),
      ),

      // ── Contenido principal ─────────────────────────────────────
      if (_loading)
        const SliverFillRemaining(
          child: Center(child: CircularProgressIndicator(color: _red)),
        )
      else if (_error != null)
        SliverFillRemaining(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.wifi_off, color: Colors.black12, size: 56),
                const SizedBox(height: 16),
                Text(
                  'No se pudo conectar al servidor',
                  style: GoogleFonts.poppins(color: Colors.black54),
                ),
                const SizedBox(height: 16),
                ElevatedBoxButton(
                  onPressed: _loadRestaurants,
                  label: 'Reintentar',
                ),
              ],
            ),
          ),
        )
      else if (_userLat == null || _userLng == null)
        SliverFillRemaining(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: _red.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.location_off_rounded,
                    color: _red,
                    size: 56,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  '¿Dónde te entregamos?',
                  style: GoogleFonts.poppins(
                    color: Colors.black87,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    'Necesitas configurar tu ubicación para cargar las opciones disponibles.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      color: Colors.black45,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedBoxButton(
                  onPressed: _showForceLocationDialog,
                  label: 'Poner mi ubicación',
                  icon: Icons.add_location_alt_rounded,
                ),
              ],
            ),
          ),
        )
      else if (list.isEmpty)
        SliverFillRemaining(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.storefront_outlined,
                  color: Colors.black12,
                  size: 56,
                ),
                const SizedBox(height: 16),
                Text(
                  _searchQuery.isNotEmpty
                      ? 'Sin resultados para "$_searchQuery"'
                      : _selectedMenu == 'hoteles'
                      ? 'No hay hoteles disponibles'
                      : 'No hay restaurantes en tu zona',
                  style: GoogleFonts.poppins(color: Colors.black54),
                ),
              ],
            ),
          ),
        )
      else ...[
        // DISEÑO DIVERSIFICADO: Solo si la categoría es 'Todos' y no hay búsqueda
        if (_selectedCategory == 'Todos' && _searchQuery.isEmpty) ...[
          // 1. Carrusel de Recomendados
          if (list.isNotEmpty)
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Recomendados ✨',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: 220,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: list.take(5).length,
                      itemBuilder: (ctx, i) => CarouselRestaurantCard(
                        item: list[i],
                        onTap: () => _openDetail(ctx, list[i]),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // 2. Tarjetas Pequeñas (Lo más popular) - Solo si hay más de 5
          if (list.length > 5) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                child: Text(
                  'Lo más popular 🔥',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 0.85,
                ),
                delegate: SliverChildBuilderDelegate((ctx, i) {
                  final item = list.skip(5).toList()[i];
                  return SmallRestaurantCard(
                    item: item,
                    onTap: () => _openDetail(ctx, item),
                  );
                }, childCount: list.skip(5).take(4).length),
              ),
            ),
          ],

          // 3. Lista Principal (El resto)
          if (list.length > (list.length > 5 ? 9 : 5))
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                child: Text(
                  'Todos los locales',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
            ),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (ctx, i) {
                  // Si hay más de 5, empezamos después de los populares (skip 9)
                  // Si hay menos de 5, empezamos después de los recomendados (skip 5)
                  final skipCount = list.length > 5 ? 9 : 5;
                  final remainingItems = list.skip(skipCount).toList();
                  if (i >= remainingItems.length) return null;
                  final item = remainingItems[i];
                  return RestaurantCard(
                    restaurant: item,
                    onTap: () => _openDetail(ctx, item),
                  );
                },
                childCount: (list.length > (list.length > 5 ? 9 : 5))
                    ? (list.length - (list.length > 5 ? 9 : 5))
                    : 0,
              ),
            ),
          ),
        ] else ...[
          // DISEÑO ESTÁNDAR: Para categorías específicas o búsquedas
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Text(
                _searchQuery.isNotEmpty
                    ? 'Resultados de búsqueda'
                    : 'Categoría: $_selectedCategory',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (ctx, i) => RestaurantCard(
                  restaurant: list[i],
                  onTap: () => _openDetail(ctx, list[i]),
                ),
                childCount: list.length,
              ),
            ),
          ),
        ],
      ],
    ];
  }

  List<Widget> _buildFavorView() {
    return [
      SliverFillRemaining(
        hasScrollBody: false,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const SizedBox(height: 40),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: _card,
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(
                    color: const Color(0xFFFA7516).withValues(alpha: 0.2),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFA7516).withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.delivery_dining_rounded,
                        color: Color(0xFFFA7516),
                        size: 40,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      '¿Necesitas un Pakiip Favor?',
                      style: GoogleFonts.poppins(
                        color: Colors.black87,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Solicita un motorizado personalizado para trámites, recojos o entregas rápidas.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        color: Colors.black54,
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 60,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(
                                0xFFFA7516,
                              ).withValues(alpha: 0.2),
                              blurRadius: 15,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: _showUserFavorSheet,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFA7516),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                              side: BorderSide(
                                color: Colors.white.withValues(alpha: 0.2),
                                width: 1.5,
                              ),
                            ),
                            elevation: 0,
                          ),
                          child: Text(
                            'SOLICITAR MOTORIZADO',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ];
  }

  void _showUserFavorSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => RiderRequestSheet(
        isDark: false,
        rawOrder: {
          'id': '',
          'client': _clientName,
          'total': 0.0,
          'address': _deliveryAddress,
          'phone': '',
        },
        restaurantData: {
          'id': '0',
          'name': 'Mi ubicación',
          'lat': _userLat,
          'lng': _userLng,
        },
      ),
    );
  }

  void _openDetail(BuildContext ctx, RestaurantModel item) {
    Navigator.push(
      ctx,
      MaterialPageRoute(
        builder: (_) => RestaurantDetailScreen(
          id: item.id,
          name: item.name,
          heroImage: item.logoUrl != null
              ? (item.logoUrl!.startsWith('http')
                    ? item.logoUrl!
                    : '${ApiService.baseUrl}${item.logoUrl}')
              : '',
          categories: item.categories,
          rating: item.rating,
          minTime: item.minTime,
          maxTime: item.maxTime,
          isOpen: item.isOpen,
        ),
      ),
    );
  }
}
