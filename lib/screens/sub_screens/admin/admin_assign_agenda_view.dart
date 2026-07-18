import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../providers/order_provider.dart';
import '../shared/widgets/build_avatar_helper.dart';

class AdminAssignAgendaView extends StatefulWidget {
  final Map<String, dynamic> preventista;
  const AdminAssignAgendaView({super.key, required this.preventista});

  @override
  State<AdminAssignAgendaView> createState() => _AdminAssignAgendaViewState();
}

class _AdminAssignAgendaViewState extends State<AdminAssignAgendaView> {
  DateTime _selectedDate = DateTime.now();
  final List<String> _selectedClientIds = [];
  String _searchQuery = '';
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<OrderProvider>(context, listen: false).fetchClientes();
    });
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF4F46E5),
              onPrimary: Colors.white,
              onSurface: Color(0xFF0F172A),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<OrderProvider>(context);
    final preventistaName = widget.preventista['full_name'] ?? widget.preventista['fullName'] ?? 'Preventista';
    final preventistaId = widget.preventista['id'] as String;

    final filteredClientes = provider.clientes.where((client) {
      final name = (client['name'] as String? ?? '').toLowerCase();
      final owner = (client['owner_name'] as String? ?? '').toLowerCase();
      final address = (client['address'] as String? ?? '').toLowerCase();
      final query = _searchQuery.toLowerCase();
      return name.contains(query) || owner.contains(query) || address.contains(query);
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF0F172A), size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Asignar Agenda',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: const Color(0xFF0F172A),
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Preventista Info & Date Selection Card
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    buildAvatarHelper(
                      preventistaName,
                      widget.preventista['avatar_url'] as String?,
                      radius: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            preventistaName,
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                          Text(
                            'Rol: Preventista',
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Divider(color: Color(0xFFE2E8F0)),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const HugeIcon(
                          icon: HugeIcons.strokeRoundedCalendar04,
                          color: Color(0xFF4F46E5),
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          DateFormat('dd/MM/yyyy').format(_selectedDate),
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                    TextButton(
                      onPressed: () => _selectDate(context),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF4F46E5),
                      ),
                      child: Text(
                        'Cambiar Fecha',
                        style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Clients Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              onChanged: (val) {
                setState(() {
                  _searchQuery = val;
                });
              },
              decoration: InputDecoration(
                hintText: 'Buscar clientes...',
                hintStyle: GoogleFonts.outfit(color: const Color(0xFF94A3B8), fontSize: 14),
                prefixIcon: const Icon(Icons.search, color: Color(0xFF94A3B8)),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 1.5),
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Clients List
          Expanded(
            child: provider.clientes.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : filteredClientes.isEmpty
                    ? Center(
                        child: Text(
                          'No se encontraron clientes',
                          style: GoogleFonts.outfit(color: const Color(0xFF64748B)),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: filteredClientes.length,
                        itemBuilder: (context, index) {
                          final client = filteredClientes[index];
                          final id = client['id'] as String;
                          final name = client['name'] ?? 'Cliente';
                          final owner = client['owner_name'] ?? 'Propietario';
                          final address = client['address'] ?? 'Sin dirección';
                          final isSelected = _selectedClientIds.contains(id);

                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected ? const Color(0xFF4F46E5) : const Color(0xFFE2E8F0),
                                width: isSelected ? 1.5 : 1.0,
                              ),
                            ),
                            child: CheckboxListTile(
                              activeColor: const Color(0xFF4F46E5),
                              value: isSelected,
                              onChanged: (bool? checked) {
                                setState(() {
                                  if (checked == true) {
                                    _selectedClientIds.add(id);
                                  } else {
                                    _selectedClientIds.remove(id);
                                  }
                                });
                              },
                              title: Text(
                                name,
                                style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: const Color(0xFF0F172A),
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    owner,
                                    style: GoogleFonts.outfit(
                                      fontSize: 12,
                                      color: const Color(0xFF64748B),
                                    ),
                                  ),
                                  Text(
                                    address,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.outfit(
                                      fontSize: 12,
                                      color: const Color(0xFF94A3B8),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),

          // Bottom Action Button
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _selectedClientIds.isEmpty || _isSaving
                    ? null
                    : () async {
                        setState(() {
                          _isSaving = true;
                        });

                        final success = await provider.assignAgenda(
                          preventistaId: preventistaId,
                          date: _selectedDate,
                          clientIds: _selectedClientIds,
                        );

                        setState(() {
                          _isSaving = false;
                        });

                        if (mounted) {
                          if (success) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Agenda asignada con éxito a $preventistaName',
                                  style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                                ),
                                backgroundColor: const Color(0xFF10B981),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                            Navigator.pop(context);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Error al asignar agenda. Verifique la conexión.',
                                  style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                                ),
                                backgroundColor: const Color(0xFFEF4444),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  disabledBackgroundColor: const Color(0xFFCBD5E1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : Text(
                        'Asignar Agenda (${_selectedClientIds.length} seleccionados)',
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
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
