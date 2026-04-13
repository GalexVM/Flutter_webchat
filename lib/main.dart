import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

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
      home: const ChatScreen(),
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
        body: json.encode({'message': textToSend}),
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
