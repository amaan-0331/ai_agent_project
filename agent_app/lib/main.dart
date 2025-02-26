import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

const _baseCloudUrl = 'https://finapp-backend-510358572253.us-central1.run.app';

void main() {
  runApp(const StockChatApp());
}

class StockChatApp extends StatelessWidget {
  const StockChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Stock Chat Assistant',
      theme: ThemeData(
        primarySwatch: Colors.green,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const StockChatScreen(),
    );
  }
}

class StockChatScreen extends StatefulWidget {
  const StockChatScreen({super.key});

  @override
  State<StockChatScreen> createState() => _StockChatScreenState();
}

class _StockChatScreenState extends State<StockChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  String? sessionId;

  @override
  void initState() {
    super.initState();
    _startChat();

    // Add initial system message
    _messages.add(
      ChatMessage(
        content:
            "Hello! I can help you find information about companies and analyze "
            "stocks. Try asking about a specific company like \"do you know about "
            "Apple?\"",
        isUser: false,
        isCustomWidget: false,
      ),
    );
  }

  Future<void> _startChat() async {
    try {
      final response = await http.post(
        Uri.parse('$_baseCloudUrl/chat/start'),
        headers: {'Content-Type': 'application/json'},
      );

      final data = jsonDecode(response.body);
      sessionId = data['session_id'];
      debugPrint('Chat session started: $sessionId');
    } catch (error) {
      debugPrint('Error starting chat: $error');
    }
  }

  Future<void> _sendMessage(String message) async {
    if (message.isEmpty) return;

    setState(() {
      _messages.add(ChatMessage(
        content: message,
        isUser: true,
        isCustomWidget: false,
      ));
      _messageController.clear();
    });

    // Scroll to bottom after adding message
    _scrollToBottom();

    try {
      final response = await http.post(
        Uri.parse('$_baseCloudUrl/chat/message'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'session_id': sessionId,
          'message': message,
        }),
      );

      final data = jsonDecode(response.body);
      _handleResponse(data);
    } catch (error) {
      debugPrint('Error sending message: $error');
      setState(() {
        _messages.add(ChatMessage(
          content: 'Sorry, there was an error processing your request.',
          isUser: false,
          isCustomWidget: false,
        ));
      });
      _scrollToBottom();
    }
  }

  void _handleResponse(Map<String, dynamic> response) {
    setState(() {
      if (response['type'] == 'text') {
        _messages.add(ChatMessage(
          content: response['content'],
          isUser: false,
          isCustomWidget: false,
        ));
      } else if (response['type'] == 'company_options') {
        _messages.add(ChatMessage(
          content: response['query'],
          isUser: false,
          isCustomWidget: true,
          customWidget: CompanyOptionsWidget(
            query: response['query'],
            options: List<Map<String, dynamic>>.from(response['options']),
            onSelect: (symbol) {
              _sendMessage('I select $symbol');
            },
          ),
        ));
      } else if (response['type'] == 'stock_analysis') {
        _messages.add(ChatMessage(
          content: response['explanation'],
          isUser: false,
          isCustomWidget: true,
          customWidget: StockAnalysisWidget(
            symbol: response['symbol'],
            explanation: response['explanation'],
          ),
        ));
      }
    });

    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stock Chat Assistant'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16.0),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final message = _messages[index];
                  return _buildMessageWidget(message);
                },
              ),
            ),
            _buildInputArea(),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageWidget(ChatMessage message) {
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          bottom: 10.0,
          left: message.isUser ? 80.0 : 0.0,
          right: message.isUser ? 0.0 : 80.0,
        ),
        padding: const EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          color:
              message.isUser ? Colors.lightBlue.shade50 : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(8.0),
        ),
        child: message.isCustomWidget
            ? message.customWidget
            : Text(message.content),
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.2),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: const InputDecoration(
                hintText: 'Type your message here...',
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onSubmitted: (text) {
                if (text.isNotEmpty) {
                  _sendMessage(text);
                }
              },
            ),
          ),
          const SizedBox(width: 8.0),
          ElevatedButton(
            onPressed: () {
              final message = _messageController.text.trim();
              if (message.isNotEmpty) {
                _sendMessage(message);
              }
            },
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}

class ChatMessage {
  final String content;
  final bool isUser;
  final bool isCustomWidget;
  final Widget? customWidget;

  ChatMessage({
    required this.content,
    required this.isUser,
    required this.isCustomWidget,
    this.customWidget,
  });
}

class CompanyOptionsWidget extends StatelessWidget {
  final String query;
  final List<Map<String, dynamic>> options;
  final Function(String) onSelect;

  const CompanyOptionsWidget({
    super.key,
    required this.query,
    required this.options,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "I found several companies matching '$query'. Which one did you mean?",
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ...options.map((company) => GestureDetector(
              onTap: () => onSelect(company['symbol']),
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 6),
                padding:
                    const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('${company['name']} (${company['symbol']})'),
              ),
            )),
      ],
    );
  }
}

class StockAnalysisWidget extends StatelessWidget {
  final String symbol;
  final String explanation;

  const StockAnalysisWidget({
    super.key,
    required this.symbol,
    required this.explanation,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$symbol Analysis',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        Text(explanation),
        const SizedBox(height: 12),
        Container(
          height: 180,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Center(
            child: Text('Stock chart visualization would go here'),
          ),
        ),
      ],
    );
  }
}
