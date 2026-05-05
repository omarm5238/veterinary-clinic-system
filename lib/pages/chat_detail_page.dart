import 'package:flutter/material.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/user.dart';
import '../services/chat_service.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_container.dart';

class ChatDetailPage extends StatefulWidget {
  final User currentUser;
  final User otherUser;

  const ChatDetailPage({
    super.key,
    required this.currentUser,
    required this.otherUser,
  });

  @override
  State<ChatDetailPage> createState() => _ChatDetailPageState();
}

class _ChatDetailPageState extends State<ChatDetailPage> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  
  late String _chatId;
  late Stream<QuerySnapshot> _messagesStream;
  late Stream<DocumentSnapshot> _chatStream;
  bool _isProcessing = false;

  // Entry Flow State
  bool? _isInitialized;
  bool _showEntryGate = false;
  bool? _hasReservation;
  bool? _isUrgent;
  bool? _immediateBooking;
  final _problemController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final customerId = widget.currentUser.role == 'customer' 
        ? widget.currentUser.uid 
        : widget.otherUser.uid;
    final doctorId = widget.currentUser.role == 'customer' 
        ? widget.otherUser.uid 
        : widget.currentUser.uid;
        
    _chatId = ChatService.getChatId(customerId ?? '', doctorId ?? '');
    _messagesStream = ChatService.getMessagesStream(_chatId);
    _chatStream = FirebaseFirestore.instance.collection('chats').doc(_chatId).snapshots();

    _checkInitialization();

    // Reset unread counts on open
    ChatService.resetUnreadCount(_chatId, widget.currentUser.role);
  }

  Future<void> _checkInitialization() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('chats').doc(_chatId).get();
      if (mounted) {
        setState(() {
          _isInitialized = doc.exists && doc.data()?['isInitialized'] == true;
        });
      }
    } catch(e) {
      if (mounted) {
        setState(() {
          _isInitialized = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _problemController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0.0, // 0.0 is the bottom because reverse: true
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isProcessing) return;

    setState(() => _isProcessing = true);
    _messageController.clear();

    try {
      await ChatService.sendMessage(
        chatId: _chatId,
        senderId: widget.currentUser.uid ?? '',
        text: text,
        type: 'text',
      );
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No internet connection. Message not sent.')),
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _createBookingFromDoctor(bool isUrgent) async {
    setState(() => _isProcessing = true);
    try {
      await ChatService.createLinkedBooking(
        chatId: _chatId,
        customerId: widget.otherUser.uid ?? '',
        customerName: widget.otherUser.name ?? widget.otherUser.email,
        doctorId: widget.currentUser.uid ?? '',
        doctorName: widget.currentUser.name ?? widget.currentUser.email,
        isEmergency: isUrgent,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Booking created successfully!')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))));
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _submitEntryFlow() async {
    final text = _problemController.text.trim();
    if (text.isEmpty || _hasReservation == null || _isUrgent == null || _isProcessing) return;
    if (_isUrgent == true && _immediateBooking == null) return;

    setState(() => _isProcessing = true);

    try {
      await ChatService.initializeChat(
        customerId: widget.currentUser.uid ?? '',
        doctorId: widget.otherUser.uid ?? '',
        hasReservation: _hasReservation!,
        isUrgent: _isUrgent!,
        initialMessage: text,
        customerName: widget.currentUser.name ?? widget.currentUser.email,
        doctorName: widget.otherUser.name ?? widget.otherUser.email,
      );
      
      // Chat is initialized, update state locally
      if (mounted) {
        setState(() {
          _isInitialized = true;
          _showEntryGate = false;
          _hasReservation = null;
          _isUrgent = null;
          _immediateBooking = null;
        });
        _problemController.clear();
      }

      // If immediate booking requested
      if (_isUrgent == true && _immediateBooking == true) {
        await ChatService.createLinkedBooking(
          chatId: _chatId,
          customerId: widget.currentUser.uid ?? '',
          customerName: widget.currentUser.name ?? widget.currentUser.email,
          doctorId: widget.otherUser.uid ?? '',
          doctorName: widget.otherUser.name ?? widget.otherUser.email,
          isEmergency: true,
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: AppTheme.glassBackground,
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: _isInitialized == null
                    ? const Center(child: CircularProgressIndicator(color: Colors.white))
                    : (!_isInitialized! || _showEntryGate) && widget.currentUser.role == 'customer'
                        ? _buildEntryGateFlow()
                        : (!_isInitialized! && widget.currentUser.role == 'doctor')
                            ? const Center(
                                child: Text('Waiting for user to start the chat...',
                                    style: TextStyle(color: Colors.white70)))
                            : _buildChatBody(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return StreamBuilder<DocumentSnapshot>(
      stream: _chatStream,
      builder: (context, snapshot) {
        final chatData = snapshot.data?.data() as Map<String, dynamic>?;
        final hasReservation = chatData?['hasReservation'] == true;
        final isUrgent = chatData?['isUrgent'] == true;

        return GlassContainer(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          margin: const EdgeInsets.all(16),
          borderRadius: BorderRadius.circular(20),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              const SizedBox(width: 8),
              CircleAvatar(
                backgroundColor: AppTheme.primaryRed.withValues(alpha: 0.8),
                child: Text(
                  (widget.otherUser.name ?? widget.otherUser.email)[0].toUpperCase(),
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.otherUser.name ?? widget.otherUser.email,
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      widget.otherUser.role == 'doctor' ? 'Doctor' : 'Customer',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (widget.currentUser.role == 'doctor' && !hasReservation && chatData != null)
                ElevatedButton(
                  onPressed: _isProcessing ? null : () => _createBookingFromDoctor(isUrgent),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppTheme.primaryRed,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  child: _isProcessing 
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Create Booking', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              if (widget.currentUser.role == 'customer' && !_showEntryGate)
                ElevatedButton(
                  onPressed: () => setState(() => _showEntryGate = true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppTheme.primaryRed,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  child: const Text('New Consultation', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
        );
      }
    );
  }

  Widget _buildEntryGateFlow() {
    return Center(
      child: SingleChildScrollView(
        child: GlassContainer(
          padding: const EdgeInsets.all(24),
          margin: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'New Consultation',
                style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              
              if (_hasReservation == null) ...[
                const Text('Do you have a reservation with this doctor?', style: TextStyle(color: Colors.white, fontSize: 16)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => setState(() => _hasReservation = true),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: AppTheme.primaryRed),
                        child: const Text('Yes'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => setState(() => _hasReservation = false),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.white.withValues(alpha: 0.2), foregroundColor: Colors.white),
                        child: const Text('No'),
                      ),
                    ),
                  ],
                ),
              ] else if (_isUrgent == null) ...[
                const Text('Is your case urgent?', style: TextStyle(color: Colors.white, fontSize: 16)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => setState(() => _isUrgent = true),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
                        child: const Text('Yes'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => setState(() => _isUrgent = false),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.white.withValues(alpha: 0.2), foregroundColor: Colors.white),
                        child: const Text('No'),
                      ),
                    ),
                  ],
                ),
              ] else if (_isUrgent == true && _immediateBooking == null) ...[
                const Text('Do you want immediate booking to skip waiting?', style: TextStyle(color: Colors.white, fontSize: 16)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => setState(() => _immediateBooking = true),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
                        child: const Text('Yes'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => setState(() => _immediateBooking = false),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.white.withValues(alpha: 0.2), foregroundColor: Colors.white),
                        child: const Text('No'),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                const Text('Please describe your pet\'s problem', style: TextStyle(color: Colors.white, fontSize: 16)),
                const SizedBox(height: 16),
                TextField(
                  controller: _problemController,
                  maxLines: 4,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.1),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _isProcessing ? null : _submitEntryFlow,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: AppTheme.primaryRed),
                  child: _isProcessing 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) 
                      : const Text('Start Chat'),
                ),
              ]
            ],
          ),
        ),
      ).animate().fadeIn(),
    );
  }

  Widget _buildChatBody() {
    return Column(
      children: [
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _messagesStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: Colors.white));
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.chat_bubble_outline, size: 64, color: Colors.white.withValues(alpha: 0.6)),
                      const SizedBox(height: 16),
                      Text('No messages yet', style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 18)),
                    ],
                  ),
                );
              }

              // Reverse list so newest message is at index 0 (bottom)
              final messages = snapshot.data!.docs.reversed.toList();

              return ListView.builder(
                controller: _scrollController,
                reverse: true,
                padding: const EdgeInsets.all(16),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final doc = messages[index];
                  final data = doc.data() as Map<String, dynamic>;
                  final isMe = data['senderId'] == widget.currentUser.uid;
                  final isSystem = data['type'] == 'system';

                  // Filter by visibility
                  final visibleTo = data['visibleTo'] as String?;
                  if (visibleTo != null && visibleTo != widget.currentUser.uid) {
                    return const SizedBox.shrink();
                  }

                  // Hide empty messages
                  final text = data['text']?.toString().trim() ?? '';
                  if (text.isEmpty && !isSystem) {
                    return const SizedBox.shrink();
                  }

                  return _buildMessageItem(doc.id, data, isMe, isSystem);
                },
              );
            },
          ),
        ),
        _buildMessageInput(),
      ],
    );
  }

  Widget _buildMessageItem(String messageId, Map<String, dynamic> data, bool isMe, bool isSystem) {
    final timestamp = data['timestamp'] as Timestamp?;
    final timeStr = timestamp != null 
        ? '${timestamp.toDate().hour.toString().padLeft(2, '0')}:${timestamp.toDate().minute.toString().padLeft(2, '0')}' 
        : '';

    if (isSystem) {
      return Center(
        key: ValueKey(messageId),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 16),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
          ),
          child: Text(
            data['text'] ?? '',
            style: const TextStyle(color: Colors.white, fontSize: 12, fontStyle: FontStyle.italic),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Align(
      key: ValueKey(messageId),
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isMe ? AppTheme.primaryRed.withValues(alpha: 0.8) : Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(data['text'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 16)),
            if (timeStr.isNotEmpty) ...[
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  timeStr,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 10),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    return GlassContainer(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.all(16),
      borderRadius: BorderRadius.circular(30),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Type a message...',
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.1),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            backgroundColor: AppTheme.primaryRed.withValues(alpha: 0.8),
            child: IconButton(
              icon: _isProcessing 
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.send, color: Colors.white),
              onPressed: _sendMessage,
            ),
          ),
        ],
      ),
    );
  }
}
