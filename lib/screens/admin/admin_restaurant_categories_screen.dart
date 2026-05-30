import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/api_service.dart';

class AdminRestaurantCategoriesScreen extends StatefulWidget {
  const AdminRestaurantCategoriesScreen({super.key});

  @override
  State<AdminRestaurantCategoriesScreen> createState() =>
      _AdminRestaurantCategoriesScreenState();
}

class _AdminRestaurantCategoriesScreenState
    extends State<AdminRestaurantCategoriesScreen> {
  static const Color _bg = Color(0xFFFFFFFF);
  static const Color _red = Color(0xFFFA7516);

  bool _loading = true;
  List<Map<String, dynamic>> _categories = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await ApiService.getList('/restaurant-categories');
      setState(() {
        _categories = data.cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      _snack('Error: $e', Colors.red);
    }
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.poppins(color: Colors.white)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _delete(int id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text(
          'Eliminar Categoría',
          style: GoogleFonts.poppins(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          '¿Seguro que deseas eliminarla? Esto afectará a los restaurantes vinculados.',
          style: GoogleFonts.poppins(color: Colors.black54),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancelar',
              style: GoogleFonts.poppins(color: Colors.black38),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: _red),
            child: Text('Eliminar', style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await ApiService.delete('/restaurant-categories/$id');
      _load();
      _snack('Categoría eliminada', Colors.orange);
    } catch (e) {
      _snack('Error: $e', Colors.red);
    }
  }

  void _openForm({Map<String, dynamic>? cat}) {
    final isEdit = cat != null;
    final nameCtrl = TextEditingController(text: cat?['name'] ?? '');
    bool saving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Container(
            decoration: const BoxDecoration(
              color: Color(0xFFFFFFFF),
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Colors.black54,
                        size: 20,
                      ),
                    ),
                    Text(
                      isEdit ? 'Editar Categoría' : 'Nueva Categoría',
                      style: GoogleFonts.poppins(
                        color: Colors.black87,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(width: 48), // Spacer for balance
                  ],
                ),
                const SizedBox(height: 20),
                _field(
                  ctrl: nameCtrl,
                  label: 'Nombre de la categoría',
                  icon: Icons.category_rounded,
                ),
                const SizedBox(height: 12),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: saving
                        ? null
                        : () async {
                            if (nameCtrl.text.isEmpty) return;
                            setSheet(() => saving = true);
                            try {
                              if (isEdit) {
                                await ApiService.put(
                                  '/restaurant-categories/${cat['id']}',
                                  {'name': nameCtrl.text.trim()},
                                );
                              } else {
                                await ApiService.postAuth(
                                  '/restaurant-categories',
                                  {'name': nameCtrl.text.trim()},
                                );
                              }
                              _load();
                              Navigator.pop(ctx);
                              _snack(
                                isEdit ? 'Actualizada' : 'Creada',
                                Colors.green,
                              );
                            } catch (e) {
                              setSheet(() => saving = false);
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
                      saving ? 'Guardando...' : 'Guardar',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController ctrl,
    required String label,
    required IconData icon,
  }) {
    return TextField(
      controller: ctrl,
      style: GoogleFonts.poppins(color: Colors.black87),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.poppins(color: Colors.black38),
        prefixIcon: Icon(icon, color: _red),
        filled: true,
        fillColor: Colors.black.withValues(alpha: 0.05),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(
          'Categorías de Restaurantes',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(),
        backgroundColor: _red,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _red))
          : _categories.isEmpty
          ? Center(
              child: Text(
                'No hay categorías creadas',
                style: GoogleFonts.poppins(color: Colors.black38),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _categories.length,
              itemBuilder: (ctx, i) {
                final c = _categories[i];
                return Card(
                  color: const Color(0xFFF9FAFB),
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: _red.withValues(alpha: 0.1),
                      child: const Icon(
                        Icons.fastfood_rounded,
                        color: _red,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      c['name'] ?? '',
                      style: GoogleFonts.poppins(
                        color: Colors.black87,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      c['active'] == false ? 'Inactiva' : 'Activa',
                      style: GoogleFonts.poppins(
                        color: Colors.black38,
                        fontSize: 12,
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.edit,
                            color: Colors.black38,
                            size: 20,
                          ),
                          onPressed: () => _openForm(cat: c),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: _red, size: 20),
                          onPressed: () => _delete(c['id']),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}






