import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/api_service.dart';
import '../../widgets/delivery_location_dialog.dart';
import 'package:pakiip/screens/auth/login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();

  String? _serverImageUrl;
  String? _localImagePath;
  bool _isLoading = true;
  bool _isSaving = false;
  String _role = ''; // 'client' | 'restaurant' | 'admin'

  static const Color _red = Color(0xFFFA7516);
  static const Color _dark = Colors.white;
  static const Color _card = Color(0xFFF7F7F7);

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  // ── Load ──────────────────────────────────────────────────────────
  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    try {
      _role = await ApiService.getRole() ?? '';

      final String endpoint = _role == 'client'
          ? '/auth/clients/me'
          : '/restaurants/me';

      final data = await ApiService.get(endpoint);
      setState(() {
        _nameController.text = data['name'] ?? '';
        _phoneController.text = data['phone'] ?? '';
        _emailController.text = data['email'] ?? '';
        _addressController.text =
            data['address'] ?? data['delivery_address'] ?? '';
        _serverImageUrl = _role == 'client'
            ? data['avatar_url']
            : data['logo_url'];
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _snack('Error al cargar perfil: $e', Colors.red);
    }
  }

  // ── Image ──────────────────────────────────────────────────────────
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: _red),
              title: const Text(
                'Cámara',
                style: TextStyle(color: Colors.black87),
              ),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: _red),
              title: const Text(
                'Galería',
                style: TextStyle(color: Colors.black87),
              ),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source != null) {
      final pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 75,
      );
      if (pickedFile != null) {
        setState(() => _localImagePath = pickedFile.path);
        _uploadImage(pickedFile.path);
      }
    }
  }

  Future<void> _uploadImage(String path) async {
    setState(() => _isSaving = true);
    try {
      // Usar el mismo endpoint de upload, el campo se adapta según el rol
      final endpoint = _role == 'client'
          ? '/upload/restaurant/hero' // reutilizamos el mismo endpoint genérico
          : '/upload/restaurant/hero';
      final res = await ApiService.uploadFile(endpoint, path);
      setState(() {
        _serverImageUrl = res['imageUrl'];
        _isSaving = false;
      });
      _snack('✓ Foto de perfil actualizada', Colors.green);
    } catch (e) {
      setState(() => _isSaving = false);
      _snack('Error al subir imagen: $e', Colors.red);
    }
  }

  // ── Save ───────────────────────────────────────────────────────────
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      if (_role == 'client') {
        await ApiService.put('/auth/clients/me', {
          'name': _nameController.text.trim(),
          'phone': _phoneController.text.trim(),
          'delivery_address': _addressController.text.trim(),
          'avatar_url': _serverImageUrl,
        });
      } else {
        await ApiService.put('/restaurants/me', {
          'name': _nameController.text.trim(),
          'phone': _phoneController.text.trim(),
          'address': _addressController.text.trim(),
          'logo_url': _serverImageUrl,
        });
      }
      setState(() => _isSaving = false);
      _snack('✓ Perfil guardado', _red);
    } catch (e) {
      setState(() => _isSaving = false);
      _snack('Error al guardar: $e', Colors.red);
    }
  }

  // ── Direccion Picker ──────────────────────────────────────────────
  Future<void> _showAddressPicker() async {
    final result = await DeliveryLocationDialog.show(
      context,
      LocationDialogMode.register,
      initialAddress: _addressController.text,
    );
    if (result != null) {
      setState(() => _addressController.text = result['address']);
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────
  void _snack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.poppins()),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final name = _nameController.text;
    final initials = name.isNotEmpty
        ? name
              .trim()
              .split(' ')
              .where((s) => s.isNotEmpty)
              .take(2)
              .map((w) => w[0])
              .join()
              .toUpperCase()
        : '?';

    final fullImageUrl = _serverImageUrl != null && _serverImageUrl!.isNotEmpty
        ? (_serverImageUrl!.startsWith('http')
              ? _serverImageUrl
              : '${ApiService.baseUrl}$_serverImageUrl')
        : null;

    final bool isClient = _role == 'client';

    return Scaffold(
      backgroundColor: _dark,
      appBar: AppBar(
        backgroundColor: _dark,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: Text(
          'Mi Perfil',
          style: GoogleFonts.poppins(
            color: Colors.black87,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.black26),
            onPressed: _confirmLogout,
            tooltip: 'Cerrar sesión',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _red))
          : SingleChildScrollView(
              child: Column(
                children: [
                  // ── Avatar ─────────────────────────────────────────
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    decoration: const BoxDecoration(
                      color: _card,
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(32),
                        bottomRight: Radius.circular(32),
                      ),
                    ),
                    child: Column(
                      children: [
                        GestureDetector(
                          onTap: _isSaving ? null : _pickImage,
                          child: Stack(
                            children: [
                              Container(
                                width: 130,
                                height: 130,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: _red, width: 3),
                                  color: _red.withValues(alpha: 0.1),
                                ),
                                child: ClipOval(
                                  child: _localImagePath != null
                                      ? (kIsWeb
                                            ? Image.network(
                                                _localImagePath!,
                                                fit: BoxFit.cover,
                                              )
                                            : Image.file(
                                                File(_localImagePath!),
                                                fit: BoxFit.cover,
                                              ))
                                      : (fullImageUrl != null
                                            ? Image.network(
                                                fullImageUrl,
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, _, _) =>
                                                    _buildInitialsAvatar(
                                                      initials,
                                                    ),
                                              )
                                            : _buildInitialsAvatar(initials)),
                                ),
                              ),
                              if (_isSaving)
                                const Positioned.fill(
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      color: Colors.black87,
                                    ),
                                  ),
                                ),
                              Positioned(
                                bottom: 4,
                                right: 4,
                                child: Container(
                                  padding: const EdgeInsets.all(7),
                                  decoration: const BoxDecoration(
                                    color: _red,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.camera_alt,
                                    color: Colors.black87,
                                    size: 16,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          _nameController.text.isNotEmpty
                              ? _nameController.text
                              : 'Tu nombre',
                          style: GoogleFonts.poppins(
                            color: Colors.black87,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── Formulario ─────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          _buildField(
                            controller: _nameController,
                            label: isClient
                                ? 'Nombre completo'
                                : 'Nombre del Local',
                            icon: isClient
                                ? Icons.person_outline
                                : Icons.store_outlined,
                            validator: (v) =>
                                v == null || v.isEmpty ? 'Requerido' : null,
                          ),
                          const SizedBox(height: 14),
                          _buildField(
                            controller: _phoneController,
                            label: 'Teléfono',
                            icon: Icons.phone_android,
                            keyboardType: TextInputType.phone,
                          ),
                          const SizedBox(height: 14),
                          _buildField(
                            controller: _addressController,
                            label: isClient
                                ? 'Dirección de entrega'
                                : 'Dirección del local',
                            icon: Icons.location_on_outlined,
                            maxLines: 2,
                            readOnly: true,
                            onTap: isClient ? _showAddressPicker : null,
                          ),
                          const SizedBox(height: 14),
                          _buildField(
                            controller: _emailController,
                            label: 'Correo (no editable)',
                            icon: Icons.email_outlined,
                            enabled: false,
                          ),
                          const SizedBox(height: 30),

                          // ── Guardar ───────────────────────────────
                          SizedBox(
                            width: double.infinity,
                            height: 54,
                            child: ElevatedButton(
                              onPressed: _isSaving ? null : _save,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _red,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(28),
                                ),
                              ),
                              child: _isSaving
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        color: Colors.black87,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Text(
                                      'Guardar Cambios',
                                      style: GoogleFonts.poppins(
                                        color: Colors.black87,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 14),

                          const SizedBox(height: 20),
                          _buildSupportCard(),
                          const SizedBox(height: 14),

                          // ── Cerrar sesión ─────────────────────────
                          SizedBox(
                            width: double.infinity,
                            height: 54,
                            child: OutlinedButton.icon(
                              onPressed: _confirmLogout,
                              icon: const Icon(
                                Icons.logout,
                                color: Colors.redAccent,
                                size: 20,
                              ),
                              label: Text(
                                'Cerrar sesión',
                                style: GoogleFonts.poppins(
                                  color: Colors.redAccent,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.redAccent),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(28),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 30),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSupportCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.help_center_rounded, color: _red, size: 24),
              const SizedBox(width: 12),
              Text(
                'Soporte Técnico',
                style: GoogleFonts.poppins(
                  color: Colors.black87,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _supportItem(Icons.phone_rounded, 'WhatsApp', '+51 910 318 809'),
          const SizedBox(height: 12),
          _supportItem(
            Icons.email_outlined,
            'Correo',
            'pakiipglobal@gmail.com',
          ),
        ],
      ),
    );
  }

  Widget _supportItem(IconData icon, String title, String value) {
    return Row(
      children: [
        Icon(icon, color: Colors.black26, size: 18),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: GoogleFonts.poppins(color: Colors.black38, fontSize: 11),
            ),
            Text(
              value,
              style: GoogleFonts.poppins(
                color: Colors.black87,
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInitialsAvatar(String initials) {
    return Center(
      child: Text(
        initials,
        style: GoogleFonts.poppins(
          color: Colors.black87,
          fontWeight: FontWeight.bold,
          fontSize: 42,
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    int maxLines = 1,
    bool enabled = true,
    bool readOnly = false,
    VoidCallback? onTap,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      enabled: enabled,
      readOnly: readOnly,
      onTap: onTap,
      style: GoogleFonts.poppins(
        color: enabled ? Colors.black87 : Colors.black26,
        fontSize: 14,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.poppins(color: Colors.black38, fontSize: 12),
        prefixIcon: Icon(icon, color: _red, size: 20),
        filled: true,
        fillColor: _card,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.black12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: _red, width: 1.5),
        ),
      ),
    );
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Cerrar sesión',
          style: GoogleFonts.poppins(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          '¿Deseas salir de tu cuenta?',
          style: GoogleFonts.poppins(color: Colors.black54),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancelar',
              style: GoogleFonts.poppins(color: Colors.black38),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              await ApiService.logout();
              if (mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (r) => false,
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: Text(
              'Salir',
              style: GoogleFonts.poppins(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
