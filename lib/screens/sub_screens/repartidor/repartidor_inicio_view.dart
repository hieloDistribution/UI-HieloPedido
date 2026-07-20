import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import '../../../providers/order_provider.dart';
import '../../../models/order_model.dart';
import '../shared/widgets/build_avatar_helper.dart';

class RepartidorInicioView extends StatefulWidget {
  const RepartidorInicioView({super.key});

  @override
  State<RepartidorInicioView> createState() => _RepartidorInicioViewState();
}

class _RepartidorInicioViewState extends State<RepartidorInicioView> {
  String? _activeVerificationOrderId;
  final List<TextEditingController> _otpControllers = List.generate(
    4,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _otpFocusNodes = List.generate(4, (_) => FocusNode());
  final _receivedByController = TextEditingController();

  static const Color slate50 = Color(0xFFF8FAFC);
  static const Color slate100 = Color(0xFFF1F5F9);
  static const Color slate200 = Color(0xFFE2E8F0);
  static const Color slate400 = Color(0xFF94A3B8);
  static const Color slate700 = Color(0xFF334155);
  static const Color slate900 = Color(0xFF0F172A);
  static const Color cyanCustom = Color(0xFF06B6D4);

  @override
  void initState() {
    super.initState();
    _requestLocationPermission();
  }

  Future<void> _requestLocationPermission() async {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) {
          if (mounted) {
            _showLocationServiceDialog();
          }
          return;
        }

        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
          if (permission == LocationPermission.denied) {
            if (mounted) {
              _showPermissionDeniedExplanation();
            }
            return;
          }
        }

