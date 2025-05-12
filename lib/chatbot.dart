import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({Key? key}) : super(key: key);

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final List<ChatMessage> _messages = [];
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ScrollController _scrollController = ScrollController();
  String _currentChatId = '';
  List<Map<String, dynamic>> _busOptions = [];

  @override
  void initState() {
    super.initState();
    _createNewChat();
    _loadBusOptions();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _createNewChat() async {
    setState(() {
      _messages.clear();
    });

    final newChatDoc = await _firestore.collection('chatSessions').add({
      'createdAt': Timestamp.now(),
      'lastUpdated': Timestamp.now(),
    });

    setState(() {
      _currentChatId = newChatDoc.id;
    });

    final welcomeMessage = ChatMessage(
      text: 'Bonjour ! Que souhaitez-vous savoir aujourd\'hui ?',
      isUser: false,
      timestamp: DateTime.now(),
      options: ['Information sur les bus'],
    );

    setState(() {
      _messages.add(welcomeMessage);
    });

    await _firestore
        .collection('chatSessions')
        .doc(_currentChatId)
        .collection('messages')
        .add({
      'text': welcomeMessage.text,
      'isUser': false,
      'timestamp': Timestamp.now(),
      'options': welcomeMessage.options,
    });
  }

  Future<void> _loadBusOptions() async {
    final busesSnapshot = await _firestore.collection('buses').get();
    setState(() {
      _busOptions = busesSnapshot.docs.map((doc) {
        return {
          'id': doc.id,
          'lineName': doc['lineName'],
          'busCode': doc['busCode'],
        };
      }).toList();
    });
  }

  Future<void> _handleUserSelection(String selectedText) async {
    final userMessage = ChatMessage(
      text: selectedText,
      isUser: true,
      timestamp: DateTime.now(),
    );

    setState(() {
      _messages.add(userMessage);
    });

    await _firestore
        .collection('chatSessions')
        .doc(_currentChatId)
        .collection('messages')
        .add({
      'text': selectedText,
      'isUser': true,
      'timestamp': Timestamp.now(),
    });

    _scrollToBottom();

    // Si l'utilisateur demande "Information sur les bus"
    if (selectedText == 'Information sur les bus') {
      await Future.delayed(const Duration(seconds: 1));

      final botMessage = ChatMessage(
        text: 'Sélectionnez un bus :',
        isUser: false,
        timestamp: DateTime.now(),
        options: _busOptions
            .map((bus) => '${bus['busCode']} - ${bus['lineName']}')
            .toList(),
      );

      setState(() {
        _messages.add(botMessage);
      });

      await _firestore
          .collection('chatSessions')
          .doc(_currentChatId)
          .collection('messages')
          .add({
        'text': botMessage.text,
        'isUser': false,
        'timestamp': Timestamp.now(),
        'options': botMessage.options,
      });

      _scrollToBottom();
    }
    // Si l'utilisateur sélectionne un bus spécifique
    else if (selectedText.contains(' - ')) {
      final selectedBusCode = selectedText.split(' - ')[0];
      final selectedBus = _busOptions.firstWhere(
          (bus) => bus['busCode'] == selectedBusCode,
          orElse: () => {});

      if (selectedBus.isNotEmpty) {
        final busDoc =
            await _firestore.collection('buses').doc(selectedBus['id']).get();
        final List<dynamic> stations = busDoc.data()?['station'] ?? [];

        List<String> stationNames = [];
        for (var station in stations) {
          if (station['name'] != null) {
            stationNames.add(station['name']);
          }
        }

        final stationText = stationNames.isNotEmpty
            ? 'Les stations de ce bus sont :\n\n${stationNames.join('\n')}'
            : 'Aucune station trouvée pour ce bus.';

        await Future.delayed(const Duration(seconds: 1));

        final botResponse = ChatMessage(
          text: stationText,
          isUser: false,
          timestamp: DateTime.now(),
        );

        setState(() {
          _messages.add(botResponse);
        });

        await _firestore
            .collection('chatSessions')
            .doc(_currentChatId)
            .collection('messages')
            .add({
          'text': botResponse.text,
          'isUser': false,
          'timestamp': Timestamp.now(),
        });

        _scrollToBottom();
      }
    }
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
        title: const Text('Assistant Bus'),
        backgroundColor: const Color(0xFFE6E8EA),
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(8.0),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                return _messages[index];
              },
            ),
          ),
          if (_messages.isEmpty || _messages.last.isUser)
            _buildPredefinedQuestions(),
        ],
      ),
    );
  }

  Widget _buildPredefinedQuestions() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            blurRadius: 6,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 8.0, bottom: 8.0),
            child: Text(
              'Sélectionnez une question :',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF0E2A47),
              ),
            ),
          ),
          Wrap(
            spacing: 8.0,
            runSpacing: 8.0,
            children: [
              _buildQuestionButton('Information sur les bus'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionButton(String text) {
    return ElevatedButton(
      onPressed: () => _handleUserSelection(text),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF0E2A47),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      child: Text(text),
    );
  }
}

class ChatMessage extends StatelessWidget {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final List<String>? options;

  const ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.options,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isUser)
                Container(
                  margin: const EdgeInsets.only(right: 8.0),
                  child: const CircleAvatar(
                    backgroundColor: Color(0xFF0E2A47),
                    child: Icon(Icons.support_agent, color: Colors.white),
                  ),
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: isUser
                      ? CrossAxisAlignment.end
                      : CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12.0),
                      decoration: BoxDecoration(
                        color: isUser
                            ? const Color(0xFF0E2A47).withOpacity(0.1)
                            : Colors.grey.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                      child: Text(text),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        '${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (isUser)
                Container(
                  margin: const EdgeInsets.only(left: 8.0),
                  child: const CircleAvatar(
                    backgroundColor: Color(0xFF0E2A47),
                    child: Icon(Icons.person, color: Colors.white),
                  ),
                ),
            ],
          ),
          if (!isUser && options != null && options!.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 8.0, left: 48.0),
              child: Wrap(
                spacing: 8.0,
                runSpacing: 8.0,
                children: options!.map((option) {
                  return ElevatedButton(
                    onPressed: () {
                      final chatState =
                          context.findAncestorStateOfType<_ChatPageState>();
                      if (chatState != null) {
                        chatState._handleUserSelection(option);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0E2A47),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                    ),
                    child: Text(option, style: const TextStyle(fontSize: 12)),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }
}
