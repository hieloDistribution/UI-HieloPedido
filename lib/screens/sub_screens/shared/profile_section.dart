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

  static const Color slate50 = Color(0xFFF8FAFC);
  static const Color slate100 = Color(0xFFF1F5F9);
  static const Color slate200 = Color(0xFFE2E8F0);
  static const Color slate400 = Color(0xFF94A3B8);
  static const Color slate700 = Color(0xFF475569);
  static const Color slate900 = Color(0xFF0F172A);

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
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: slate900),
            ),
          ],
        ),
        content: Text(
          'La aplicación no recomienda desactivar el rastreo GPS. Si desactivas esta opción, tus entregas podrían retrasarse y no recibirás nuevos pedidos automáticos en tu ruta.',
          style: GoogleFonts.outfit(fontSize: 14, color: slate700),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: slate900,
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
      backgroundColor: slate50,
      appBar: AppBar(
        title: Text(
          'Profile',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            color: slate900,
            fontSize: 18,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF0F172A), size: 18),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        actions: [
          IconButton(
            icon: HugeIcon(
              icon: _isEditing ? HugeIcons.strokeRoundedCancel01 : HugeIcons.strokeRoundedSettings01,
              color: _isEditing ? Colors.redAccent : slate900,
              size: 22,
            ),
            onPressed: () {
              setState(() {
                if (_isEditing) {
                  // Cancel and restore
                  _isEditing = false;
                  _nameController.text = provider.currentUserFullName ?? '';
                  _emailController.text = user?.email ?? '';
                  _phoneController.text = provider.currentUserCelular ?? '';
                  _vehicleController.text = provider.currentUser?.tipoVehiculo ?? '';
                  _matriculaController.text = provider.currentUser?.matricula ?? '';
                  _avatarPath = provider.currentUserAvatarUrl;
                } else {
                  _isEditing = true;
                }
              });
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Avatar Picker
                Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 110,
                        height: 110,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.06),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: _avatarPath != null && _avatarPath!.isNotEmpty
                            ? ClipOval(
                                child: _avatarPath!.startsWith('assets/')
                                    ? Image.asset(_avatarPath!, fit: BoxFit.cover)
                                    : _avatarPath!.startsWith('/') || _avatarPath!.contains('cache')
                                        ? Image.file(File(_avatarPath!), fit: BoxFit.cover)
                                        : buildAvatarHelper(null, _avatarPath, radius: 55),
                              )
                            : buildAvatarHelper(
                                provider.currentUserFullName ?? user?.email,
                                null,
                                radius: 55,
                                fontSize: 28,
                              ),
                      ),
                      Positioned(
                        bottom: 2,
                        right: 2,
                        child: GestureDetector(
                          onTap: _pickImage,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.12),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const HugeIcon(
                              icon: HugeIcons.strokeRoundedPencilEdit02,
                              color: Color(0xFF0F172A),
                              size: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    provider.currentUserFullName ?? 'Usuario',
                    style: GoogleFonts.outfit(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: slate900,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // 2. Información Personal Card (Unified)
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: slate200),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.015),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Name Row (editable only in form)
                      if (_isEditing)
                        _buildEditableRow(
                          icon: HugeIcons.strokeRoundedUser,
                          label: 'Nombre y Apellido',
                          controller: _nameController,
                          validator: (val) => val == null || val.trim().isEmpty ? 'El nombre es obligatorio' : null,
                        )
                      else
                        _buildInfoRow(
                          icon: HugeIcons.strokeRoundedUser,
                          label: 'Nombre y Apellido',
                          value: provider.currentUserFullName ?? 'No especificado',
                        ),
                      const Divider(height: 1, color: slate100, indent: 60),

                      // Phone Row
                      if (_isEditing)
                        _buildEditableRow(
                          icon: HugeIcons.strokeRoundedSmartPhone01,
                          label: 'Celular',
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                        )
                      else
                        _buildInfoRow(
                          icon: HugeIcons.strokeRoundedSmartPhone01,
                          label: 'Celular',
                          value: provider.currentUserCelular ?? 'No especificado',
                        ),
                      const Divider(height: 1, color: slate100, indent: 60),

                      // Email Row
                      if (_isEditing)
                        _buildEditableRow(
                          icon: HugeIcons.strokeRoundedMail01,
                          label: 'Email',
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          validator: (val) => val == null || !val.contains('@') ? 'Ingresa un correo válido' : null,
                        )
                      else
                        _buildInfoRow(
                          icon: HugeIcons.strokeRoundedMail01,
                          label: 'Email',
                          value: user?.email ?? 'No especificado',
                        ),

                      if (isRepartidor) ...[
                        const Divider(height: 1, color: slate100, indent: 60),
                        // Vehicle Row
                        if (_isEditing)
                          _buildEditableRow(
                            icon: HugeIcons.strokeRoundedTruck,
                            label: 'Vehículo',
                            controller: _vehicleController,
                          )
                        else
                          _buildInfoRow(
                            icon: HugeIcons.strokeRoundedTruck,
                            label: 'Vehículo',
                            value: provider.currentUser?.tipoVehiculo ?? 'No especificado',
                          ),
                        const Divider(height: 1, color: slate100, indent: 60),

                        // License Plate Row
                        if (_isEditing)
                          _buildEditableRow(
                            icon: HugeIcons.strokeRoundedNote01,
                            label: 'Patente / Matrícula',
                            controller: _matriculaController,
                          )
                        else
                          _buildInfoRow(
                            icon: HugeIcons.strokeRoundedNote01,
                            label: 'Patente / Matrícula',
                            value: provider.currentUser?.matricula ?? 'No especificado',
                          ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // 3. Configuración App (Repartidor Only)
                if (isRepartidor) ...[
                  _buildGpsCard(provider),
                  const SizedBox(height: 24),
                ],

                // 4. Botones de Acción (Guardar & Cerrar Sesión)
                if (_isEditing) ...[
                  ElevatedButton(
                    onPressed: () => _saveProfile(provider, isRepartidor),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: slate900,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'Guardar Cambios',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

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

                // CRITICAL FOR THE NAVBAR OVERLAP ISSUE: Extra bottom padding to avoid nav bar cutting buttons off
                const SizedBox(height: 130),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required List<List<dynamic>> icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 20.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: HugeIcon(
              icon: icon,
              color: slate700,
              size: 18,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    color: slate400,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value.isNotEmpty ? value : 'No especificado',
                  style: GoogleFonts.outfit(
                    fontSize: 13.5,
                    color: slate900,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.arrow_forward_ios,
            color: slate400,
            size: 14,
          ),
        ],
      ),
    );
  }

  Widget _buildEditableRow({
    required List<List<dynamic>> icon,
    required String label,
    required TextEditingController controller,
    String? Function(String?)? validator,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 20.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: slate200),
            ),
            child: HugeIcon(
              icon: icon,
              color: slate700,
              size: 18,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    color: slate400,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                TextFormField(
                  controller: controller,
                  validator: validator,
                  keyboardType: keyboardType,
                  style: GoogleFonts.outfit(
                    fontSize: 13.5,
                    color: slate900,
                    fontWeight: FontWeight.bold,
                  ),
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 4),
                    border: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    enabledBorder: InputBorder.none,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGpsCard(OrderProvider provider) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: slate200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.015),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 20.0, top: 16.0, right: 20.0),
            child: Text(
              'Configuración App',
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: slate900,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const HugeIcon(
                    icon: HugeIcons.strokeRoundedMapPin,
                    color: Color(0xFFEF4444),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Rastreo GPS de Ruta',
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          color: slate900,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Reporta tu ubicación en tiempo real.',
                        style: GoogleFonts.openSans(
                          fontSize: 10.5,
                          color: slate400,
                        ),
                      ),
                    ],
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
          ),
        ],
      ),
    );
  }
}
