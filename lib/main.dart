import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:mongo_dart/mongo_dart.dart' as mongo;

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
        primarySwatch: Colors.blue,
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
  final TextEditingController _userIdController = TextEditingController(text: '123456789');
  final List<ChatMessage> _messages = [];
  final ScrollController _scrollController = ScrollController();

  final String _backendUrl = 'http://localhost:8001/consulta-webchat';

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
      final response = await http.post(
        Uri.parse(_backendUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'message': textToSend, 'user_id': _userIdController.text}),
      );
      if (response.statusCode == 200) {
        setState(() {
          _messages.add(ChatMessage(text: json.decode(response.body)['response'], isUser: false));
        });
      } else {
        // Error del lado del servidor (ej. 404, 500)
        setState(() {
          _messages.add(ChatMessage(text: 'Error del servidor: ${response.statusCode}', isUser: false));
        });
      }
    } catch (e) {
      // Error de conexión o al procesar la respuesta (ej. JSON malformado, tipo incorrecto)
      setState(() {
        _messages.add(ChatMessage(text: 'Error: No se pudo procesar la respuesta del servidor.', isUser: false));
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
      appBar: AppBar(
        backgroundColor: const Color(0xFF111111),
        title: Row(
          children: [
            // Asegúrate de que la ruta coincida con la ubicación de tu logo
            Image.asset('assets/logo.png', height: 120), // Altura ajustada para el AppBar
            const SizedBox(width: 30),
            const Text(
              'IA Service Chat. Pre Alfa.',
              style: TextStyle(
                color: Colors.white,
              ),
            ),
            const Spacer(),
            SizedBox(
              width: 200,
              child: TextField(
                controller: _userIdController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Número emisor (user_id)',
                  labelStyle: TextStyle(color: Colors.white70),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.white54),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.white),
                  ),
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
      body:
      Column(
        children: [
        Expanded(
          child:
          ListView.builder(
            controller: _scrollController,
            itemCount: _messages.length,
            itemBuilder: (context, index) {
              final message = _messages[index];
              return ListTile(
                title: Align(
                  alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child:
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: message.isUser ? Colors.blue[100] : Colors.grey[200],
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(message.text, style: const TextStyle(fontSize: 25.0)), // Aumentado el tamaño de la fuente
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child:
          Row(
            children: [
            Expanded(
              child:
              TextField(
                controller: _controller,
                decoration: const InputDecoration(hintText: 'Escribe un mensaje...'),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.send),
              onPressed: _sendMessage,
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

  ChatMessageDomain({required this.role, required this.content, required this.timestamp});
}

class ChatConversation {
  final String id;
  final String userId;
  final List<ChatMessageDomain> history;

  ChatConversation({required this.id, required this.userId, required this.history});

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

  MongoChatRepository({required this.connectionString, required this.collectionName});

  @override
  Future<List<ChatConversation>> getConversations() async {
    final db = await mongo.Db.create(connectionString);
    await db.open();
    final coll = db.collection(collectionName);
    
    // Traemos los documentos ordenados por ID (o podrías hacerlo por fecha)
    final docs = await coll.find().toList();
    await db.close();

    return docs.map<ChatConversation?>((doc) { // Especificamos que el map puede devolver null
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
          timestamp: DateTime.tryParse(msg['timestamp'] ?? '') ?? DateTime.now(),
        );
      }).toList();

      return ChatConversation(
        id: doc['_id'].toString(),
        userId: userId, // Usamos el userId que ya sabemos que no es nulo ni vacío
        history: history,
      );
    }).whereType<ChatConversation>().toList(); // Filtramos los valores nulos antes de convertir a lista
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
    connectionString: 'mongodb://navia:Zefiron1!@localhost:27017/chatbot_db?authSource=admin',
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
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: const Color(0xFF111111),
        selectedItemColor: Colors.blue[300],
        unselectedItemColor: Colors.white54,
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'Chat Actual'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'Auditoría DB'),
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
        backgroundColor: const Color(0xFF111111),
        title: const Text('Historial de Conversaciones', style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Sincronizar ahora',
            onPressed: _loadConversations, // Botón de Refresh
          )
        ],
      ),
      body: FutureBuilder<List<ChatConversation>>(
        future: _futureConversations,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error al conectar con la BD:\n${snapshot.error}', textAlign: TextAlign.center));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No hay conversaciones en la base de datos.', style: TextStyle(fontSize: 18)));
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
                  backgroundColor: Colors.blue[100],
                  child: const Icon(Icons.person, color: Colors.blueGrey),
                ),
                title: Text('Usuario: ${chat.userId}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                subtitle: Text('Último mensaje: $dateStr'),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => ReadOnlyChatScreen(conversation: chat)),
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
      appBar: AppBar(
        backgroundColor: const Color(0xFF111111),
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text('Historial - ID: ${conversation.userId}', style: const TextStyle(color: Colors.white)),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(10),
        itemCount: conversation.history.length,
        itemBuilder: (context, index) {
          final message = conversation.history[index];
          final isUser = message.role == 'user'; // Lógica para separar estilos

          return ListTile(
            title: Align(
              alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isUser ? Colors.blue[100] : Colors.grey[200],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(message.content, style: const TextStyle(fontSize: 25.0)),
              ),
            ),
          );
        },
      ),
    );
  }
}
