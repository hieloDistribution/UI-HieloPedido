import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../providers/order_provider.dart';
import 'widgets/build_avatar_helper.dart';

class ProfileSection extends StatefulWidget {
  const ProfileSection({super.key});

  @override
  State<ProfileSection> createState() => _ProfileSectionState();
}

class _ProfileSectionState extends State<ProfileSection> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _vehicleController;
  late TextEditingController _matriculaController;
  String? _avatarPath;
  bool _isEditing = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    final provider = Provider.of<OrderProvider>(context, listen: false);
    _nameController = TextEditingController(text: provider.currentUserFullName ?? '');
    _emailController = TextEditingController(text: provider.currentUser?.email ?? '');
    _phoneController = TextEditingController(text: provider.currentUserCelular ?? '');
    _vehicleController = TextEditingController(text: provider.currentUser?.tipoVehiculo ?? '');
    _matriculaController = TextEditingController(text: provider.currentUser?.matricula ?? '');
    _avatarPath = provider.currentUserAvatarUrl;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _vehicleController.dispose();
    _matriculaController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
        maxWidth: 500,
        maxHeight: 500,
      );
      if (image != null) {
        setState(() {
          _avatarPath = image.path;
        });
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al seleccionar imagen: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> _saveProfile(OrderProvider provider, bool isRepartidor) async {
    if (!_formKey.currentState!.validate()) return;

    try {
      await provider.updateProfile(
        fullName: _nameController.text.trim(),
        email: _emailController.text.trim(),
        celular: _phoneController.text.trim(),
        avatarUrl: _avatarPath,
        tipoVehiculo: isRepartidor ? _vehicleController.text.trim() : null,
        matricula: isRepartidor ? _matriculaController.text.trim() : null,
      );
      setState(() {
        _isEditing = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Perfil guardado exitosamente.'),
            backgroundColor: Colors.teal,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar perfil: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _showGpsDisableWarning(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
            const SizedBox(width: 8),
            Text(
              'Aviso Importante',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
            ),
          ],
        ),
        content: Text(
          'La aplicación no recomienda desactivar el rastreo GPS. Si desactivas esta opción, tus entregas podrían retrasarse y no recibirás nuevos pedidos automáticos en tu ruta.',
          style: GoogleFonts.outfit(fontSize: 14, color: const Color(0xFF475569)),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F172A),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Entendido', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<OrderProvider>(context);
    final user = provider.currentUser;
    final isRepartidor = provider.userRole == 'repartidor';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'Configuración de Perfil',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            color: const Color(0xFF0F172A),
            fontSize: 18,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (!_isEditing)
            IconButton(
              icon: const HugeIcon(
                icon: HugeIcons.strokeRoundedEdit02,
                color: Color(0xFF0F172A),
                size: 22,
              ),
              onPressed: () => setState(() => _isEditing = true),
            )
          else
            IconButton(
              icon: const HugeIcon(
                icon: HugeIcons.strokeRoundedCancel01,
                color: Colors.redAccent,
                size: 22,
              ),
              onPressed: () {
                setState(() {
                  _isEditing = false;
                  _nameController.text = provider.currentUserFullName ?? '';
                  _emailController.text = user?.email ?? '';
                  _phoneController.text = provider.currentUserCelular ?? '';
                  _vehicleController.text = provider.currentUser?.tipoVehiculo ?? '';
                  _matriculaController.text = provider.currentUser?.matricula ?? '';
                  _avatarPath = provider.currentUserAvatarUrl;
                });
              },
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Avatar Picker
                Center(
                  child: Stack(
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFFF1F5F9),
                          border: Border.all(color: const Color(0xFFE2E8F0), width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 10,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: _avatarPath != null && _avatarPath!.isNotEmpty
                            ? ClipOval(
                                child: _avatarPath!.startsWith('assets/')
                                    ? Image.asset(_avatarPath!, fit: BoxFit.cover)
                                    : _avatarPath!.startsWith('/') || _avatarPath!.contains('cache')
                                        ? Image.file(File(_avatarPath!), fit: BoxFit.cover)
                                        : buildAvatarHelper(null, _avatarPath, radius: 50),
                              )
                            : buildAvatarHelper(
                                provider.currentUserFullName ?? user?.email,
                                null,
                                radius: 50,
                                fontSize: 24,
                              ),
                      ),
                      if (_isEditing)
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: _pickImage,
                            child: const CircleAvatar(
                              radius: 16,
                              backgroundColor: Color(0xFF0F172A),
                              child: Icon(Icons.camera_alt, color: Colors.white, size: 16),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Fields Container
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Role Label
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Rol de Cuenta',
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F172A),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              provider.userRole.toUpperCase(),
                              style: GoogleFonts.outfit(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 32, color: Color(0xFFE2E8F0)),

                      // Name Field
                      Text(
                        'Nombre y Apellido',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _nameController,
                        enabled: _isEditing,
                        style: GoogleFonts.outfit(fontSize: 14, color: const Color(0xFF0F172A)),
                        decoration: InputDecoration(
                          hintText: 'Ej. Juan Pérez',
                          filled: true,
                          fillColor: _isEditing ? Colors.white : const Color(0xFFF1F5F9),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'El nombre es obligatorio';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Email Field
                      Text(
                        'Correo Electrónico',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _emailController,
                        enabled: _isEditing,
                        style: GoogleFonts.outfit(fontSize: 14, color: const Color(0xFF0F172A)),
                        decoration: InputDecoration(
                          hintText: 'Ej. juan@correo.com',
                          filled: true,
                          fillColor: _isEditing ? Colors.white : const Color(0xFFF1F5F9),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'El correo es obligatorio';
                          }
                          if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                            return 'Ingresa un correo válido';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Phone Field
                      Text(
                        'Número de Celular',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _phoneController,
                        enabled: _isEditing,
                        style: GoogleFonts.outfit(fontSize: 14, color: const Color(0xFF0F172A)),
                        decoration: InputDecoration(
                          hintText: 'Ej. 0981123456',
                          filled: true,
                          fillColor: _isEditing ? Colors.white : const Color(0xFFF1F5F9),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                        ),
                      ),

                      if (isRepartidor) ...[
                        const SizedBox(height: 16),
                        // Vehicle Field
                        Text(
                          'Tipo de Vehículo',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _vehicleController,
                          enabled: _isEditing,
                          style: GoogleFonts.outfit(fontSize: 14, color: const Color(0xFF0F172A)),
                          decoration: InputDecoration(
                            hintText: 'Ej. Moto / Camioneta',
                            filled: true,
                            fillColor: _isEditing ? Colors.white : const Color(0xFFF1F5F9),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Matricula Field
                        Text(
                          'Matrícula / Patente',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _matriculaController,
                          enabled: _isEditing,
                          style: GoogleFonts.outfit(fontSize: 14, color: const Color(0xFF0F172A)),
                          decoration: InputDecoration(
                            hintText: 'Ej. 123-ABC',
                            filled: true,
                            fillColor: _isEditing ? Colors.white : const Color(0xFFF1F5F9),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Repartidor-only GPS Section
                if (isRepartidor) ...[
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFFEE2E2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const HugeIcon(
                              icon: HugeIcons.strokeRoundedMapPin,
                              color: Color(0xFFEF4444),
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Uso de Ubicación (GPS)',
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: const Color(0xFF991B1B),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tus coordenadas geográficas se transmiten en segundo plano para rastrear tu ruta activa y asignarte pedidos de forma automática.',
                          style: GoogleFonts.outfit(
                            fontSize: 11.5,
                            color: const Color(0xFF7F1D1D),
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Activar Rastreo GPS',
                              style: GoogleFonts.outfit(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF991B1B),
                              ),
                            ),
                            Switch(
                              value: provider.isGpsReportingEnabled,
                              activeColor: const Color(0xFFEF4444),
                              onChanged: (val) {
                                provider.toggleGpsReporting(val);
                                if (!val) {
                                  _showGpsDisableWarning(context);
                                }
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // Save button
                if (_isEditing) ...[
                  ElevatedButton(
                    onPressed: () => _saveProfile(provider, isRepartidor),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F172A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      'Guardar Cambios',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // Logout Button
                OutlinedButton.icon(
                  onPressed: () => provider.logout(),
                  icon: const Icon(Icons.logout, color: Colors.redAccent, size: 18),
                  label: Text(
                    'Cerrar Sesión',
                    style: GoogleFonts.outfit(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.redAccent, width: 1),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
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
}
