import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:mongo_dart/mongo_dart.dart' as mongo;
import 'configuration_screen.dart';

void main() {
  runApp(const ChatApp());
}

// Un modelo simple para representar un mensaje en el chat
class ChatMessage {
  final String text;
  final bool isUser;
  ChatMessage({required this.text, required this.isUser});
}

class ChatApp extends StatelessWidget {
  const ChatApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Chat Demo',
      theme: ThemeData(
        primaryColor: const Color(0xFF075E54),
        colorScheme: ColorScheme.fromSwatch().copyWith(
          primary: const Color(0xFF075E54),
          secondary: const Color(0xFF25D366),
        ),
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const MainScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final TextEditingController _userIdController = TextEditingController(
    text: '123456789',
  );
  final List<ChatMessage> _messages = [];
  final ScrollController _scrollController = ScrollController();

  final String _backendUrl =
      'https://5b7d-45-177-196-205.ngrok-free.app/rag/query';

  Future<void> _sendMessage() async {
    if (_controller.text.isEmpty) return;
    setState(() {
      _messages.add(ChatMessage(text: _controller.text, isUser: true));
    });
    final textToSend = _controller.text;
    _controller.clear();
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
    try {
      final uri = Uri.parse(_backendUrl).replace(queryParameters: {
        'query': textToSend,
        'phone_id': _userIdController.text,
        'chunks': '500',
      });

      print('DEBUG: Enviando petición a: $uri');

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
      );

      print('DEBUG: Respuesta recibida. Código: ${response.statusCode}');
      print('DEBUG: Cuerpo de la respuesta: ${response.body}');

      if (response.statusCode == 200) {
        final decodedBody = json.decode(response.body);
        final messageText = decodedBody['response']['response']['response'];
        setState(() {
          _messages.add(
            ChatMessage(
              text: messageText,
              isUser: false,
            ),
          );
        });
      } else {
        // Error del lado del servidor (ej. 404, 500)
        setState(() {
          _messages.add(
            ChatMessage(
              text: 'Error del servidor: ${response.statusCode}. Revisa la consola de depuración para más detalles.',
              isUser: false,
            ),
          );
        });
      }
    } catch (e) {
      // Error de conexión o al procesar la respuesta (ej. JSON malformado, tipo incorrecto)
      print('DEBUG: Ha ocurrido una excepción: $e');
      setState(() {
        _messages.add(
          ChatMessage(
            text: 'Error: No se pudo procesar la respuesta. Revisa la consola de depuración.',
            isUser: false,
          ),
        );
      });
    }
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  void _clearChat() {
    setState(() {
      _messages.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFECE5DD),
      appBar: AppBar(
        backgroundColor: const Color(0xFF075E54),
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.asset(
                'assets/logo.png',
                height: 40,
                width: 40,
                fit: BoxFit.cover,
                errorBuilder: (c, e, s) =>
                    const Icon(Icons.person, color: Colors.white),
              ),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'IA Service',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Pre Alfa',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
            const Spacer(),
            SizedBox(
              width: 140,
              child: TextField(
                controller: _userIdController,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: const InputDecoration(
                  labelText: 'ID',
                  labelStyle: TextStyle(color: Colors.white70),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.white54),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.white),
                  ),
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            IconButton(
              icon: const Icon(Icons.delete_sweep, color: Colors.white),
              tooltip: 'Limpiar chat',
              onPressed: _clearChat,
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 4.0,
                    horizontal: 14.0,
                  ),
                  child: Align(
                    alignment: message.isUser
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Container(
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.75,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: message.isUser
                            ? const Color(0xFFDCF8C6)
                            : Colors.white,
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(12),
                          topRight: const Radius.circular(12),
                          bottomLeft: Radius.circular(message.isUser ? 12 : 0),
                          bottomRight: Radius.circular(message.isUser ? 0 : 12),
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 1,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Text(
                        message.text,
                        style: const TextStyle(
                          fontSize: 16.0,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            color: Colors.transparent,
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24.0),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 1,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _controller,
                      decoration: const InputDecoration(
                        hintText: 'Mensaje',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 20.0,
                          vertical: 14.0,
                        ),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                ),
                const SizedBox(width: 8.0),
                CircleAvatar(
                  backgroundColor: const Color(0xFF128C7E),
                  radius: 24,
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white),
                    onPressed: _sendMessage,
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

// ==========================================
// ARQUITECTURA HEXAGONAL: DOMINIO Y PUERTOS
// ==========================================

class ChatMessageDomain {
  final String role;
  final String content;
  final DateTime timestamp;

  ChatMessageDomain({
    required this.role,
    required this.content,
    required this.timestamp,
  });
}

class ChatConversation {
  final String id;
  final String userId;
  final List<ChatMessageDomain> history;

  ChatConversation({
    required this.id,
    required this.userId,
    required this.history,
  });

  DateTime? get lastMessageDate {
    if (history.isEmpty) return null;
    return history.last.timestamp;
  }
}

abstract class ChatRepository {
  Future<List<ChatConversation>> getConversations();
}

// ==========================================
// ARQUITECTURA HEXAGONAL: ADAPTADORES
// ==========================================

class MongoChatRepository implements ChatRepository {
  final String connectionString;
  final String collectionName;

  MongoChatRepository({
    required this.connectionString,
    required this.collectionName,
  });

  @override
  Future<List<ChatConversation>> getConversations() async {
    final db = await mongo.Db.create(connectionString);
    await db.open();
    final coll = db.collection(collectionName);

    // Traemos los documentos ordenados por ID (o podrías hacerlo por fecha)
    final docs = await coll.find().toList();
    await db.close();

    return docs
        .map<ChatConversation?>((doc) {
          // Especificamos que el map puede devolver null
          final String? userId = doc['user_id'] as String?;

          // Si user_id es nulo o vacío, no creamos la conversación
          if (userId == null || userId.isEmpty) {
            return null;
          }

          final historyList = (doc['history'] as List?) ?? [];
          final history = historyList.map((msg) {
            return ChatMessageDomain(
              role: msg['role'] ?? 'user',
              content: msg['content'] ?? '',
              timestamp:
                  DateTime.tryParse(msg['timestamp'] ?? '') ?? DateTime.now(),
            );
          }).toList();

          return ChatConversation(
            id: doc['_id'].toString(),
            userId:
                userId, // Usamos el userId que ya sabemos que no es nulo ni vacío
            history: history,
          );
        })
        .whereType<ChatConversation>()
        .toList(); // Filtramos los valores nulos antes de convertir a lista
  }
}

// ==========================================
// INTERFAZ GRÁFICA: NUEVAS VISTAS
// ==========================================

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  // Inyección de dependencias (Se inyecta el Adaptador en el Puerto)
  // TODO: REEMPLAZA ESTA URI Y COLECCIÓN CON TUS DATOS DE MONGODB
  final ChatRepository _chatRepository = MongoChatRepository(
    //connectionString: 'mongodb://rvadmin:RvSuperSecure%232025@62.171.141.232:27017/chatbot_db?authSource=admin',
    connectionString:
        'mongodb://navia:Zefiron1!@localhost:27018/chatbot_db?authSource=admin',
    collectionName: 'conversations',
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // IndexedStack permite mantener vivas ambas pestañas sin borrar el texto ingresado
      body: IndexedStack(
        index: _currentIndex,
        children: [
          const ChatScreen(), // Tab 0: El webchat original que ya tenías
          HistoryListScreen(repository: _chatRepository), // Tab 1: Nueva vista
          const ConfigurationScreen(), // Tab 2: Nueva vista de configuración
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.white,
        selectedItemColor: const Color(0xFF075E54),
        unselectedItemColor: Colors.grey,
        currentIndex: _currentIndex,
        type: BottomNavigationBarType.fixed,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'Chat Actual'),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'Auditoría DB',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Configuración',
          ),
        ],
      ),
    );
  }
}

class HistoryListScreen extends StatefulWidget {
  final ChatRepository repository;
  const HistoryListScreen({super.key, required this.repository});

  @override
  State<HistoryListScreen> createState() => _HistoryListScreenState();
}

class _HistoryListScreenState extends State<HistoryListScreen> {
  late Future<List<ChatConversation>> _futureConversations;

  @override
  void initState() {
    super.initState();
    _loadConversations();
  }

  void _loadConversations() {
    setState(() {
      _futureConversations = widget.repository.getConversations();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF075E54),
        title: const Text(
          'Historial de Conversaciones',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Sincronizar ahora',
            onPressed: _loadConversations, // Botón de Refresh
          ),
        ],
      ),
      body: FutureBuilder<List<ChatConversation>>(
        future: _futureConversations,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error al conectar con la BD:\n${snapshot.error}',
                textAlign: TextAlign.center,
              ),
            );
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text(
                'No hay conversaciones en la base de datos.',
                style: TextStyle(fontSize: 18),
              ),
            );
          }

