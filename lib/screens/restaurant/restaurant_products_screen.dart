import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/api_service.dart';
import 'package:pakiip/screens/restaurant/restaurant_add_product_screen.dart';

// ── Model ──────────────────────────────────────────────────────────────────────
class _Product {
  final int id;
  String name;
  String description;
  double price;
  String category;
  String imageUrl;
  bool available;
  List<dynamic> groups;

  _Product({
    required this.id,
    required this.name,
    this.description = '',
    required this.price,
    required this.category,
    this.imageUrl = '',
    this.available = true,
    this.groups = const [],
  });

  factory _Product.fromJson(Map<String, dynamic> j) => _Product(
    id: j['id'] as int,
    name: j['name'] as String,
    description: j['description'] ?? '',
    price: double.tryParse(j['price'].toString()) ?? 0,
    category: j['category'] ?? 'General',
    imageUrl: j['image_url'] ?? '',
    available: j['available'] ?? true,
    groups: j['groups'] is List ? j['groups'] : [],
  );
}

class RestaurantProductsScreen extends StatefulWidget {
  const RestaurantProductsScreen({super.key});

  @override
  State<RestaurantProductsScreen> createState() =>
      _RestaurantProductsScreenState();
}

class _RestaurantProductsScreenState extends State<RestaurantProductsScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  String _selectedCategory = 'Todos';
  bool _loading = true;
  String? _error;

  static const Color _bg = Color(0xFFFFFFFF);
  static const Color _card = Color(0xFFF9FAFB);
  static const Color _red = Color(0xFFFA7516);
  static const Color _border = Color(0xFFE0E0E0);
  static const Color _green = Color(0xFF4CAF50);

  // Categorías que vienen de la DB
  List<String> _userCategories = [];

  List<_Product> _products = [];

  List<String> get _allCategories {
    final fromProducts = _products.map((p) => p.category).toSet();
    final combined = {'General', ..._userCategories, ...fromProducts};
    return ['Todos', ...combined];
  }

  List<_Product> get _filtered {
    return _products.where((p) {
      final matchQ =
          _query.isEmpty || p.name.toLowerCase().contains(_query.toLowerCase());
      final matchCat =
          _selectedCategory == 'Todos' || p.category == _selectedCategory;
      return matchQ && matchCat;
    }).toList();
  }

  // ── Load ──────────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await ApiService.getList('/products/my');
      setState(() {
        _products = list
            .map((j) => _Product.fromJson(j as Map<String, dynamic>))
            .toList();
        _loading = false;
      });

      // Cargar también las categorías creadas por el usuario
      final catList = await ApiService.getList('/categories');
      setState(() {
        _userCategories = catList.map((c) => c['name'] as String).toList();
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ── Toggle available ──────────────────────────────────────────────────────────
  Future<void> _toggleStatus(_Product p) async {
    final newAvail = !p.available;
    setState(() => p.available = newAvail);
    try {
      await ApiService.put('/products/${p.id}', {
        'name': p.name,
        'description': p.description,
        'price': p.price,
        'category': p.category,
        'image_url': p.imageUrl,
        'available': newAvail,
        'groups': p.groups,
      });
    } catch (_) {
      setState(() => p.available = !newAvail); // revert
    }
  }

  // ── Delete ────────────────────────────────────────────────────────────────────
  void _confirmDelete(_Product p) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Eliminar producto',
          style: GoogleFonts.poppins(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          '¿Eliminar "${p.name}"?\nEsta acción no se puede deshacer.',
          style: GoogleFonts.poppins(color: Colors.black54, fontSize: 13),
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
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ApiService.delete('/products/${p.id}');
                setState(() => _products.remove(p));
                _snack('Producto eliminado', Colors.orange);
              } catch (e) {
                _snack('Error: $e', Colors.red);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Eliminar',
              style: GoogleFonts.poppins(
                color: Colors.black87,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Add product ───────────────────────────────────────────────────────────────
  Future<void> _showAddProductSheet() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => RestaurantAddProductScreen(categories: _allCategories),
      ),
    );
    if (result == null) return;
    try {
      final data = await ApiService.postAuth('/products', {
        'name': result['name'],
        'description': result['description'] ?? '',
        'price': result['price'],
        'category': result['category'] ?? 'General',
        'image_url': result['image_url'],
        'groups': result['groups'],
      });
      final newProduct = _Product.fromJson(
        data['product'] as Map<String, dynamic>,
      );
      setState(() => _products.add(newProduct));
      _snack('✅ Producto "${newProduct.name}" creado', _green);
    } catch (e) {
      _snack('Error al crear: $e', Colors.red);
    }
  }

  // ── Edit product ──────────────────────────────────────────────────────────────
  Future<void> _editProduct(_Product p) async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => RestaurantAddProductScreen(
          categories: _allCategories,
          initialName: p.name,
          initialDescription: p.description,
          initialPrice: p.price,
          initialCategory: p.category,
          initialImageUrl: p.imageUrl,
          initialGroups: p.groups,
          editMode: true,
        ),
      ),
    );
    if (result == null) return;
    try {
      await ApiService.put('/products/${p.id}', {
        'name': result['name'],
        'description': result['description'] ?? '',
        'price': result['price'],
        'category': result['category'],
        'image_url': result['image_url'],
        'available': p.available,
        'groups': result['groups'],
      });
      setState(() {
        p.name = result['name'] as String;
        p.description = result['description'] ?? '';
        p.price = (result['price'] ?? 0).toDouble();
        p.category = result['category'] as String;
        p.imageUrl = result['image_url'] ?? '';
        p.groups = result['groups'] ?? [];
      });
      _snack('✅ Producto actualizado', _green);
    } catch (e) {
      _snack('Error al actualizar: $e', Colors.red);
    }
  }

  void _snack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.poppins(color: Colors.white)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: _red),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Gestionar Menú',
          style: GoogleFonts.poppins(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 17,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black45),
            onPressed: _loadProducts,
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFFA7516)),
            )
          : _error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.wifi_off, color: Colors.black26, size: 48),
                  const SizedBox(height: 12),
                  Text(
                    'Error de conexión',
                    style: GoogleFonts.poppins(
                      color: Colors.black38,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: _loadProducts,
                    style: ElevatedButton.styleFrom(backgroundColor: _red),
                    child: Text(
                      'Reintentar',
                      style: GoogleFonts.poppins(color: Colors.white),
                    ),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                // ── Search bar ────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: _card,
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: _border),
                    ),
                    child: TextField(
                      controller: _searchController,
                      style: GoogleFonts.poppins(
                        color: Colors.black87,
                        fontSize: 14,
                      ),
                      onChanged: (v) => setState(() => _query = v),
                      decoration: InputDecoration(
                        hintText: 'Buscar en el menú...',
                        hintStyle: GoogleFonts.poppins(
                          color: Colors.black38,
                          fontSize: 13,
                        ),
                        prefixIcon: const Icon(
                          Icons.search,
                          color: Colors.black38,
                          size: 20,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // ── Header row ────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Text(
                        'TUS PRODUCTOS (${filtered.length})',
                        style: GoogleFonts.poppins(
                          color: _red,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: _showCategoryFilter,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: _card,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: _selectedCategory != 'Todos'
                                  ? _red
                                  : _border,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.filter_list,
                                color: _selectedCategory != 'Todos'
                                    ? _red
                                    : Colors.black26,
                                size: 14,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _selectedCategory == 'Todos'
                                    ? 'Categorías'
                                    : _selectedCategory,
                                style: GoogleFonts.poppins(
                                  color: _selectedCategory != 'Todos'
                                      ? _red
                                      : Colors.black54,
                                  fontSize: 12,
                                  fontWeight: _selectedCategory != 'Todos'
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // ── Product list ──────────────────────────────────────────
                Expanded(
                  child: filtered.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.restaurant_menu,
                                color: Colors.black26,
                                size: 48,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _products.isEmpty
                                    ? 'Aún no tienes productos.\n¡Añade el primer plato!'
                                    : 'No se encontraron productos',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.poppins(
                                  color: Colors.black38,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          physics: const BouncingScrollPhysics(),
                          itemCount: filtered.length,
                          itemBuilder: (_, i) => _ProductCard(
                            product: filtered[i],
                            onEdit: () => _editProduct(filtered[i]),
                            onToggle: () => _toggleStatus(filtered[i]),
                            onDelete: () => _confirmDelete(filtered[i]),
                          ),
                        ),
                ),

                // ── Add button ────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: _showAddProductSheet,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _red,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        elevation: 4,
                        shadowColor: _red.withValues(alpha: 0.4),
                      ),
                      icon: const Icon(
                        Icons.add,
                        color: Colors.black87,
                        size: 22,
                      ),
                      label: Text(
                        'Añadir Producto',
                        style: GoogleFonts.poppins(
                          color: Colors.black87,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  void _showCategoryFilter() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Filtrar por categoría',
              style: GoogleFonts.poppins(
                color: Colors.black87,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 12),
            ..._allCategories.map(
              (cat) => ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  cat,
                  style: GoogleFonts.poppins(color: Colors.black87),
                ),
                trailing: _selectedCategory == cat
                    ? const Icon(
                        Icons.check_circle,
                        color: Color(0xFFFA7516),
                        size: 20,
                      )
                    : null,
                onTap: () {
                  setState(() => _selectedCategory = cat);
                  Navigator.pop(ctx);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Product card ──────────────────────────────────────────────────────────────
class _ProductCard extends StatelessWidget {
  final _Product product;
  final VoidCallback onEdit;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  static const Color _card = Color(0xFFF9FAFB);
  static const Color _red = Color(0xFFFA7516);
  static const Color _border = Color(0xFFE0E0E0);
  static const Color _green = Color(0xFF4CAF50);

  const _ProductCard({
    required this.product,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isAvailable = product.available;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: product.imageUrl.isNotEmpty
                  ? Image.network(
                      product.imageUrl.startsWith('http')
                          ? product.imageUrl
                          : '${ApiService.baseUrl}${product.imageUrl}',
                      width: 88,
                      height: 88,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => _placeholder(),
                    )
                  : _placeholder(),
            ),
            const SizedBox(width: 12),

            // Info + actions
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          product.name,
                          style: GoogleFonts.poppins(
                            color: Colors.black87,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'S/. ${product.price.toStringAsFixed(2)}',
                        style: GoogleFonts.poppins(
                          color: _red,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    product.category,
                    style: GoogleFonts.poppins(
                      color: Colors.black38,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: isAvailable ? _green : _red,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isAvailable ? 'DISPONIBLE' : 'AGOTADO',
                        style: GoogleFonts.poppins(
                          color: isAvailable ? _green : _red,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _ActionButton(
                        icon: Icons.edit_outlined,
                        label: 'Editar',
                        onTap: onEdit,
                      ),
                      const SizedBox(width: 8),
                      _ActionButton(
                        icon: isAvailable
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        label: isAvailable ? 'Pausar' : 'Activar',
                        isHighlighted: !isAvailable,
                        onTap: onToggle,
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: onDelete,
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: _red.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Icon(
                            Icons.delete_outline,
                            color: _red,
                            size: 17,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() => Container(
    width: 88,
    height: 88,
    decoration: BoxDecoration(
      color: const Color(0xFF2A1515),
      borderRadius: BorderRadius.circular(12),
    ),
    child: const Icon(Icons.fastfood, color: Colors.black26, size: 32),
  );
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isHighlighted;

  static const Color _red = Color(0xFFFA7516);
  static const Color _btnBg = Color(0xFF2A1515);

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isHighlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isHighlighted ? _red : _btnBg,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 14),
            const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
