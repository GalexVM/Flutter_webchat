import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ConfigurationScreen extends StatefulWidget {
  const ConfigurationScreen({super.key});

  @override
  State<ConfigurationScreen> createState() => _ConfigurationScreenState();
}

class _ConfigurationScreenState extends State<ConfigurationScreen> {
  final Map<String, dynamic> _configChanges = {};
  Map<String, dynamic> _currentConfig = {};
  final Map<String, TextEditingController> _controllers = {};
  bool _isLoading = false;

  // Asegúrate de usar la URL y el puerto correctos donde tengas alojada tu API
  final String _backendUrl = 'http://localhost:8001/configuration';

  @override
  void initState() {
    super.initState();
    _fetchConfig();
  }

  Future<void> _fetchConfig() async {
    setState(() => _isLoading = true);
    try {
      final response = await http.get(Uri.parse(_backendUrl));
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        setState(() {
          _currentConfig = data;
          _configChanges.clear();
          // Actualizar los controladores de texto si ya estaban inicializados
          _currentConfig.forEach((key, value) {
            if (_controllers.containsKey(key)) {
              if (key == 'phrases_to_avoid' && value is List) {
                _controllers[key]!.text = value.join(', ');
              } else if (value is Map || value is List) {
                _controllers[key]!.text = json.encode(value);
              } else {
                _controllers[key]!.text = value?.toString() ?? '';
              }
            }
          });
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al cargar configuración: ${response.statusCode}')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error de conexión al cargar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  bool _areEqual(dynamic a, dynamic b) {
    if (a == b) return true;
    if (a == null && b is String && b.isEmpty) return true;
    if (b == null && a is String && a.isEmpty) return true;
    if (a is String && b is String) return a.trim() == b.trim();
    if (a is String && b is List) return a.trim() == b.join(', ').trim();
    if (a is List && b is List) {
      if (a.length != b.length) return false;
      for (int i = 0; i < a.length; i++) {
        if (!_areEqual(a[i], b[i])) return false;
      }
      return true;
    }
    if (a is Map && b is Map) {
      if (a.length != b.length) return false;
      for (var key in a.keys) {
        if (!b.containsKey(key)) return false;
        if (!_areEqual(a[key], b[key])) return false;
      }
      return true;
    }
    return false;
  }

  void _updateField(String key, dynamic value) {
    setState(() {
      if (_areEqual(value, _currentConfig[key])) {
        _configChanges.remove(key);
      } else {
        _configChanges[key] = value;
      }
    });
  }

  void _updateDictField(String dictName, String key, int? value) {
    setState(() {
      dynamic originalDict = _currentConfig[dictName];
      int? originalValue;
      if (originalDict is Map && originalDict.containsKey(key)) {
        originalValue = originalDict[key] as int?;
      }

      if (value == originalValue) {
        if (_configChanges.containsKey(dictName)) {
          final map = _configChanges[dictName] as Map<String, dynamic>;
          map.remove(key);
          if (map.isEmpty) {
            _configChanges.remove(dictName);
          }
        }
      } else {
        if (!_configChanges.containsKey(dictName)) {
          _configChanges[dictName] = <String, dynamic>{};
        }
        final map = _configChanges[dictName] as Map<String, dynamic>;
        map[key] = value;
      }
    });
  }

  Future<void> _submitConfig() async {
    if (_configChanges.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay cambios para enviar.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final payload = Map<String, dynamic>.from(_configChanges);
    final jsonKeys = ['FAC', 'ranges_predefined', 'configuration_list_summary', 'range_available_visit', 'positive_accions', 'negative_accions', 'negative_decay', 'project_event', 'scoring_intents', 'lead_score'];

    for (var key in jsonKeys) {
      if (payload.containsKey(key) && payload[key] is String) {
        try {
          payload[key] = json.decode(payload[key]);
        } catch (e) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: El campo $key no tiene un formato JSON válido.')),
          );
          return;
        }
      }
    }

    final keysToRemove = <String>[];
    payload.forEach((key, value) {
      if (_areEqual(value, _currentConfig[key])) {
        keysToRemove.add(key);
      }
    });

    for (var key in keysToRemove) {
      payload.remove(key);
      _configChanges.remove(key);
    }

    if (payload.isEmpty) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay cambios reales para enviar.')),
      );
      return;
    }

    try {
      print('=== PAYLOAD A ENVIAR ===');
      print(json.encode(payload));
      print('========================');
      
      final response = await http.put(
        Uri.parse(_backendUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(payload),
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Configuración actualizada correctamente.')),
        );
        await _fetchConfig(); // Recargar los valores para que el UI refleje el nuevo estado base
      } else {
        if (!mounted) return;
        // Mostrar un resumen del body del error para ayudar a depurar
        final errorBody = response.body.length > 100 ? '${response.body.substring(0, 100)}...' : response.body;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error ${response.statusCode}: $errorBody')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error de conexión: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildSection(String title, List<Widget> children) {
    List<Widget> rows = [];
    // Convertimos la lista de hijos simples a una lista de filas de 2 columnas.
    for (int i = 0; i < children.length; i += 2) {
      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: children[i]),
              const SizedBox(width: 16),
              Expanded(
                child: i + 1 < children.length ? children[i + 1] : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16.0),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF075E54))),
            const Divider(),
            const SizedBox(height: 8.0),
            ...rows,
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(String key, String label, {bool isNumber = false, int maxLines = 1}) {
    _controllers.putIfAbsent(key, () {
      final val = _currentConfig[key];
      return TextEditingController(text: val?.toString() ?? '');
    });
    return TextFormField(
      controller: _controllers[key],
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        filled: true,
        fillColor: Colors.grey[50],
        isDense: true,
      ),
      onChanged: (val) {
        if (val.isEmpty) {
          _updateField(key, null);
        } else {
          _updateField(key, isNumber ? (int.tryParse(val) ?? val) : val);
        }
      },
    );
  }

  Widget _buildBoolDropdown(String key, String label) {
    bool? currentValue;
    if (_configChanges.containsKey(key)) {
      currentValue = _configChanges[key] as bool?;
    } else if (_currentConfig.containsKey(key)) {
      currentValue = _currentConfig[key] as bool?;
    }

    return DropdownButtonFormField<bool?>(
      value: currentValue,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        filled: true,
        fillColor: Colors.grey[50],
        isDense: true,
      ),
      items: const [
        DropdownMenuItem(value: null, child: Text("No definido / Restablecer", overflow: TextOverflow.ellipsis)),
        DropdownMenuItem(value: true, child: Text("Activado (True)", overflow: TextOverflow.ellipsis)),
        DropdownMenuItem(value: false, child: Text("Desactivado (False)", overflow: TextOverflow.ellipsis)),
      ],
      onChanged: (val) => _updateField(key, val),
    );
  }

  Widget _buildCommaSeparatedListField(String key, String label, {int maxLines = 1}) {
    _controllers.putIfAbsent(key, () {
      final val = _currentConfig[key];
      String text = '';
      if (val is List) {
        text = val.join(', ');
      } else if (val != null) {
        text = val.toString();
      }
      return TextEditingController(text: text);
    });
    return TextFormField(
      controller: _controllers[key],
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: '$label (Separadas por comas)',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        filled: true,
        fillColor: Colors.grey[50],
        isDense: true,
      ),
      onChanged: (val) {
        if (val.trim().isEmpty) {
          _updateField(key, null);
        } else {
          // Se envía el string directamente con sus comas, sin convertir a lista
          _updateField(key, val.trim());
        }
      },
    );
  }

  Widget _buildStringDropdown(String key, String label, List<String> options) {
    String? currentValue;
    if (_configChanges.containsKey(key)) {
      currentValue = _configChanges[key] as String?;
    } else if (_currentConfig.containsKey(key)) {
      currentValue = _currentConfig[key] as String?;
    }

    // Si el valor actual no está en la lista de opciones (ej. error en BD), mostramos null para evitar crasheos visuales.
    if (currentValue != null && !options.contains(currentValue)) {
      currentValue = null;
    }

    return DropdownButtonFormField<String?>(
      value: currentValue,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        filled: true,
        fillColor: Colors.grey[50],
        isDense: true,
      ),
      items: [
        const DropdownMenuItem(value: null, child: Text("No definido / Restablecer", overflow: TextOverflow.ellipsis)),
        ...options.map((val) => DropdownMenuItem(value: val, child: Text(val, overflow: TextOverflow.ellipsis))),
      ],
      onChanged: (val) => _updateField(key, val),
    );
  }

  Widget _buildJsonField(String key, String label) {
    _controllers.putIfAbsent(key, () {
      final val = _currentConfig[key];
      final text = val != null ? json.encode(val) : '';
      return TextEditingController(text: text);
    });
    return TextFormField(
      controller: _controllers[key],
      maxLines: 3,
      decoration: InputDecoration(
        labelText: '$label (Formato JSON válido)',
        hintText: 'Ej: {"clave": valor}',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        filled: true,
        fillColor: Colors.grey[50],
        isDense: true,
      ),
      onChanged: (val) {
        if (val.isEmpty) {
          _updateField(key, null);
        } else {
          _configChanges[key] = val; // Se procesará a JSON al enviar
        }
      },
    );
  }

  Widget _buildDictDropdown(String dictName, String key, String label) {
    int? currentValue;
    if (_configChanges.containsKey(dictName) && (_configChanges[dictName] as Map).containsKey(key)) {
      currentValue = (_configChanges[dictName] as Map)[key] as int?;
    } else if (_currentConfig.containsKey(dictName) && _currentConfig[dictName] != null && (_currentConfig[dictName] as Map).containsKey(key)) {
      currentValue = (_currentConfig[dictName] as Map)[key] as int?;
    }

    return DropdownButtonFormField<int?>(
      value: currentValue,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        filled: true,
        fillColor: Colors.grey[50],
        isDense: true,
      ),
      items: [
        const DropdownMenuItem(value: null, child: Text("No definido / Restablecer", overflow: TextOverflow.ellipsis)),
        // Genera valores del 0 al 20 para elegir la puntuación
        ...List.generate(21, (index) => index).map((val) => 
          DropdownMenuItem(value: val, child: Text(val.toString()))
        ),
      ],
      onChanged: (val) => _updateDictField(dictName, key, val),
    );
  }

  @override
  void dispose() {
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFECE5DD),
      appBar: AppBar(
        backgroundColor: const Color(0xFF075E54),
        title: const Text('Configuración del Chatbot', style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Recargar configuración',
            onPressed: _isLoading ? null : _fetchConfig,
          ),
          IconButton(
            icon: const Icon(Icons.save, color: Colors.white),
            tooltip: 'Guardar Cambios',
            onPressed: _isLoading ? null : _submitConfig,
          )
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator()) 
        : ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildSection('Textos y Nombres', [
            _buildTextField('company_name', 'Nombre Compañía'),
            _buildTextField('chatbot_name', 'Nombre Chatbot'),
            _buildTextField('fallback_agent', 'Agente Respaldo'),
            _buildTextField('fallback_main_activity', 'Actividad Principal Respaldo'),
            _buildTextField('fallback_urgent_activity', 'Actividad Urgente Respaldo'),
            _buildTextField('fallback_urgent_tag', 'Etiqueta Urgente Respaldo'),
            _buildTextField('personality_prompt', 'Prompt de Personalidad', maxLines: 4),
            _buildStringDropdown('writing_tone', 'Tono de Escritura', ['POLITE', 'REGULAR']),
            _buildCommaSeparatedListField('phrases_to_avoid', 'Frases a Evitar', maxLines: 3),
            _buildStringDropdown('price_policy', 'Política de Precios', ['RANGE', 'NONE', 'STARTING_FROM', 'EXACT']),
          ]),
          
          _buildSection('Tiempos y Números', [
            _buildTextField('user_session_window', 'Ventana Sesión (seg)', isNumber: true),
            _buildTextField('info_refresh_time', 'Refresco Info (min)', isNumber: true),
            _buildTextField('appointment_duration', 'Duración Cita (min)', isNumber: true),
            _buildTextField('blacklist_short_timeout', 'Timeout Corto Blacklist (hrs)', isNumber: true),
            _buildTextField('blacklist_large_timeout', 'Timeout Largo Blacklist (hrs)', isNumber: true),
          ]),
          
          _buildSection('Características y Permisos', [
            _buildBoolDropdown('uses_google_calendar', 'Usa Google Calendar'),
            _buildBoolDropdown('gives_average_space_metrics', 'Da Métricas Espacio Prom.'),
            _buildBoolDropdown('gives_average_prices', 'Da Precios Promedio'),
            _buildBoolDropdown('gives_price_per_m2', 'Da Precio por m2'),
            _buildBoolDropdown('gives_number_of_unities_available', 'Da Núm. Unidades Disp.'),
            _buildBoolDropdown('gives_if_available_unities', 'Informa si hay Disp.'),
            _buildBoolDropdown('gives_start_date', 'Da Fecha Inicio'),
            _buildBoolDropdown('gives_end_date', 'Da Fecha Fin'),
            _buildBoolDropdown('gives_views', 'Da Vistas'),
            _buildBoolDropdown('gives_number_blocks_or_levels', 'Da Núm. Bloques/Niveles'),
            _buildBoolDropdown('gives_location', 'Da Ubicación'),
            _buildBoolDropdown('send_brochures', 'Envía Folletos'),
            _buildBoolDropdown('send_pictures', 'Envía Fotos'),
            _buildBoolDropdown('uses_stickers', 'Usa Stickers'),
            _buildBoolDropdown('offers_principal_zones', 'Ofrece Zonas Princip.'),
            _buildBoolDropdown('enabled_scoring', 'Scoring Habilitado'),
            _buildBoolDropdown('shows_assesor_name', 'Muestra Nombre Asesor'),
            _buildBoolDropdown('asks_about_purpose', 'Pregunta Propósito'),
            _buildBoolDropdown('gives_financing', 'Informa Financiamiento'),
            _buildBoolDropdown('enable_name_completed', 'Habilita Captura de Nombre'),
          ]),
          

          _buildSection('Configuración de Presupuesto', [
            _buildBoolDropdown('enable_budget', 'Habilitar Presupuesto'),
            _buildBoolDropdown('ask_budget', 'Preguntar Presupuesto'),
            _buildStringDropdown('budget_mode', 'Modo Presupuesto', ['text', 'range']),
            _buildJsonField('ranges_predefined', 'Rangos Predefinidos'),
          ]),

          _buildSection('Configuración Avanzada (JSON)', [
            _buildJsonField('FAC', 'FAC (Lista strings)'),
            _buildBoolDropdown('chooses_activity', 'Elige Actividad'),
          ]),

          _buildSection('Lead Score (Puntuación de Leads)', [
            _buildDictDropdown('lead_score', 'zone', 'Zona (zone)'),
            _buildDictDropdown('lead_score', 'budget', 'Presupuesto (budget)'),
            _buildDictDropdown('lead_score', 'urgency', 'Urgencia (urgency)'),
            _buildDictDropdown('lead_score', 'date', 'Fecha (date)'),
          ]),

          _buildSection('Scoring de Intenciones', [
            _buildDictDropdown('scoring_intents', 'schedule_visit', 'Agendar Visita'),
            _buildDictDropdown('scoring_intents', 'consult_location', 'Consultar Ubicación'),
            _buildDictDropdown('scoring_intents', 'greeting', 'Saludo'),
          ]),

          _buildSection('Acciones Positivas', [
            _buildDictDropdown('positive_accions', 'wants_info_or_price', 'Información o Precio'),
            _buildDictDropdown('positive_accions', 'wants_location', 'Ubicación'),
            _buildDictDropdown('positive_accions', 'wants_footage', 'Metraje'),
            _buildDictDropdown('positive_accions', 'wants_multimedia', 'Multimedia'),
            _buildDictDropdown('positive_accions', 'greeting', 'Saludo'),
          ]),

          _buildSection('Acciones Negativas', [
            _buildDictDropdown('negative_accions', 'greeting', 'Saludo'),
            _buildDictDropdown('negative_accions', 'reject_visit', 'Rechaza Visita'),
            _buildDictDropdown('negative_accions', 'low_intent', 'Baja Intención'),
          ]),

          _buildSection('Decaimiento Negativo (Horas)', [
            _buildDictDropdown('negative_decay', '1', '1 Hora'),
            _buildDictDropdown('negative_decay', '2', '2 Horas'),
            _buildDictDropdown('negative_decay', '6', '6 Horas'),
            _buildDictDropdown('negative_decay', '24', '24 Horas'),
          ]),

          _buildSection('Eventos de Proyecto', [
            _buildDictDropdown('project_event', 'asked_price', 'Preguntó Precio'),
            _buildDictDropdown('project_event', 'asked_features', 'Preguntó Características'),
            _buildDictDropdown('project_event', 'asked_multimedia', 'Preguntó Multimedia'),
          ]),

          _buildSection('Resumen Automático', [
            _buildBoolDropdown('automatic_summary', 'Resumen Automático'),
            _buildJsonField('configuration_list_summary', 'Configuración Lista Resumen'),
          ]),

          _buildSection('Agendamiento de Visitas', [
            _buildBoolDropdown('enable_module_visit', 'Habilitar Módulo de Visitas'),
            _buildTextField('days_available_visit', 'Días Disponibles Visita', isNumber: true),
            _buildTextField('duration_date', 'Duración Cita (min)', isNumber: true),
            _buildJsonField('range_available_visit', 'Rango Horario Disponible'),
            _buildTextField('scheduling_message_completed', 'Mensaje Agendamiento Completo', maxLines: 2),
            _buildBoolDropdown('enabled_message_visit', 'Habilitar Mensaje de Visita'),
            _buildTextField('seleccion_mode_date', 'Modo Selección Fecha'),
          ]),

          _buildSection('Control y Contacto', [
            _buildTextField('recontact_hours', 'Horas para Recontacto', isNumber: true),
            _buildTextField('recontact_times', 'Nº de Intentos de Recontacto', isNumber: true),
            _buildTextField('flood_max_messages', 'Máx. Mensajes (Flood)', isNumber: true),
            _buildTextField('flood_window_seconds', 'Ventana (seg) (Flood)', isNumber: true),
            _buildTextField('flood_cooldown_seconds', 'Enfriamiento (seg) (Flood)', isNumber: true),
          ]),

          _buildSection('Sistema (Solo para desarrolladores)', [
            _buildTextField('fallback_agent', 'Agente de Respaldo (ID)'),
            _buildTextField('model_smart_llm', 'Modelo LLM Inteligente'),
            _buildTextField('model_fast_llm', 'Modelo LLM Rápido'),
            _buildTextField('toker_per_response', 'Tokens por Respuesta', isNumber: true),
            _buildTextField('count_messages_by_lead', 'Conteo Mensajes por Lead', isNumber: true),
            _buildBoolDropdown('enable_persist_leads_job', 'Habilitar Persistencia de Leads'),
          ]),


          const SizedBox(height: 20),
          Center(
            child: ElevatedButton.icon(
              icon: const Icon(Icons.send),
              label: const Text('Enviar Actualización'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF075E54),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _isLoading ? null : _submitConfig,
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}