          final chats = snapshot.data!;
          return ListView.builder(
            itemCount: chats.length,
            itemBuilder: (context, index) {
              final chat = chats[index];
              final lastDate = chat.lastMessageDate;
              final dateStr = lastDate != null
                  ? '${lastDate.day}/${lastDate.month}/${lastDate.year} ${lastDate.hour}:${lastDate.minute.toString().padLeft(2, '0')}'
                  : 'Sin mensajes';

              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.grey[300],
                  child: const Icon(
                    Icons.person,
                    color: Colors.white,
                    size: 30,
                  ),
                  radius: 24,
                ),
                title: Text(
                  chat.userId,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                subtitle: Text(
                  'Último mensaje: $dateStr',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          ReadOnlyChatScreen(conversation: chat),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class ReadOnlyChatScreen extends StatelessWidget {
  final ChatConversation conversation;
  const ReadOnlyChatScreen({super.key, required this.conversation});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFECE5DD),
      appBar: AppBar(
        backgroundColor: const Color(0xFF075E54),
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          'Historial - ID: ${conversation.userId}',
          style: const TextStyle(color: Colors.white),
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(10),
        itemCount: conversation.history.length,
        itemBuilder: (context, index) {
          final message = conversation.history[index];
          final isUser = message.role == 'user'; // Lógica para separar estilos

          return Padding(
            padding: const EdgeInsets.symmetric(
              vertical: 4.0,
              horizontal: 14.0,
            ),
            child: Align(
              alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.75,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isUser ? const Color(0xFFDCF8C6) : Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(12),
                    topRight: const Radius.circular(12),
                    bottomLeft: Radius.circular(isUser ? 12 : 0),
                    bottomRight: Radius.circular(isUser ? 0 : 12),
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 1,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
                child: Text(
                  message.content,
                  style: const TextStyle(fontSize: 16.0, color: Colors.black87),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
