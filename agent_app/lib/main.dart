import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

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
      // _scrollToBottom();
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
        // Convert the data to a JSON string if it's not already a string
        String stockDataStr;
        if (response['data'] is String) {
          stockDataStr = response['data'];
        } else if (response['data'] != null) {
          stockDataStr = jsonEncode(response['data']);
        } else {
          stockDataStr = '';
        }

        _messages.add(ChatMessage(
          content: response['explanation'],
          isUser: false,
          isCustomWidget: true,
          customWidget: StockAnalysisWidget(
            symbol: response['symbol'],
            explanation: response['explanation'],
            stockData: stockDataStr,
          ),
        ));
      }
    });

    // _scrollToBottom();
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
          left: message.isUser ? 25.0 : 0.0,
          right: message.isUser ? 0.0 : 25.0,
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
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
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

class StockAnalysisWidget extends StatefulWidget {
  final String symbol;
  final String explanation;
  final String? stockData;

  const StockAnalysisWidget({
    super.key,
    required this.symbol,
    required this.explanation,
    required this.stockData,
  });

  @override
  State<StockAnalysisWidget> createState() => _StockAnalysisWidgetState();
}

class _StockAnalysisWidgetState extends State<StockAnalysisWidget> {
  List<FlSpot> _priceSpots = [];
  double _minY = 0;
  double _maxY = 0;
  List<String> _dates = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _parseStockData();
  }

  void _parseStockData() {
    if (widget.stockData == null || widget.stockData!.isEmpty) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      // Parse the JSON string
      final Map<String, dynamic> data = jsonDecode(widget.stockData!);

      // Extract the time series data
      final Map<String, dynamic> timeSeries = data['Time Series (Daily)'] ?? {};

      // Sort dates in ascending order
      final List<String> sortedDates = timeSeries.keys.toList()
        ..sort((a, b) => DateTime.parse(a).compareTo(DateTime.parse(b)));

      _dates = sortedDates;

      // Create data points for the chart
      List<FlSpot> spots = [];
      double minPrice = double.infinity;
      double maxPrice = -double.infinity;

      for (int i = 0; i < sortedDates.length; i++) {
        final date = sortedDates[i];
        final dayData = timeSeries[date];

        // Handle the specific format from your sample data
        final closePrice = double.parse(dayData['4. close'] ??
            dayData['close'] ??
            dayData['4. close:'] ??
            dayData['close:'] ??
            // Try to match the format in your sample
            (dayData.containsKey('4. close') ? dayData['4. close'] : null) ??
            (dayData.containsKey('close') ? dayData['close'] : null) ??
            '0');

        spots.add(FlSpot(i.toDouble(), closePrice));

        if (closePrice < minPrice) minPrice = closePrice;
        if (closePrice > maxPrice) maxPrice = closePrice;
      }

      // Add some padding to min and max for better visualization
      final padding = (maxPrice - minPrice) * 0.1;

      setState(() {
        _priceSpots = spots;
        _minY = minPrice - padding;
        _maxY = maxPrice + padding;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error parsing stock data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${widget.symbol} Analysis',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        Container(
          height: 250,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(4),
          ),
          padding: const EdgeInsets.all(16),
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _priceSpots.isEmpty
                  ? const Center(child: Text('No stock data available'))
                  : _buildStockChart(),
        ),
        const SizedBox(height: 12),
        MarkdownBody(data: widget.explanation),
      ],
    );
  }

  Widget _buildStockChart() {
    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: true,
          horizontalInterval: 1,
          verticalInterval: 1,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: Colors.grey.shade300,
              strokeWidth: 1,
            );
          },
          getDrawingVerticalLine: (value) {
            return FlLine(
              color: Colors.grey.shade300,
              strokeWidth: 1,
            );
          },
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: _dates.length > 10
                  ? (_dates.length / 5).floor().toDouble()
                  : 1,
              getTitlesWidget: (value, meta) {
                if (value.toInt() >= 0 && value.toInt() < _dates.length) {
                  final date = DateTime.parse(_dates[value.toInt()]);
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      DateFormat('MM/dd').format(date),
                      style: const TextStyle(
                        color: Colors.black54,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  );
                }
                return const SizedBox();
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: ((_maxY - _minY) / 5).roundToDouble(),
              getTitlesWidget: (value, meta) {
                return Text(
                  '\$${value.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: Colors.black54,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                );
              },
              reservedSize: 42,
            ),
          ),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border.all(color: Colors.grey.shade400),
        ),
        minX: 0,
        maxX: (_priceSpots.length - 1).toDouble(),
        minY: _minY,
        maxY: _maxY,
        lineBarsData: [
          LineChartBarData(
            spots: _priceSpots,
            isCurved: true,
            color: Colors.green,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(
              // Only show dots if we have few data points
              show: _priceSpots.length < 15,
            ),
            belowBarData: BarAreaData(
              show: true,
              color: Colors.green.withValues(alpha: 0.2),
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            // tooltipBgColor: Colors.blueAccent.withOpacity(0.8),
            getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
              return touchedBarSpots.map((barSpot) {
                final index = barSpot.x.toInt();
                if (index >= 0 && index < _dates.length) {
                  final date = DateTime.parse(_dates[index]);
                  final formattedDate = DateFormat('yyyy-MM-dd').format(date);
                  return LineTooltipItem(
                    '$formattedDate\n',
                    const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                    children: [
                      TextSpan(
                        text: '\$${barSpot.y.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.normal,
                        ),
                      ),
                    ],
                  );
                }
                return null;
              }).toList();
            },
          ),
        ),
      ),
    );
  }
}
