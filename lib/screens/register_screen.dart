import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../providers/order_provider.dart';
import 'sub_screens/shared/widgets/success_overlay_dialog.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();

  final _dniController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _plateController = TextEditingController();
  final _businessNameController = TextEditingController();

  LatLng? _selectedBusinessLocation;

  bool _obscurePassword = true;
  String _selectedRole = 'repartidor'; // 'repartidor' or 'cliente'
  String _selectedVehicle = 'Moto'; // 'Moto' or 'Auto'
  int _currentStep = 1;
  bool _isGeocoding = false;

  // Paleta de colores local limpia y segura
  static const Color slate300 = Color(0xFFCBD5E1);
  static const Color slate400 = Color(0xFF94A3B8);
  static const Color slate800 = Color(0xFF1E293B);
  static const Color slate900 = Color(0xFF0F172A);

  @override
  void initState() {
    super.initState();
    _nameController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _dniController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _plateController.dispose();
    _businessNameController.dispose();
    super.dispose();
  }

  String getInitials(String fullName) {
    if (fullName.trim().isEmpty) return '?';
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return (parts[0][0] + parts[1][0]).toUpperCase();
    }
    return parts[0][0].toUpperCase();
  }

  Future<void> _reverseGeocode(LatLng location) async {
    setState(() {
      _isGeocoding = true;
      _addressController.text = 'Detectando calle...';
    });
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=${location.latitude}&lon=${location.longitude}&zoom=18&addressdetails=1',
      );
      final response = await http.get(url, headers: {
        'User-Agent': 'hielo-distribution-app-maxce',
      });
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final address = data['display_name'] as String?;
        if (address != null && mounted) {
          setState(() {
            final parts = address.split(',');
            if (parts.length > 2) {
              // Si la calle está en la primera o segunda parte:
              _addressController.text = '${parts[0].trim()}, ${parts[1].trim()}';
            } else {
              _addressController.text = address;
            }
          });
        }
      }
    } catch (e) {
      debugPrint('Error en geocodificación reversa: $e');
      if (mounted) {
        setState(() {
          _addressController.text = 'Formosa Capital';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGeocoding = false;
        });
      }
    }
  }

  void _openBusinessMapPicker() {
    LatLng centerPosition = const LatLng(-26.1851, -58.1747); // Centrado en Formosa Capital

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (mapContext) => Scaffold(
          appBar: AppBar(
            backgroundColor: slate900,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(mapContext),
            ),
            title: Text(
              'Fijar Ubicación Comercial',
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  setState(() {
                    _selectedBusinessLocation = centerPosition;
                  });
                  _reverseGeocode(centerPosition);
                  Navigator.pop(mapContext);
                },
                child: Text(
                  'Confirmar',
                  style: GoogleFonts.outfit(
                    color: Colors.cyanAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          body: Stack(
            children: [
              GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: centerPosition,
                  zoom: 15.0,
                ),
                zoomControlsEnabled: false,
                myLocationButtonEnabled: false,
                onCameraMove: (position) {
                  centerPosition = position.target;
                },
              ),
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 35),
                  child: const Icon(
                    Icons.location_on,
                    size: 45,
                    color: Colors.redAccent,
                  ),
                ),
              ),
              Positioned(
                bottom: 20,
                left: 20,
                right: 20,
                child: Card(
                  color: slate900,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: Colors.white10),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      'Arrastra el mapa para centrar el marcador rojo exactamente en tu negocio o local comercial.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.openSans(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedRole == 'cliente' && _selectedBusinessLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, selecciona la ubicación comercial en el mapa.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final provider = Provider.of<OrderProvider>(context, listen: false);
    try {
      final fullName = _nameController.text.trim();
      final role = _selectedRole;
      final avatarUrl = role == 'repartidor'
          ? 'assets/repartidor.png'
          : 'assets/cliente.png';

      await provider.signUpWithEmail(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        fullName: fullName,
        role: role,
        avatarUrl: avatarUrl,
        dni: role == 'cliente' ? _dniController.text.trim() : null,
        direccion: role == 'cliente' ? _addressController.text.trim() : null,
        celular: role == 'cliente' ? _phoneController.text.trim() : null,
        nombreComercial: role == 'cliente' ? _businessNameController.text.trim() : null,
        latitudComercial: role == 'cliente' ? _selectedBusinessLocation?.latitude : null,
        longitudComercial: role == 'cliente' ? _selectedBusinessLocation?.longitude : null,
        tipoVehiculo: role == 'repartidor' ? _selectedVehicle : null,
        matricula: role == 'repartidor' ? _plateController.text.trim() : null,
      );
      if (mounted) {
        final loginContext = context;
        Navigator.pop(context);
        showPremiumSuccessDialog(
          loginContext,
          title: '¡Registro Exitoso!',
          message: 'Tu cuenta ha sido creada correctamente. Ya puedes iniciar sesión con tus credenciales.',
        );
      }
    } catch (e) {
      if (mounted) {
        showPremiumErrorDialog(
          context,
          title: 'Error al Registrarse',
          message: e.toString().replaceAll('Exception:', '').trim(),
        );
      }
    }
  }

  // Helper para las etiquetas arriba de los inputs
  Widget _buildFieldLabel(String labelText) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, left: 4),
      child: Text(
        labelText,
        style: GoogleFonts.outfit(
          color: slate300,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  InputDecoration _buildInputDecoration({
    required String hint,
    required Widget prefix,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white30, fontSize: 14),
      prefixIcon: prefix,
      filled: true,
      fillColor: Colors.white.withOpacity(0.03),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.cyanAccent, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<OrderProvider>(context);

    return Scaffold(
      backgroundColor: Colors.black, // Fondo Negro Puro solicitado
      body: Stack(
        children: [
          // Botón Atrás
          Positioned(
            top: 50,
            left: 16,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const HugeIcon(
                  icon: HugeIcons.strokeRoundedArrowLeft01,
                  color: Colors.white,
                  size: 24,
                ),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),

          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 60.0,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Mensaje Gancho Separado
                    Text(
                      'Únete a la Red',
                      style: GoogleFonts.outfit(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Text(
                        'Crea tu cuenta hoy y empieza a gestionar tus despachos de hielo con la mayor velocidad.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.openSans(
                          fontSize: 14,
                          color: slate400,
                          height: 1.4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Tarjeta Vertical Organizada
                    Container(
                      constraints: const BoxConstraints(
                        maxWidth: 480,
                      ), // Tamaño controlado y estético
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: slate900,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.08),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Selector de Rol (Ahora al inicio)
                          _buildFieldLabel('Selecciona tu Rol'),
                          Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => setState(() {
                                    _selectedRole = 'repartidor';
                                    _currentStep = 1; // Reset steps when switching role
                                  }),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    decoration: BoxDecoration(
                                      color: Colors.black,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: _selectedRole == 'repartidor'
                                            ? Colors.cyanAccent
                                            : Colors.white12,
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Center(
                                      child: Text(
                                        'Preventista',
                                        style: GoogleFonts.inter(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => setState(() {
                                    _selectedRole = 'cliente';
                                    _currentStep = 1;
                                  }),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    decoration: BoxDecoration(
                                      color: Colors.black,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: _selectedRole == 'cliente'
                                            ? Colors.cyanAccent
                                            : Colors.white12,
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Center(
                                      child: Text(
                                        'Cliente',
                                        style: GoogleFonts.inter(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // Indicador de pasos solo para clientes
                          if (_selectedRole == 'cliente') ...[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _buildStepIndicator(1, 'Negocio', _currentStep >= 1),
                                Container(
                                  width: 40,
                                  height: 2,
                                  color: _currentStep >= 2 ? Colors.cyanAccent : Colors.white24,
                                ),
                                _buildStepIndicator(2, 'Dueño', _currentStep >= 2),
                              ],
                            ),
                            const SizedBox(height: 24),
                          ],

                          // Avatar de Perfil Dinámico (Solo en pantallas donde ya se ingresó nombre)
                          if (_selectedRole == 'repartidor' || _currentStep == 2) ...[
                            Center(
                              child: Container(
                                width: 100,
                                height: 100,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.cyanAccent,
                                    width: 2.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.cyanAccent.withOpacity(0.12),
                                      blurRadius: 12,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(50),
                                  child: _nameController.text.trim().isEmpty
                                      ? Image.asset(
                                          _selectedRole == 'repartidor'
                                              ? 'assets/repartidor.png'
                                              : 'assets/cliente.png',
                                          fit: BoxFit.cover,
                                        )
                                      : Container(
                                          color: Colors.cyan.shade800,
                                          alignment: Alignment.center,
                                          child: Text(
                                            getInitials(_nameController.text),
                                            style: GoogleFonts.outfit(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 34,
                                            ),
                                          ),
                                        ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                          ],

                          // VISTA PASO 1 CLIENTE: DATOS DEL LOCAL/NEGOCIO
                          if (_selectedRole == 'cliente' && _currentStep == 1) ...[
                            _buildFieldLabel('Nombre Comercial del Negocio'),
                            TextFormField(
                              controller: _businessNameController,
                              style: const TextStyle(color: Colors.white),
                              decoration: _buildInputDecoration(
                                hint: 'Ej: Despensa Formosa',
                                prefix: const Icon(
                                  Icons.storefront_outlined,
                                  color: Colors.cyanAccent,
                                  size: 20,
                                ),
                              ),
                              validator: (val) =>
                                  (val == null || val.trim().isEmpty)
                                  ? 'Ingresa el nombre comercial'
                                  : null,
                            ),
                            const SizedBox(height: 16),

                            _buildFieldLabel('Ubicación Comercial (Pin en Mapa)'),
                            InkWell(
                              onTap: _openBusinessMapPicker,
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.03),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: _selectedBusinessLocation != null
                                        ? Colors.tealAccent
                                        : Colors.white.withOpacity(0.08),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.map_outlined,
                                      color: _selectedBusinessLocation != null
                                          ? Colors.tealAccent
                                          : Colors.cyanAccent,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        _selectedBusinessLocation == null
                                            ? 'Seleccionar en el mapa'
                                            : 'Ubicación fijada: (${_selectedBusinessLocation!.latitude.toStringAsFixed(5)}, ${_selectedBusinessLocation!.longitude.toStringAsFixed(5)})',
                                        style: GoogleFonts.outfit(
                                          color: _selectedBusinessLocation != null
                                              ? Colors.tealAccent
                                              : Colors.white70,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                    if (_selectedBusinessLocation != null)
                                      const Icon(
                                        Icons.check_circle_outline,
                                        color: Colors.tealAccent,
                                        size: 20,
                                      ),
                                  ],
                                ),
                              ),
                            ),

                            if (_selectedBusinessLocation != null || _isGeocoding) ...[
                              const SizedBox(height: 16),
                              _buildFieldLabel('Dirección Detectada (Calle)'),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.02),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.white10),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.location_on_outlined,
                                      color: Colors.cyanAccent,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _isGeocoding
                                          ? const SizedBox(
                                              height: 18,
                                              width: 18,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.cyanAccent,
                                              ),
                                            )
                                          : Text(
                                              _addressController.text.isEmpty
                                                  ? 'No se pudo detectar la calle'
                                                  : _addressController.text,
                                              style: GoogleFonts.outfit(
                                                color: Colors.white70,
                                                fontSize: 14,
                                              ),
                                            ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 28),

                            // Botón de Continuar
                            Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                gradient: const LinearGradient(
                                  colors: [Colors.cyan, Colors.teal],
                                ),
                              ),
                              child: ElevatedButton(
                                onPressed: () {
                                  if (_formKey.currentState!.validate()) {
                                    if (_selectedBusinessLocation == null) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Por favor, selecciona la ubicación comercial en el mapa.'),
                                          backgroundColor: Colors.redAccent,
                                        ),
                                      );
                                      return;
                                    }
                                    setState(() {
                                      _currentStep = 2;
                                    });
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: Text(
                                  'CONTINUAR',
                                  style: GoogleFonts.inter(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],

                          // VISTA PASO 2 CLIENTE: DATOS DEL DUEÑO/PROPIETARIO
                          if (_selectedRole == 'cliente' && _currentStep == 2) ...[
                            _buildFieldLabel('Nombre y Apellido del Dueño'),
                            TextFormField(
                              controller: _nameController,
                              style: const TextStyle(color: Colors.white),
                              decoration: _buildInputDecoration(
                                hint: 'Ej: Mauricio Heredia',
                                prefix: const Icon(
                                  Icons.person_outline,
                                  color: Colors.cyanAccent,
                                  size: 20,
                                ),
                              ),
                              validator: (val) =>
                                  (val == null || val.trim().isEmpty)
                                  ? 'Ingresa tu nombre'
                                  : null,
                            ),
                            const SizedBox(height: 16),

                            _buildFieldLabel('DNI / Documento del Dueño'),
                            TextFormField(
                              controller: _dniController,
                              keyboardType: TextInputType.number,
                              style: const TextStyle(color: Colors.white),
                              decoration: _buildInputDecoration(
                                hint: 'Ej: 54321098',
                                prefix: const Icon(
                                  Icons.badge_outlined,
                                  color: Colors.cyanAccent,
                                  size: 20,
                                ),
                              ),
                              validator: (val) =>
                                  (val == null || val.trim().isEmpty)
                                  ? 'Ingresa tu DNI'
                                  : null,
                            ),
                            const SizedBox(height: 16),

                            _buildFieldLabel('Número de Celular del Dueño'),
                            TextFormField(
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              style: const TextStyle(color: Colors.white),
                              decoration: _buildInputDecoration(
                                hint: 'Ej: +595981234567',
                                prefix: const Icon(
                                  Icons.phone_android_outlined,
                                  color: Colors.cyanAccent,
                                  size: 20,
                                ),
                              ),
                              validator: (val) =>
                                  (val == null || val.trim().isEmpty)
                                  ? 'Ingresa tu celular'
                                  : null,
                            ),
                            const SizedBox(height: 16),

                            _buildFieldLabel('Correo Electrónico del Dueño'),
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              style: const TextStyle(color: Colors.white),
                              decoration: _buildInputDecoration(
                                hint: 'Ej: usuario@correo.com',
                                prefix: const Padding(
                                  padding: EdgeInsets.all(12.0),
                                  child: HugeIcon(
                                    icon: HugeIcons.strokeRoundedMail01,
                                    color: Colors.cyanAccent,
                                    size: 20,
                                  ),
                                ),
                              ),
                              validator: (val) =>
                                  (val == null || !val.contains('@'))
                                  ? 'Correo inválido'
                                  : null,
                            ),
                            const SizedBox(height: 16),

                            _buildFieldLabel('Contraseña para la Cuenta'),
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              style: const TextStyle(color: Colors.white),
                              decoration: _buildInputDecoration(
                                hint: 'Mínimo 6 caracteres',
                                prefix: const Padding(
                                      padding: EdgeInsets.all(12.0),
                                      child: HugeIcon(
                                        icon: HugeIcons.strokeRoundedLock,
                                        color: Colors.cyanAccent,
                                        size: 20,
                                      ),
                                    ),
                                  ).copyWith(
                                    suffixIcon: IconButton(
                                      icon: HugeIcon(
                                        icon: _obscurePassword
                                            ? HugeIcons.strokeRoundedViewOff
                                            : HugeIcons.strokeRoundedView,
                                        color: Colors.white70,
                                        size: 18,
                                      ),
                                      onPressed: () => setState(
                                        () => _obscurePassword = !_obscurePassword,
                                      ),
                                    ),
                                  ),
                              validator: (val) => (val == null || val.length < 6)
                                  ? 'Contraseña muy corta'
                                  : null,
                            ),
                            const SizedBox(height: 28),

                            // Botones de Navegación del Paso 2
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () {
                                      setState(() {
                                        _currentStep = 1;
                                      });
                                    },
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      side: const BorderSide(color: Colors.white24),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: Text(
                                      'VOLVER',
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white70,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: provider.isLoading
                                      ? const Center(
                                          child: CircularProgressIndicator(
                                            color: Colors.cyanAccent,
                                          ),
                                        )
                                      : Container(
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(12),
                                            gradient: const LinearGradient(
                                              colors: [Colors.cyan, Colors.teal],
                                            ),
                                          ),
                                          child: ElevatedButton(
                                            onPressed: _submit,
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.transparent,
                                              shadowColor: Colors.transparent,
                                              padding: const EdgeInsets.symmetric(vertical: 14),
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                            ),
                                            child: Text(
                                              'REGISTRARSE',
                                              style: GoogleFonts.inter(
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ),
                                ),
                              ],
                            ),
                          ],

                          // VISTA PREVENTISTA: REGISTRO DIRECTO SIN PASOS
                          if (_selectedRole == 'repartidor') ...[
                            _buildFieldLabel('Nombre y Apellido'),
                            TextFormField(
                              controller: _nameController,
                              style: const TextStyle(color: Colors.white),
                              decoration: _buildInputDecoration(
                                hint: 'Ej: Mauricio Heredia',
                                prefix: const Icon(
                                  Icons.person_outline,
                                  color: Colors.cyanAccent,
                                  size: 20,
                                ),
                              ),
                              validator: (val) =>
                                  (val == null || val.trim().isEmpty)
                                  ? 'Ingresa tu nombre'
                                  : null,
                            ),
                            const SizedBox(height: 16),

                            _buildFieldLabel('Correo Electrónico'),
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              style: const TextStyle(color: Colors.white),
                              decoration: _buildInputDecoration(
                                hint: 'Ej: preventista@correo.com',
                                prefix: const Padding(
                                  padding: EdgeInsets.all(12.0),
                                  child: HugeIcon(
                                    icon: HugeIcons.strokeRoundedMail01,
                                    color: Colors.cyanAccent,
                                    size: 20,
                                  ),
                                ),
                              ),
                              validator: (val) =>
                                  (val == null || !val.contains('@'))
                                  ? 'Correo inválido'
                                  : null,
                            ),
                            const SizedBox(height: 16),

                            _buildFieldLabel('Contraseña'),
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              style: const TextStyle(color: Colors.white),
                              decoration: _buildInputDecoration(
                                hint: 'Mínimo 6 caracteres',
                                prefix: const Padding(
                                      padding: EdgeInsets.all(12.0),
                                      child: HugeIcon(
                                        icon: HugeIcons.strokeRoundedLock,
                                        color: Colors.cyanAccent,
                                        size: 20,
                                      ),
                                    ),
                                  ).copyWith(
                                    suffixIcon: IconButton(
                                      icon: HugeIcon(
                                        icon: _obscurePassword
                                            ? HugeIcons.strokeRoundedViewOff
                                            : HugeIcons.strokeRoundedView,
                                        color: Colors.white70,
                                        size: 18,
                                      ),
                                      onPressed: () => setState(
                                        () => _obscurePassword = !_obscurePassword,
                                      ),
                                    ),
                                  ),
                              validator: (val) => (val == null || val.length < 6)
                                  ? 'Contraseña muy corta'
                                  : null,
                            ),
                            const SizedBox(height: 16),

                            _buildFieldLabel('Tipo de Vehículo'),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.03),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white.withOpacity(0.08)),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _selectedVehicle,
                                  dropdownColor: slate800,
                                  style: GoogleFonts.outfit(color: Colors.white, fontSize: 15),
                                  icon: const Icon(Icons.arrow_drop_down, color: Colors.cyanAccent),
                                  isExpanded: true,
                                  items: ['Moto', 'Auto', 'Camión'].map((String value) {
                                    return DropdownMenuItem<String>(
                                      value: value,
                                      child: Text(value),
                                    );
                                  }).toList(),
                                  onChanged: (val) {
                                    if (val != null) {
                                      setState(() => _selectedVehicle = val);
                                    }
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            _buildFieldLabel('Matrícula / Patente del Vehículo'),
                            TextFormField(
                              controller: _plateController,
                              style: const TextStyle(color: Colors.white),
                              decoration: _buildInputDecoration(
                                hint: 'Ej: AAA 123 PY',
                                prefix: const Icon(
                                  Icons.numbers_outlined,
                                  color: Colors.cyanAccent,
                                  size: 20,
                                ),
                              ),
                              validator: (val) =>
                                  (val == null || val.trim().isEmpty)
                                  ? 'Ingresa la patente'
                                  : null,
                            ),
                            const SizedBox(height: 28),

                            provider.isLoading
                                ? const Center(
                                    child: CircularProgressIndicator(
                                      color: Colors.cyanAccent,
                                    ),
                                  )
                                : Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      gradient: const LinearGradient(
                                        colors: [Colors.cyan, Colors.teal],
                                      ),
                                    ),
                                    child: ElevatedButton(
                                      onPressed: _submit,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.transparent,
                                        shadowColor: Colors.transparent,
                                        padding: const EdgeInsets.symmetric(vertical: 14),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                      ),
                                      child: Text(
                                        'REGISTRARSE',
                                        style: GoogleFonts.inter(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                          ],

                          const SizedBox(height: 12),

                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text(
                              '¿Ya tienes cuenta? Inicia Sesión',
                              style: TextStyle(
                                color: Colors.cyanAccent,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ).animate().fade(delay: 200.ms).slideY(begin: 0.05),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepIndicator(int step, String label, bool active) {
    return Column(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active ? Colors.cyan : Colors.transparent,
            border: Border.all(
              color: active ? Colors.cyanAccent : Colors.white24,
              width: 1.5,
            ),
          ),
          child: Center(
            child: Text(
              '$step',
              style: GoogleFonts.outfit(
                color: active ? Colors.black : Colors.white70,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.outfit(
            color: active ? Colors.cyanAccent : Colors.white38,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