        if (permission == LocationPermission.deniedForever) {
          if (mounted) {
            _showPermissionDeniedExplanation();
          }
          return;
        }
      } catch (e) {
        debugPrint('Error requesting location permission: $e');
      }
    });
  }

  void _showLocationServiceDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.gps_off, color: Colors.amber, size: 28),
            const SizedBox(width: 10),
            Text(
              'GPS Desactivado',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: slate900),
            ),
          ],
        ),
        content: Text(
          'Para recibir viajes y reportar tu ubicación en tiempo real al administrador, debes activar el servicio de ubicación (GPS) de tu dispositivo.',
          style: GoogleFonts.openSans(color: slate700, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cerrar',
              style: GoogleFonts.outfit(color: slate400, fontWeight: FontWeight.bold),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await Geolocator.openLocationSettings();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(
              'Activar GPS',
              style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _showPermissionDeniedExplanation() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.location_off_outlined, color: Colors.redAccent, size: 28),
            const SizedBox(width: 10),
            Text(
              'Permiso de Ubicación',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: slate900),
            ),
          ],
        ),
        content: Text(
          'Esta aplicación necesita acceder a tu ubicación en tiempo real todo el tiempo para que el administrador pueda conocer tu posición en el mapa, habilitar la geocerca de entregas de hielo y asignarte pedidos cercanos de forma inteligente.',
          style: GoogleFonts.openSans(color: slate700, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Entendido',
              style: GoogleFonts.outfit(color: slate400, fontWeight: FontWeight.bold),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await Geolocator.openAppSettings();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(
              'Configurar Permisos',
              style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    for (var controller in _otpControllers) {
      controller.dispose();
    }
    for (var node in _otpFocusNodes) {
      node.dispose();
    }
    _receivedByController.dispose();
    super.dispose();
  }

  String _getFormattedDate() {
    final now = DateTime.now();
    final months = [
      'Enero',
      'Febrero',
      'Marzo',
      'Abril',
      'Mayo',
      'Junio',
      'Julio',
      'Agosto',
      'Septiembre',
      'Octubre',
      'Noviembre',
      'Diciembre',
    ];
    final days = [
      'Lunes',
      'Martes',
      'Miércoles',
      'Jueves',
      'Viernes',
      'Sábado',
      'Domingo',
    ];
    return '${days[now.weekday - 1]} ${now.day.toString().padLeft(2, '0')} de ${months[now.month - 1]}';
  }

  void _verifyOtpCode(OrderProvider provider, String orderId) async {
    final who = _receivedByController.text.trim();
    if (who.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, escribe el nombre de la persona que recibe.'),
          backgroundColor: Colors.amber,
        ),
      );
      return;
    }

    String enteredCode = _otpControllers.map((c) => c.text).join();
    if (enteredCode.length < 4) return;

    try {
      final success = await provider.confirmDelivery(orderId, enteredCode, who);
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('¡Entrega validada con éxito! 🎉'),
              backgroundColor: Colors.teal,
            ),
          );
          setState(() {
            _activeVerificationOrderId = null;
            _receivedByController.clear();
            for (var c in _otpControllers) {
              c.clear();
            }
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Código incorrecto. Verifica con el cliente.'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        String errorMsg = e.toString().replaceAll('Exception:', '').trim();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al entregar: $errorMsg'),
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Widget _buildDetailTextRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: cyanCustom),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: GoogleFonts.openSans(fontSize: 12, color: slate700),
                children: [
                  TextSpan(
                    text: '$label: ',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(text: value),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<OrderProvider>(context);
    final user = provider.currentUser;
    final orders = provider.orders;

    final myActiveDeliveries = orders
        .where(
          (o) =>
              o.repartidorId == user?.id &&
              (o.status == 'aceptado' || o.status == 'en_camino'),
        )
        .toList();

    final totalCount = orders.length;
    final deliveredOrders = orders
        .where((o) => o.status == 'entregado')
        .toList();
    final deliveredCount = deliveredOrders.length;
    final int totalBolsasDespachadas = deliveredOrders.fold(
      0,
      (sum, o) => sum + (o.quantity),
    );
    final double totalEarnings = deliveredOrders.fold(
      0.0,
      (sum, o) => sum + (o.total),
    );
    final currencyFormatter = NumberFormat.simpleCurrency(
      locale: 'es_PY',
      name: 'Gs',
      decimalDigits: 0,
    );

    // SOLUCIÓN DEFINITIVA AL BUG: Extraemos la orden fuera del árbol de widgets de forma segura
    OrderModel? activeOrder;
    if (myActiveDeliveries.isNotEmpty) {
      activeOrder = myActiveDeliveries.first;
    }
    final isCurrentOrderInCodeStage =
        activeOrder != null &&
        _activeVerificationOrderId == activeOrder.clientOrderId;

    return Scaffold(
      backgroundColor: slate50,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await provider.loadOrders();
            await provider.fetchTodayAgenda();
            await provider.fetchUserAgendas();
            await provider.fetchCurrentUserProfile();
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  buildAvatarHelper(
                    provider.currentUserFullName ?? user?.email,
                    provider.currentUserAvatarUrl,
                    radius: 22,
                    fontSize: 14,
                  ),
                  Text(
                    _getFormattedDate(),
                    style: GoogleFonts.outfit(
                      color: slate700,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: provider.isOnline
                          ? Colors.green.withOpacity(0.08)
                          : Colors.amber.withOpacity(0.08),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      provider.isOnline ? Icons.wifi : Icons.wifi_off,
                      color: provider.isOnline
                          ? Colors.green.shade600
                          : Colors.amber.shade600,
                      size: 18,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                '¡Hola, ${provider.currentUserFullName?.split(' ').first ?? 'Repartidor'}! 👋',
                style: GoogleFonts.outfit(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: slate900,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Resumen analítico y control de tu jornada.',
                style: GoogleFonts.openSans(fontSize: 14, color: slate400),
              ),
              const SizedBox(height: 20),

              Text(
                'Métricas del Día',
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: slate700,
                ),
              ),
              const SizedBox(height: 10),

              GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.25,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildBentoCard(
                    title: 'Rendimiento',
                    value: '$deliveredCount / $totalCount',
                    description: 'Pedidos entregados hoy',
                    icon: Icons.assignment_turned_in_outlined,
                    iconColor: Colors.blue.shade600,
                  ),
                  _buildBentoCard(
                    title: 'Recaudado',
                    value: currencyFormatter.format(totalEarnings),
                    description: 'Efectivo acumulado',
                    icon: Icons.monetization_on_outlined,
                    iconColor: Colors.teal.shade600,
                  ),
                  _buildBentoCard(
                    title: 'Hielo Entregado',
                    value: '$totalBolsasDespachadas und',
                    description: 'Total bolsas movidas',
                    icon: Icons.ac_unit_outlined,
                    iconColor: cyanCustom,
                  ),
                  _buildBentoCard(
                    title: 'Sincronización',
                    value: provider.pendingSyncCount == 0
                        ? 'Al día'
                        : '${provider.pendingSyncCount} cola',
                    description: provider.isOnline
                        ? 'Nube activa'
                        : 'Guardado local',
                    icon: provider.isOnline
                        ? Icons.cloud_done_outlined
                        : Icons.cloud_off_outlined,
                    iconColor: provider.isOnline
                        ? Colors.green.shade600
                        : Colors.red.shade600,
                  ),
                ],
              ),

              const SizedBox(height: 24),

              _buildAgendaSection(provider),

              const SizedBox(height: 24),

              // SECCIÓN INTERACTIVA INFERIOR CORREGIDA
              if (activeOrder != null) ...[
                Text(
                  'Acción de Entrega Requerida',
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: slate700,
                  ),
                ),
                const SizedBox(height: 10),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: !isCurrentOrderInCodeStage
                      ? Container(
                          key: ValueKey('slide_${activeOrder.clientOrderId}'),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: slate200),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.02),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Dismissible(
                            key: Key(activeOrder.clientOrderId),
                            direction: DismissDirection.startToEnd,
                            confirmDismiss: (direction) async {
                              if (activeOrder!.status == 'aceptado') {
                                await provider.startDelivery(
                                  activeOrder.clientOrderId,
                                );
                              }
                              setState(() {
                                _activeVerificationOrderId =
                                    activeOrder!.clientOrderId;
                              });
                              return false;
                            },
                            background: Container(
                              alignment: Alignment.centerLeft,
                              padding: const EdgeInsets.only(left: 20),
                              decoration: BoxDecoration(
                                color: cyanCustom,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Row(
                                children: [
                                  Icon(
                                    Icons.navigation_outlined,
                                    color: Colors.white,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    '¡Viaje Iniciado!',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      buildAvatarHelper(
                                        activeOrder.clientName,
                                        activeOrder.clientAvatarUrl,
                                        radius: 18,
                                        fontSize: 12,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          activeOrder.clientName,
                                          style: GoogleFonts.outfit(
                                            color: slate900,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                          ),
                                        ),
                                      ),
                                      GestureDetector(
                                        onTap: () {
                                          if (activeOrder!.status == 'en_camino') {
                                            setState(() {
                                              _activeVerificationOrderId =
                                                  activeOrder!.clientOrderId;
                                            });
                                          }
                                        },
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              activeOrder.status == 'aceptado'
                                                  ? 'Deslizar para iniciar'
                                                  : 'Ingresar Código',
                                              style: const TextStyle(
                                                color: cyanCustom,
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            const Icon(
                                              Icons.chevron_right,
                                              color: cyanCustom,
                                              size: 18,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  _buildDetailTextRow(
                                    Icons.icecream_outlined,
                                    'Producto solicitado',
                                    activeOrder.productName,
                                  ),
                                  _buildDetailTextRow(
                                    Icons.shopping_bag_outlined,
                                    'Cantidad de bolsas',
                                    '${activeOrder.quantity} bolsas',
                                  ),
                                  _buildDetailTextRow(
                                    Icons.monetization_on_outlined,
                                    'Costo total',
                                    currencyFormatter.format(activeOrder.total),
                                  ),
                                  _buildDetailTextRow(
                                    Icons.payments_outlined,
                                    'Medio de pago',
                                    activeOrder.paymentMethod.toUpperCase(),
                                  ),
                                  _buildDetailTextRow(
                                    Icons.location_on_outlined,
                                    'Dirección de entrega',
                                    (activeOrder.deliveryLatitude != null)
                                        ? 'Coordenadas GPS Fijadas'
                                        : 'No especificada',
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                      : Container(
                          key: ValueKey('code_${activeOrder.clientOrderId}'),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: cyanCustom, width: 1.5),
                            boxShadow: [
                              BoxShadow(
                                color: cyanCustom.withOpacity(0.04),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Ingresa el código del usuario',
                                    style: GoogleFonts.outfit(
                                      color: slate900,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.close,
                                      color: slate400,
                                      size: 18,
                                    ),
                                    onPressed: () => setState(
                                      () => _activeVerificationOrderId = null,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _receivedByController,
                                style: GoogleFonts.outfit(color: slate900, fontSize: 14),
                                decoration: InputDecoration(
                                  labelText: '¿Quién recibe el producto?',
                                  labelStyle: GoogleFonts.outfit(color: slate400, fontSize: 13),
                                  hintText: 'Ej: Juan (Empleado), Carlos (Cajero)',
                                  hintStyle: GoogleFonts.outfit(color: slate400.withOpacity(0.5), fontSize: 12),
                                  prefixIcon: const Icon(Icons.person_outline, color: cyanCustom, size: 20),
                                  filled: true,
                                  fillColor: slate50,
                                  contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: slate200),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: slate200),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(color: cyanCustom, width: 1.5),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: List.generate(4, (index) {
                                  return SizedBox(
                                    width: 48,
                                    child: TextField(
                                      controller: _otpControllers[index],
                                      focusNode: _otpFocusNodes[index],
                                      keyboardType: TextInputType.number,
                                      textAlign: TextAlign.center,
                                      maxLength: 1,
                                      style: GoogleFonts.outfit(
                                        color: slate900,
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      decoration: InputDecoration(
                                        counterText: "",
                                        filled: true,
                                        fillColor: slate100,
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          borderSide: const BorderSide(
                                            color: slate200,
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          borderSide: const BorderSide(
                                            color: cyanCustom,
                                            width: 1.5,
                                          ),
                                        ),
                                      ),
                                      onChanged: (value) {
                                        if (value.isNotEmpty) {
                                          if (index < 3) {
                                            FocusScope.of(context).requestFocus(
                                              _otpFocusNodes[index + 1],
                                            );
                                          } else {
                                            _otpFocusNodes[index].unfocus();
                                            _verifyOtpCode(
                                              provider,
                                              activeOrder!.clientOrderId,
                                            );
                                          }
                                        } else if (value.isEmpty && index > 0) {
                                          FocusScope.of(context).requestFocus(
                                            _otpFocusNodes[index - 1],
                                          );
                                        }
                                      },
                                    ),
                                  );
                                }),
                              ),
                            ],
                          ),
                        ),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
    );
  }

  Widget _buildBentoCard({
    required String title,
    required String value,
    required String description,
    required IconData icon,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: slate200, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.01),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 16),
              ),
              Expanded(
                child: Text(
                  title,
                  textAlign: TextAlign.end,
                  style: GoogleFonts.outfit(
                    color: slate400,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: slate900,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                description,
                style: GoogleFonts.openSans(fontSize: 10, color: slate400),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAgendaSection(OrderProvider provider) {
    final agenda = provider.todayAgenda;
    if (agenda == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: slate200),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.calendar_today_outlined, color: Color(0xFF64748B), size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sin Agenda Asignada',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: slate900,
                    ),
                  ),
                  Text(
                    'No tienes visitas programadas para hoy.',
                    style: GoogleFonts.openSans(fontSize: 11, color: slate400),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final status = agenda['status'] ?? 'PENDIENTE';
    final itemsCount = (agenda['items'] as List?)?.length ?? 0;
    final isPending = status == 'PENDIENTE';
    final isCompleted = status == 'COMPLETADA';

    if (isCompleted) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFE8F5E9), // light green
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF81C784)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Color(0xFFC8E6C9),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_outline,
                color: Color(0xFF2E7D32),
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '¡Agenda de Hoy Completada! 🎉',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: const Color(0xFF2E7D32),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Completaste con éxito todas tus visitas del día. ¡Buen trabajo!',
                    style: GoogleFonts.openSans(
                      fontSize: 11,
                      color: const Color(0xFF1B5E20),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isPending ? const Color(0xFFFFFBEB) : const Color(0xFFEEF2FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPending ? const Color(0xFFFDE68A) : const Color(0xFFC7D2FE),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isPending ? const Color(0xFFFEF3C7) : const Color(0xFFE0E7FF),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isPending ? Icons.notification_important_outlined : Icons.calendar_month_outlined,
              color: isPending ? const Color(0xFFD97706) : const Color(0xFF4F46E5),
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isPending ? 'Nueva Agenda Pendiente' : 'Agenda Activa en Progreso',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: slate900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isPending
                      ? 'Se te asignó un recorrido con $itemsCount paradas. Por favor, acéptalo en la pestaña Agendas.'
                      : 'Tienes un itinerario de $itemsCount visitas hoy. Revisa el avance en la pestaña Agendas.',
                  style: GoogleFonts.openSans(
                    fontSize: 11,
                    color: slate700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
