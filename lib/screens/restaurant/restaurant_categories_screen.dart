import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/api_service.dart';

class _Category {
  final int id;
  String name;
  int productCount;
  _Category({required this.id, required this.name, required this.productCount});

  factory _Category.fromJson(Map<String, dynamic> json) {
    return _Category(
      id: json['id'],
      name: json['name'] ?? '',
      productCount: 0, // El conteo se puede añadir después si se desea
    );
  }
}

class RestaurantCategoriesScreen extends StatefulWidget {
  const RestaurantCategoriesScreen({super.key});

  @override
  State<RestaurantCategoriesScreen> createState() =>
      _RestaurantCategoriesScreenState();
}

class _RestaurantCategoriesScreenState
    extends State<RestaurantCategoriesScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  List<_Category> _categories = [];
  bool _loading = true;

  static const Color _bg = Color(0xFFFFFFFF);
  static const Color _card = Color(0xFFF9FAFB);
  static const Color _red = Color(0xFFFA7516);
  static const Color _border = Color(0xFFE0E0E0);

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    setState(() => _loading = true);
    try {
      final list = await ApiService.getList('/categories');
      setState(() {
        _categories = list
            .map((j) => _Category.fromJson(j as Map<String, dynamic>))
            .toList();
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      _snack('Error al cargar categorías: $e', Colors.red);
    }
  }

  Future<void> _saveOrder() async {
    try {
      final ids = _categories.map((c) => c.id).toList();
      await ApiService.postAuth('/categories/reorder', {'ids': ids});
    } catch (e) {
      _snack('Error al guardar orden: $e', Colors.red);
    }
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.poppins()),
        backgroundColor: color,
      ),
    );
  }

  List<_Category> get _filtered => _query.isEmpty
      ? _categories
      : _categories
            .where((c) => c.name.toLowerCase().contains(_query.toLowerCase()))
            .toList();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ── Add ──────────────────────────────────────────────────────────────────
  void _showAddDialog() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Nueva Categoría',
          style: GoogleFonts.poppins(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: _dialogField(ctrl, 'Nombre de la categoría'),
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
              final name = ctrl.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(ctx);
              try {
                final result = await ApiService.postAuth('/categories', {
                  'name': name,
                });
                setState(() => _categories.add(_Category.fromJson(result)));
                _snack('Categoría añadida', Colors.green);
              } catch (e) {
                _snack('Error al añadir: $e', Colors.red);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Añadir',
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

  void _showEditDialog(_Category cat) {
    final ctrl = TextEditingController(text: cat.name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Editar Categoría',
          style: GoogleFonts.poppins(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: _dialogField(ctrl, 'Nombre de la categoría'),
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
              final name = ctrl.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(ctx);
              try {
                await ApiService.put('/categories/${cat.id}', {'name': name});
                setState(() => cat.name = name);
                _snack('Categoría actualizada', Colors.green);
                _loadCategories(); // Refresh to be safe
              } catch (e) {
                _snack('Error al actualizar: $e', Colors.red);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Guardar',
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

  // ── Delete ────────────────────────────────────────────────────────────────
  void _confirmDelete(_Category cat) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Eliminar categoría',
          style: GoogleFonts.poppins(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          '¿Estás seguro de eliminar "${cat.name}"?\nEsta acción no se puede deshacer.',
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
                await ApiService.delete('/categories/${cat.id}');
                setState(() => _categories.remove(cat));
                _snack('Categoría eliminada', Colors.orange);
              } catch (e) {
                _snack('Error al eliminar: $e', Colors.red);
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

  Widget _dialogField(TextEditingController ctrl, String hint) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: TextField(
        controller: ctrl,
        autofocus: true,
        style: GoogleFonts.poppins(color: Colors.black87, fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.poppins(color: Colors.black26, fontSize: 13),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
          'Editar Categorías',
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
            onPressed: _loadCategories,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: Container(
              decoration: BoxDecoration(
                color: _card,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: _border),
              ),
              child: TextField(
                controller: _searchController,
                style: GoogleFonts.poppins(color: Colors.black87, fontSize: 14),
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: 'Buscar categoría...',
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
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: _red))
                : _filtered.isEmpty
                ? Center(
                    child: Text(
                      'No se encontraron categorías',
                      style: GoogleFonts.poppins(
                        color: Colors.black38,
                        fontSize: 14,
                      ),
                    ),
                  )
                : ReorderableListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    physics: const BouncingScrollPhysics(),
                    buildDefaultDragHandles: false,
                    proxyDecorator: (child, index, animation) {
                      return AnimatedBuilder(
                        animation: animation,
                        builder: (context, child) {
                          return Material(
                            elevation: 0,
                            color: Colors.transparent,
                            child: child,
                          );
                        },
                        child: child,
                      );
                    },
                    itemCount: _filtered.length,
                    onReorder: (oldIndex, newIndex) {
                      if (_query.isNotEmpty) {
                        return; // Deshabilitar reorder si hay búsqueda
                      }
                      setState(() {
                        if (newIndex > oldIndex) newIndex--;
                        final item = _categories.removeAt(oldIndex);
                        _categories.insert(newIndex, item);
                      });
                      _saveOrder();
                    },
                    itemBuilder: (context, index) {
                      final cat = _filtered[index];
                      return _CategoryTile(
                        key: ValueKey(cat.id),
                        index: index,
                        category: cat,
                        onEdit: () => _showEditDialog(cat),
                        onDelete: () => _confirmDelete(cat),
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _showAddDialog,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _red,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: 4,
                  shadowColor: _red.withOpacity(0.4),
                ),
                icon: const Icon(
                  Icons.add_circle_outline,
                  color: Colors.black87,
                  size: 22,
                ),
                label: Text(
                  'Añadir Nueva Categoría',
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
}

class _CategoryTile extends StatelessWidget {
  final int index;
  final _Category category;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  static const Color _card = Color(0xFFF9FAFB);
  static const Color _red = Color(0xFFFA7516);
  static const Color _border = Color(0xFFE0E0E0);

  const _CategoryTile({
    super.key,
    required this.index,
    required this.category,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      key: key,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          ReorderableDragStartListener(
            index: index,
            child: const Icon(Icons.drag_handle, color: Colors.black26),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category.name,
                  style: GoogleFonts.poppins(
                    color: Colors.black87,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  '${category.productCount} productos',
                  style: GoogleFonts.poppins(
                    color: Colors.black38,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.edit_outlined,
              color: Colors.black38,
              size: 20,
            ),
            onPressed: onEdit,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: _red, size: 20),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}






