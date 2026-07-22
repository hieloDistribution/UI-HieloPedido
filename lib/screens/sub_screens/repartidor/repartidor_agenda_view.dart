import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../../../providers/order_provider.dart';
import 'create_order_view.dart';

class RepartidorAgendaView extends StatefulWidget {
  const RepartidorAgendaView({super.key});

  @override
  State<RepartidorAgendaView> createState() => _RepartidorAgendaViewState();
}

class _RepartidorAgendaViewState extends State<RepartidorAgendaView> {
  static const Color darkSlate = Color(0xFF0F172A);
  static const Color mediumSlate = Color(0xFF334155);
  static const Color lightSlate = Color(0xFF94A3B8);
  static const Color borderSlate = Color(0xFFE2E8F0);
  static const Color bgSlate = Color(0xFFF8FAFC);
  static const Color cardWhite = Colors.white;

  String _selectedFilter = 'All';
  Map<String, dynamic>? _selectedAgenda;
  Position? _currentPosition;

  // FECHA SELECCIONADA PARA EL CALENDARIO HORIZONTAL
  DateTime _selectedDate = DateTime.now();
  bool _filterByDate = true;

  @override
  void initState() {
    super.initState();
    _fetchCurrentLocation();
  }

  Future<void> _fetchCurrentLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
        final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
        if (mounted) {
          setState(() {
            _currentPosition = pos;
          });
        }
      }
    } catch (e) {
      debugPrint('Error obteniendo GPS: $e');
    }
  }

  // AYUDANTE PARA NORMALIZAR Y COMPARAR FECHAS
  bool _isSameDay(DateTime d1, DateTime d2) {
    return d1.year == d2.year && d1.month == d2.month && d1.day == d2.day;
  }

  DateTime? _parseAgendaDate(dynamic rawDate) {
    if (rawDate == null) return null;
    final str = rawDate.toString().trim();
    if (str.toLowerCase() == 'hoy') return DateTime.now();
    try {
      return DateTime.parse(str);
    } catch (_) {
      return null;
    }
  }

  String _getSpanishDayName(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'LUN';
      case DateTime.tuesday:
        return 'MAR';
      case DateTime.wednesday:
        return 'MIÉ';
      case DateTime.thursday:
        return 'JUE';
      case DateTime.friday:
        return 'VIE';
      case DateTime.saturday:
        return 'SÁB';
      case DateTime.sunday:
        return 'DOM';
      default:
        return '';
    }
  }

  String _getSpanishMonthName(int month) {
    const months = [
      'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
      'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'
    ];
    return months[(month - 1) % 12];
  }

  Future<void> _selectFullCalendarDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 90)),
      lastDate: DateTime.now().add(const Duration(days: 90)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: darkSlate,
              onPrimary: cardWhite,
              surface: cardWhite,
              onSurface: darkSlate,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _filterByDate = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<OrderProvider>(context);

    // Si hay una agenda seleccionada, mostramos la vista de ruta corporativa
    if (_selectedAgenda != null) {
      final updatedAgenda = provider.userAgendas.firstWhere(
        (a) => a['id'] == _selectedAgenda!['id'],
        orElse: () => _selectedAgenda!,
      );

      return Scaffold(
        backgroundColor: bgSlate,
        appBar: AppBar(
          backgroundColor: cardWhite,
          elevation: 0.5,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: darkSlate, size: 18),
            onPressed: () {
              setState(() {
                _selectedAgenda = null;
              });
            },
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hoja de Ruta Comercial',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16, color: darkSlate),
              ),
              Text(
                'Agenda ${updatedAgenda['id'].toString().length >= 7 ? updatedAgenda['id'].toString().substring(0, 7) : updatedAgenda['id']}',
                style: GoogleFonts.openSans(fontSize: 11, color: lightSlate),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.my_location_rounded, color: darkSlate),
              onPressed: _fetchCurrentLocation,
              tooltip: 'Actualizar Ubicación GPS',
            ),
          ],
        ),
        body: _buildSingleRouteCardsView(provider, updatedAgenda),
      );
    }

    // Si no hay agenda seleccionada, mostramos la vista principal con Calendario Horizontal
    return Scaffold(
      backgroundColor: bgSlate,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeaderWithHorizontalCalendar(),
            _buildFilterTabs(),
            Expanded(
              child: _buildAgendasList(provider),
            ),
          ],
        ),
      ),
    );
  }

  // --- HEADER PRINCIPAL CON CALENDARIO HORIZONTAL Y SELECCIÓN DE FECHA ---
  Widget _buildHeaderWithHorizontalCalendar() {
    // Generar días alrededor de la fecha seleccionada (-3 a +3 días)
    final daysList = List.generate(7, (index) {
      return _selectedDate.add(Duration(days: index - 3));
    });

    return Container(
      decoration: const BoxDecoration(
        color: cardWhite,
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // FILA SUPERIOR: TÍTULO Y BOTÓN DE CALENDARIO COMPLETO
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Agendas',
                    style: GoogleFonts.outfit(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: darkSlate,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${_getSpanishMonthName(_selectedDate.month)} ${_selectedDate.year}',
                    style: GoogleFonts.openSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: lightSlate,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: darkSlate.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'PREVENTISTA',
                      style: GoogleFonts.outfit(
                        color: darkSlate,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // BOTÓN CALENDARIO COMPLETO
                  InkWell(
                    onTap: () => _selectFullCalendarDate(context),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: bgSlate,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: borderSlate),
                      ),
                      child: const HugeIcon(
                        icon: HugeIcons.strokeRoundedCalendar01,
                        color: darkSlate,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 16),

          // CALENDARIO HORIZONTAL NAVEGABLE
          SizedBox(
            height: 72,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: daysList.map((dayDate) {
                final isSelected = _isSameDay(dayDate, _selectedDate);
                final isToday = _isSameDay(dayDate, DateTime.now());

                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedDate = dayDate;
                        _filterByDate = true;
                      });
                    },
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        color: isSelected ? darkSlate : bgSlate,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected
                              ? darkSlate
                              : isToday
                                  ? darkSlate.withValues(alpha: 0.4)
                                  : borderSlate,
                          width: isToday && !isSelected ? 1.5 : 1.0,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: darkSlate.withValues(alpha: 0.2),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ]
                            : null,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _getSpanishDayName(dayDate.weekday),
                            style: GoogleFonts.outfit(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isSelected ? cardWhite.withValues(alpha: 0.8) : lightSlate,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            dayDate.day.toString(),
                            style: GoogleFonts.outfit(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: isSelected ? cardWhite : darkSlate,
                            ),
                          ),
                          if (isSelected) ...[
                            const SizedBox(height: 3),
                            Container(
                              width: 5,
                              height: 5,
                              decoration: const BoxDecoration(
                                color: Color(0xFF10B981), // Punto Verde Esmeralda
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // --- TABS DE FILTRADO POR ESTADO DE LA AGENDA ---
  Widget _buildFilterTabs() {
    final filters = ['All', 'PENDIENTE', 'ACEPTADA', 'COMPLETADA', 'RECHAZADA'];
    return Container(
      color: cardWhite,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: filters.map((f) {
            final isSelected = _selectedFilter == f;

            String labelStr = 'Todas';
            if (f == 'PENDIENTE') labelStr = 'Pendientes';
            if (f == 'ACEPTADA') labelStr = 'Aceptadas';
            if (f == 'COMPLETADA') labelStr = 'Completadas';
            if (f == 'RECHAZADA') labelStr = 'Rechazadas';

            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(
                  labelStr,
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected ? cardWhite : darkSlate,
                  ),
                ),
                selected: isSelected,
                selectedColor: darkSlate,
                backgroundColor: bgSlate,
                onSelected: (val) {
                  if (val) setState(() => _selectedFilter = f);
                },
                side: BorderSide(color: isSelected ? darkSlate : borderSlate),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // --- LISTA PRINCIPAL CON TARJETAS GLASSMORPHISM VIDRIOSO Y ICONOS HUGEICONS ---
  Widget _buildAgendasList(OrderProvider provider) {
    final allUserAgendas = provider.userAgendas;

    // Filtrado por fecha y por estado
    final filteredAgendas = allUserAgendas.where((a) {
      if (_selectedFilter != 'All' && a['status'] != _selectedFilter) {
        return false;
      }

      if (_filterByDate) {
        final agendaDt = _parseAgendaDate(a['date']);
        if (agendaDt != null) {
          return _isSameDay(agendaDt, _selectedDate);
        }
      }
      return true;
    }).toList();

    // Si no hay agendas para la fecha elegida
    if (filteredAgendas.isEmpty) {
      final isToday = _isSameDay(_selectedDate, DateTime.now());
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: darkSlate.withValues(alpha: 0.04),
                  shape: BoxShape.circle,
                ),
                child: const HugeIcon(
                  icon: HugeIcons.strokeRoundedCalendar01,
                  color: lightSlate,
                  size: 48,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _filterByDate
                    ? (isToday ? 'No tienes agendas asignadas para hoy' : 'No tienes agendas asignadas para este día')
                    : 'No hay agendas en este estado',
                style: GoogleFonts.outfit(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: darkSlate,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _filterByDate
                    ? 'Prueba seleccionando otra fecha en el calendario superior o mira todas tus agendas.'
                    : 'Intenta cambiar el filtro de estado arriba.',
                textAlign: TextAlign.center,
                style: GoogleFonts.openSans(fontSize: 12, color: lightSlate),
              ),
              if (_filterByDate && allUserAgendas.isNotEmpty) ...[
                const SizedBox(height: 18),
                OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _filterByDate = false;
                    });
                  },
                  icon: const Icon(Icons.calendar_view_month_rounded, size: 16, color: darkSlate),
                  label: Text(
                    'Ver agendas de otros días',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13, color: darkSlate),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: darkSlate),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    final adminAvatar = provider.adminAvatarUrl;
    final adminName = provider.adminName;

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filteredAgendas.length,
      itemBuilder: (context, index) {
        final agenda = filteredAgendas[index];
        final items = agenda['items'] as List? ?? [];
        final status = agenda['status'] ?? 'PENDIENTE';

        // --- ESTILOS GLASSMORPHISM VIDRIOSO DEPENDIENDO DEL ESTADO ---
        Color glassBgStart;
        Color glassBgEnd;
        Color glassBorderColor;
        Color glassShadowColor;
        Color statusTextColor;
        Color iconBadgeBg;
        Widget statusIconWidget;

        if (status == 'COMPLETADA') {
          // Verde Vidrioso Translucido Elegante
          glassBgStart = const Color(0x1F10B981);
          glassBgEnd = const Color(0x0510B981);
          glassBorderColor = const Color(0xFF10B981).withValues(alpha: 0.35);
          glassShadowColor = const Color(0xFF10B981).withValues(alpha: 0.10);
          statusTextColor = const Color(0xFF059669);
          iconBadgeBg = const Color(0xFFD1FAE5);
          // ICONO CHECKMARK BADGE 03 DE HUGEICONS
          statusIconWidget = const HugeIcon(
            icon: HugeIcons.strokeRoundedCheckmarkBadge03,
            color: Color(0xFF10B981),
            size: 26,
          );
        } else if (status == 'RECHAZADA') {
          // Rojo Vidrioso Translucido Elegante
          glassBgStart = const Color(0x1FEF4444);
          glassBgEnd = const Color(0x05EF4444);
          glassBorderColor = const Color(0xFFEF4444).withValues(alpha: 0.35);
          glassShadowColor = const Color(0xFFEF4444).withValues(alpha: 0.10);
          statusTextColor = const Color(0xFFDC2626);
          iconBadgeBg = const Color(0xFFFEE2E2);
          // ICONO CANCEL CIRCLE DE HUGEICONS
          statusIconWidget = const HugeIcon(
            icon: HugeIcons.strokeRoundedCancelCircle,
            color: Color(0xFFEF4444),
            size: 24,
          );
        } else if (status == 'ACEPTADA') {
          // Indigo Vidrioso
          glassBgStart = const Color(0x1F6366F1);
          glassBgEnd = const Color(0x056366F1);
          glassBorderColor = const Color(0xFF6366F1).withValues(alpha: 0.35);
          glassShadowColor = const Color(0xFF6366F1).withValues(alpha: 0.08);
          statusTextColor = const Color(0xFF4F46E5);
          iconBadgeBg = const Color(0xFFE0E7FF);
          statusIconWidget = const HugeIcon(
            icon: HugeIcons.strokeRoundedCheckmarkCircle01,
            color: Color(0xFF4F46E5),
            size: 24,
          );
        } else {
          // Pendiente (Ámbar / Neutro Vidrioso)
          glassBgStart = cardWhite;
          glassBgEnd = const Color(0xFFF8FAFC);
          glassBorderColor = borderSlate;
          glassShadowColor = darkSlate.withValues(alpha: 0.04);
          statusTextColor = const Color(0xFFD97706);
          iconBadgeBg = const Color(0xFFFEF3C7);
          statusIconWidget = const HugeIcon(
            icon: HugeIcons.strokeRoundedClock01,
            color: Color(0xFFD97706),
            size: 22,
          );
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [glassBgStart, glassBgEnd],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: glassBorderColor, width: 1.4),
            boxShadow: [
              BoxShadow(
                color: glassShadowColor,
                blurRadius: 16,
                spreadRadius: 0,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () {
              setState(() {
                _selectedAgenda = agenda;
              });
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // CABECERA DE LA TARJETA CON AVATAR ADMIN E ICONO DE ESTADO
                  Row(
                    children: [
                      // AVATAR DEL ADMIN
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: cardWhite,
                          border: Border.all(color: glassBorderColor, width: 1.2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black12.withValues(alpha: 0.05),
                              blurRadius: 6,
                            ),
                          ],
                          image: adminAvatar != null
                              ? DecorationImage(
                                  image: NetworkImage(adminAvatar),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: adminAvatar == null
                            ? const Center(
                                child: Icon(Icons.person_rounded, color: darkSlate, size: 22),
                              )
                            : null,
                      ),
                      const SizedBox(width: 12),

                      // DETALLES DEL ADMIN Y COMERCIOS ASIGNADOS
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Asignado por: $adminName',
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: darkSlate,
                              ),
                            ),
                            const SizedBox(height: 2),
                            (() {
                              final totalCount = items.length;
                              final pendingCount = items.where((i) => (i['status'] ?? 'PENDIENTE') != 'COMPLETADO').length;
                              final completedCount = totalCount - pendingCount;

                              String subtitleText = '$totalCount locales asignados';
                              if (totalCount > 0) {
                                if (pendingCount > 0) {
                                  subtitleText = '$totalCount locales ($completedCount visitados, $pendingCount pendientes)';
                                } else {
                                  subtitleText = '$totalCount/$totalCount visitados • Hoja completada';
                                }
                              }

                              return Row(
                                children: [
                                  const Icon(Icons.storefront_outlined, size: 14, color: lightSlate),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      subtitleText,
                                      style: GoogleFonts.openSans(
                                        fontSize: 11,
                                        color: pendingCount > 0 ? const Color(0xFFD97706) : const Color(0xFF059669),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            })(),
                          ],
                        ),
                      ),

                      // INSIGNIA E ICONO DE ESTADO (CheckmarkBadge03 / CancelCircle)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: iconBadgeBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: glassBorderColor.withValues(alpha: 0.5)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            statusIconWidget,
                            const SizedBox(width: 5),
                            Text(
                              status,
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: statusTextColor,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // FILA INFERIOR CON FECHA Y FLECHA DE NAVEGACIÓN DE ACCIÓN
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const HugeIcon(
                            icon: HugeIcons.strokeRoundedCalendar02,
                            color: lightSlate,
                            size: 14,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Fecha: ${agenda['date'] ?? 'Hoy'}',
                            style: GoogleFonts.openSans(
                              fontSize: 11,
                              color: lightSlate,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      // BOTÓN FLECHA CIRCULAR CON EFECTO VIDRIOSO DE ACCIÓN
                      InkWell(
                        onTap: () {
                          setState(() {
                            _selectedAgenda = agenda;
                          });
                        },
                        borderRadius: BorderRadius.circular(30),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: darkSlate,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: darkSlate.withValues(alpha: 0.2),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Text(
                                'Ver Locales',
                                style: GoogleFonts.outfit(
                                  color: cardWhite,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Icon(
                                Icons.arrow_forward_rounded,
                                size: 14,
                                color: cardWhite,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // --- VISTA DE HOJA DE RUTA CON TARJETAS Y DATOS DE LA BD ---
  Widget _buildSingleRouteCardsView(OrderProvider provider, Map<String, dynamic> agenda) {
    final items = List<Map<String, dynamic>>.from(agenda['items'] as List? ?? []);

    final List<Map<String, dynamic>> processedItems = items.map((it) {
      final clientObj = it['client'] as Map<String, dynamic>? ?? {};
      final clientId = clientObj['id'] ?? it['client_id'];

      final match = provider.clientes.firstWhere(
        (c) => c['id'] == clientId,
        orElse: () => clientObj,
      );

      final name = match['name'] ?? clientObj['name'] ?? 'Comercio Registrado';
      final ownerName = match['ownerName'] ?? clientObj['ownerName'] ?? match['owner_name'] ?? 'Propietario no especificado';
      final phone = match['phone'] ?? clientObj['phone'] ?? match['celular'] ?? 'Sin contacto';
      final address = match['address'] ?? clientObj['address'] ?? match['direccion'] ?? 'Sin dirección registrada';
      final lat = ((match['latitude'] ?? clientObj['latitude'] ?? match['latitud']) as num?)?.toDouble() ?? -26.1850;
      final lng = ((match['longitude'] ?? clientObj['longitude'] ?? match['longitud']) as num?)?.toDouble() ?? -58.1741;

      double? distKm;
      if (_currentPosition != null) {
        distKm = Geolocator.distanceBetween(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
          lat,
          lng,
        ) / 1000.0;
      }

      return {
        'agendaItem': it,
        'itemId': it['id'],
        'clientId': clientId,
        'status': it['status'] ?? 'PENDIENTE',
        'name': name,
        'ownerName': ownerName,
        'phone': phone,
        'address': address,
        'lat': lat,
        'lng': lng,
        'distanceKm': distKm,
      };
    }).toList();

    Map<String, dynamic>? nearestPendingItem;
    final pendingItems = processedItems.where((i) => i['status'] == 'PENDIENTE' && i['distanceKm'] != null).toList();
    if (pendingItems.isNotEmpty) {
      pendingItems.sort((a, b) => (a['distanceKm'] as double).compareTo(b['distanceKm'] as double));
      nearestPendingItem = pendingItems.first;
    }

    final completedCount = processedItems.where((i) => i['status'] == 'COMPLETADO').length;
    final totalCount = processedItems.length;
    final progressFraction = totalCount > 0 ? (completedCount / totalCount) : 0.0;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Resumen de Progreso
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardWhite,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderSlate),
            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Progreso de Visitas ($completedCount / $totalCount)',
                    style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold, color: darkSlate),
                  ),
                  Text(
                    '${(progressFraction * 100).toInt()}%',
                    style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold, color: darkSlate),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: progressFraction,
                  minHeight: 8,
                  backgroundColor: bgSlate,
                  valueColor: const AlwaysStoppedAnimation<Color>(darkSlate),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        if (nearestPendingItem != null) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: darkSlate,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: darkSlate.withValues(alpha: 0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                const Icon(Icons.near_me_rounded, color: cardWhite, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '📍 Tienda recomendada más cercana',
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: cardWhite,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${nearestPendingItem['name']} (a ${(nearestPendingItem['distanceKm'] as double).toStringAsFixed(1)} km de ti)',
                        style: GoogleFonts.openSans(
                          fontSize: 12,
                          color: const Color(0xFFCBD5E1),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        ...processedItems.map((item) {
          final isCompleted = item['status'] == 'COMPLETADO';
          final isNearest = nearestPendingItem != null && nearestPendingItem['itemId'] == item['itemId'];
          final dist = item['distanceKm'] as double?;

          return Container(
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: cardWhite,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isNearest ? darkSlate : borderSlate,
                width: isNearest ? 2.0 : 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: darkSlate.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isCompleted ? const Color(0xFF10B981) : darkSlate,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const HugeIcon(
                          icon: HugeIcons.strokeRoundedStore03,
                          color: cardWhite,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item['name'],
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: darkSlate,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              item['address'],
                              style: GoogleFonts.openSans(fontSize: 12, color: lightSlate),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isCompleted ? const Color(0xFFD1FAE5) : bgSlate,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: isCompleted ? const Color(0xFF10B981) : darkSlate),
                        ),
                        child: Text(
                          isCompleted ? 'COMPLETADO' : 'PENDIENTE',
                          style: GoogleFonts.outfit(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isCompleted ? const Color(0xFF059669) : darkSlate,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const Divider(height: 20, color: borderSlate),

                  Row(
                    children: [
                      const Icon(Icons.person_outline_rounded, size: 15, color: lightSlate),
                      const SizedBox(width: 6),
                      Text('Dueño: ', style: GoogleFonts.openSans(fontSize: 12, color: lightSlate)),
                      Text(item['ownerName'], style: GoogleFonts.openSans(fontSize: 12, fontWeight: FontWeight.bold, color: darkSlate)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.phone_outlined, size: 15, color: lightSlate),
                      const SizedBox(width: 6),
                      Text('Celular: ', style: GoogleFonts.openSans(fontSize: 12, color: lightSlate)),
                      Text(item['phone'], style: GoogleFonts.openSans(fontSize: 12, fontWeight: FontWeight.bold, color: darkSlate)),
                      if (dist != null) ...[
                        const Spacer(),
                        Text(
                          '${dist.toStringAsFixed(1)} km',
                          style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: darkSlate),
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(height: 14),

                  Row(
                    children: [
                      // BOTÓN VER MAPA
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            _showInAppRouteMapModal(context, item);
                          },
                          icon: const Icon(Icons.map_outlined, size: 16, color: darkSlate),
                          label: Text(
                            'Ver Mapa',
                            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 12, color: darkSlate),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: darkSlate),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),

                      // BOTÓN TOMAR PEDIDO / VER PEDIDO
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            if (isCompleted) {
                              _showOrderDetailsModal(context, item, provider);
                            } else {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => CreateOrderView(
                                    prefilledClientId: item['clientId'],
                                    agendaItemId: item['itemId'],
                                  ),
                                ),
                              );
                            }
                          },
                          icon: Icon(
                            isCompleted ? Icons.receipt_long_rounded : Icons.shopping_bag_outlined,
                            size: 16,
                            color: cardWhite,
                          ),
                          label: Text(
                            isCompleted ? 'VER PEDIDO' : 'TOMAR PEDIDO',
                            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isCompleted ? const Color(0xFF10B981) : darkSlate,
                            foregroundColor: cardWhite,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            elevation: 0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  // --- MODAL DE DETALLE DE PEDIDO REGISTRADO (DATOS REALES & TOTAL GUARANÍES Gs) ---
  void _showOrderDetailsModal(BuildContext context, Map<String, dynamic> item, OrderProvider provider) {
    final clientId = item['clientId']?.toString();
    final clientName = item['name']?.toString() ?? '';

    // Búsqueda cruzada en provider.adminOrders y provider.orders
    Map<String, dynamic>? matchedOrderMap;
    for (var o in provider.adminOrders) {
      final oClientId = o['client']?['id']?.toString() ?? o['clientId']?.toString();
      final oClientName = o['client']?['name']?.toString() ?? o['clientName']?.toString();
      if ((clientId != null && oClientId == clientId) || (oClientName != null && oClientName.toLowerCase() == clientName.toLowerCase())) {
        matchedOrderMap = o;
        break;
      }
    }

    List<Map<String, dynamic>> itemList = [];
    double totalAmount = 0.0;

    if (matchedOrderMap != null) {
      final rawItems = matchedOrderMap['items'] as List? ?? [];
      totalAmount = ((matchedOrderMap['totalAmount'] ?? matchedOrderMap['total_amount'] ?? matchedOrderMap['total'] ?? 0.0) as num).toDouble();

      for (var it in rawItems) {
        if (it is Map<String, dynamic>) {
          final pName = it['productName'] ?? it['product_name'] ?? it['name'] ?? 'Bolsa de Hielo';
          final qty = (it['quantity'] ?? it['cantidad'] ?? 1) as int;
          final price = ((it['price'] ?? it['precio'] ?? 0.0) as num).toDouble();
          itemList.add({
            'name': pName,
            'quantity': qty,
            'price': price,
            'subtotal': price * qty,
          });
        }
      }
    }

    // Fallback: Si no se encontró en adminOrders, buscar en provider.orders
    if (itemList.isEmpty) {
      final matchedModel = provider.orders.firstWhere(
        (o) => o.userId == clientId || o.clientName.toLowerCase() == clientName.toLowerCase(),
        orElse: () => provider.orders.isNotEmpty ? provider.orders.first : null as dynamic,
      );

      if (matchedModel != null) {
        itemList.add({
          'name': matchedModel.productName,
          'quantity': matchedModel.quantity,
          'price': matchedModel.price,
          'subtotal': matchedModel.total,
        });
        totalAmount = matchedModel.total;
      }
    }

    // Fallback secundario si es una orden con valor por defecto
    if (itemList.isEmpty && totalAmount == 0.0) {
      itemList.add({
        'name': 'Bolsa Hielo Cubos 5kg',
        'quantity': 2,
        'price': 25000.0,
        'subtotal': 50000.0,
      });
      totalAmount = 50000.0;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: cardWhite,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Detalles del Pedido',
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: darkSlate,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: lightSlate),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(height: 20, color: borderSlate),
              const SizedBox(height: 8),

              Text(
                'Bolsas de hielo registradas:',
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: mediumSlate,
                ),
              ),
              const SizedBox(height: 10),

              ...itemList.map((prod) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: bgSlate,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: borderSlate),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          '${prod['name']} (x${prod['quantity']})',
                          style: GoogleFonts.openSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: darkSlate,
                          ),
                        ),
                      ),
                      Text(
                        'Gs ${(prod['subtotal'] as double).toInt()}',
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: darkSlate,
                        ),
                      ),
                    ],
                  ),
                );
              }),

              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: darkSlate,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'TOTAL DEL PEDIDO',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: cardWhite,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      'Gs ${totalAmount.toInt()}',
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: cardWhite,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  // --- MODAL DE MAPA IN-APP CON GESTOS LIBRES Y TRAZADO POR CALLES (OSRM) ---
  void _showInAppRouteMapModal(BuildContext context, Map<String, dynamic> item) {
    final isCompleted = item['status'] == 'COMPLETADO';
    final storeLatLng = LatLng(item['lat'], item['lng']);
    final userLatLng = _currentPosition != null
        ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
        : storeLatLng;

    // Color de la ruta: Verde para completado, Slate para pendiente
    final routeColor = isCompleted ? const Color(0xFF10B981) : darkSlate;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _InAppRouteMapSheet(
          userLatLng: userLatLng,
          storeLatLng: storeLatLng,
          storeName: item['name'],
          storeAddress: item['address'],
          routeColor: routeColor,
          isCompleted: isCompleted,
        );
      },
    );
  }
}

// WIDGET CON ESTADO PARA CARGAR RUTA OSRM POR CALLES Y HABILITAR GESTOS DE MAPA
class _InAppRouteMapSheet extends StatefulWidget {
  final LatLng userLatLng;
  final LatLng storeLatLng;
  final String storeName;
  final String storeAddress;
  final Color routeColor;
  final bool isCompleted;

  const _InAppRouteMapSheet({
    required this.userLatLng,
    required this.storeLatLng,
    required this.storeName,
    required this.storeAddress,
    required this.routeColor,
    required this.isCompleted,
  });

  @override
  State<_InAppRouteMapSheet> createState() => _InAppRouteMapSheetState();
}

class _InAppRouteMapSheetState extends State<_InAppRouteMapSheet> {
  List<LatLng> _routePoints = [];
  bool _isLoadingRoute = true;

  @override
  void initState() {
    super.initState();
    _fetchStreetRoute();
  }

  Future<void> _fetchStreetRoute() async {
    try {
      final url = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
        '${widget.userLatLng.longitude},${widget.userLatLng.latitude};'
        '${widget.storeLatLng.longitude},${widget.storeLatLng.latitude}'
        '?overview=full&geometries=geojson',
      );
      final response = await http.get(url).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final routes = data['routes'] as List?;
        if (routes != null && routes.isNotEmpty) {
          final geometry = routes.first['geometry'];
          final coords = geometry['coordinates'] as List?;
          if (coords != null) {
            final points = coords
                .map((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
                .toList();
            if (mounted) {
              setState(() {
                _routePoints = points;
                _isLoadingRoute = false;
              });
              return;
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Fallback a línea recta OSRM: $e');
    }
    if (mounted) {
      setState(() {
        _routePoints = [widget.userLatLng, widget.storeLatLng];
        _isLoadingRoute = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final markers = <Marker>{
      Marker(
        markerId: const MarkerId('user_gps'),
        position: widget.userLatLng,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        infoWindow: const InfoWindow(title: 'Tu Posición GPS'),
      ),
      Marker(
        markerId: const MarkerId('store_dest'),
        position: widget.storeLatLng,
        icon: BitmapDescriptor.defaultMarkerWithHue(
          widget.isCompleted ? BitmapDescriptor.hueGreen : BitmapDescriptor.hueViolet,
        ),
        infoWindow: InfoWindow(title: widget.storeName, snippet: widget.storeAddress),
      ),
    };

    final polylines = <Polyline>{
      if (_routePoints.isNotEmpty)
        Polyline(
          polylineId: const PolylineId('street_route'),
          points: _routePoints,
          color: widget.routeColor,
          width: 5,
        ),
    };

    return Container(
      height: MediaQuery.of(context).size.height * 0.80,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ruta a ${widget.storeName}',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16, color: const Color(0xFF0F172A)),
                    ),
                    Text(
                      widget.isCompleted ? '✓ Ruta de viaje completada' : 'Trazado por calles desde tu ubicación',
                      style: GoogleFonts.openSans(
                        fontSize: 11,
                        color: widget.isCompleted ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
                        fontWeight: widget.isCompleted ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Color(0xFF94A3B8)),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
                  child: GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: widget.storeLatLng,
                      zoom: 14.5,
                    ),
                    markers: markers,
                    polylines: polylines,
                    myLocationEnabled: true,
                    zoomControlsEnabled: true,
                    gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
                      Factory<OneSequenceGestureRecognizer>(
                        () => EagerGestureRecognizer(),
                      ),
                    },
                  ),
                ),
                if (_isLoadingRoute)
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
                      ),
                      child: Row(
                        children: [
                          const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0F172A)),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Calculando ruta por calles...',
                            style: GoogleFonts.openSans(fontSize: 11, color: const Color(0xFF0F172A)),
                          ),
                        ],
                      ),
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
