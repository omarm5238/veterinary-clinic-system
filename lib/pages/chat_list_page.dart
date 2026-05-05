import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/user.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_container.dart';
import 'chat_detail_page.dart';

class ChatListPage extends StatelessWidget {
  final User currentUser;

  const ChatListPage({super.key, required this.currentUser});

  @override
  Widget build(BuildContext context) {
    if (currentUser.role == 'customer') {
      return _buildCustomerChatList(context);
    } else {
      return _buildDoctorChatList(context);
    }
  }

  Widget _buildDoctorChatList(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('chats')
          .where('participants', arrayContains: currentUser.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Colors.white));
        }

        var chats = snapshot.data?.docs ?? [];

        // Filter and sort in Dart
        chats = chats.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['isInitialized'] == true;
        }).toList();

        chats.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          
          final aUrgent = aData['isUrgent'] == true;
          final bUrgent = bData['isUrgent'] == true;
          
          // 1. isUrgent == true
          if (aUrgent && !bUrgent) return -1;
          if (!aUrgent && bUrgent) return 1;

          // 2. unreadCount descending
          final aUnread = aData['unreadCountDoctor'] ?? 0;
          final bUnread = bData['unreadCountDoctor'] ?? 0;
          if (aUnread != bUnread) {
            return bUnread.compareTo(aUnread);
          }

          // 3. lastMessageTime
          final aTime = (aData['lastMessageTime'] as Timestamp?)?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bTime = (bData['lastMessageTime'] as Timestamp?)?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
          return bTime.compareTo(aTime);
        });

        if (chats.isEmpty) {
          return Center(
            child: GlassContainer(
              padding: const EdgeInsets.all(40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.chat_bubble_outline, size: 64, color: Colors.white.withValues(alpha: 0.8)),
                  const SizedBox(height: 16),
                  Text(
                    'No messages yet',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 18),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: chats.length,
          itemBuilder: (context, index) {
            final doc = chats[index];
            final data = doc.data() as Map<String, dynamic>;
            
            final unreadCount = data['unreadCountDoctor'] ?? 0;
            final customerName = data['customerName'] ?? 'Unknown Customer';
            final lastMessage = data['lastMessage'] ?? '';
            final isUrgent = data['isUrgent'] == true;
            final hasReservation = data['hasReservation'] == true;

            final customerUser = User(
              uid: data['customerId'],
              email: '', 
              role: 'customer',
              name: customerName,
              password: '',
            );

            return _buildChatListItem(context, customerUser, unreadCount, lastMessage, isUrgent, hasReservation, index);
          },
        );
      },
    );
  }

  Widget _buildCustomerChatList(BuildContext context) {
    return Stack(
      children: [
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('chats')
              .where('participants', arrayContains: currentUser.uid)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: Colors.white));
            }

            var chats = snapshot.data?.docs ?? [];

            chats = chats.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return data['isInitialized'] == true;
            }).toList();

            chats.sort((a, b) {
              final aData = a.data() as Map<String, dynamic>;
              final bData = b.data() as Map<String, dynamic>;
              final aTime = (aData['lastMessageTime'] as Timestamp?)?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
              final bTime = (bData['lastMessageTime'] as Timestamp?)?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
              return bTime.compareTo(aTime);
            });

            if (chats.isEmpty) {
              return Center(
                child: GlassContainer(
                  padding: const EdgeInsets.all(40),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.chat_bubble_outline, size: 64, color: Colors.white.withValues(alpha: 0.8)),
                      const SizedBox(height: 16),
                      Text(
                        'No active chats',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 18),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tap "New Chat" to start a consultation',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 14),
                      ),
                    ],
                  ),
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 80), // Extra padding for FAB
              itemCount: chats.length,
              itemBuilder: (context, index) {
                final doc = chats[index];
                final data = doc.data() as Map<String, dynamic>;
                
                final unreadCount = data['unreadCountUser'] ?? 0;
                final doctorName = data['doctorName'] ?? 'Unknown Doctor';
                final lastMessage = data['lastMessage'] ?? '';
                final isUrgent = data['isUrgent'] == true;
                final hasReservation = data['hasReservation'] == true;

                final doctorUser = User(
                  uid: data['doctorId'],
                  email: '', 
                  role: 'doctor',
                  name: doctorName,
                  password: '',
                );

                return _buildChatListItem(context, doctorUser, unreadCount, lastMessage, isUrgent, hasReservation, index);
              },
            );
          },
        ),
        Positioned(
          bottom: 16,
          right: 16,
          child: FloatingActionButton.extended(
            onPressed: () => _showNewChatDialog(context),
            backgroundColor: AppTheme.primaryRed,
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text('New Chat', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ).animate().scale(delay: 300.ms),
        ),
      ],
    );
  }

  void _showNewChatDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return GlassContainer(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('Select a Doctor', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              Expanded(
                child: FutureBuilder<QuerySnapshot>(
                  future: FirebaseFirestore.instance.collection('users').where('role', isEqualTo: 'doctor').get(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Colors.white));
                    final doctors = snapshot.data!.docs;
                    if (doctors.isEmpty) {
                      return const Center(child: Text('No doctors found.', style: TextStyle(color: Colors.white70)));
                    }
                    return ListView.builder(
                      itemCount: doctors.length,
                      itemBuilder: (context, index) {
                        final data = doctors[index].data() as Map<String, dynamic>;
                        final doctorUser = User(
                          uid: doctors[index].id,
                          email: data['email'] ?? '',
                          password: '',
                          role: 'doctor',
                          name: data['name'],
                        );
                        return ListTile(
                          leading: CircleAvatar(backgroundColor: AppTheme.primaryRed, child: const Icon(Icons.person, color: Colors.white)),
                          title: Text(doctorUser.name ?? doctorUser.email, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          subtitle: Text('Doctor', style: TextStyle(color: Colors.white.withValues(alpha: 0.7))),
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(context, MaterialPageRoute(builder: (_) => ChatDetailPage(currentUser: currentUser, otherUser: doctorUser)));
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildChatListItem(BuildContext context, User otherUser, int unreadCount, String lastMessage, bool isUrgent, bool hasReservation, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: unreadCount > 0 ? Colors.white.withValues(alpha: 0.15) : Colors.transparent, // Active/Unread subtle highlight
        borderRadius: BorderRadius.circular(16),
      ),
      child: GlassContainer(
        padding: const EdgeInsets.all(16),
        child: ListTile(
          contentPadding: EdgeInsets.zero,
        leading: Stack(
          clipBehavior: Clip.none,
          children: [
            CircleAvatar(
              backgroundColor: AppTheme.primaryRed.withValues(alpha: 0.8),
              radius: 25,
              child: const Icon(Icons.person, color: Colors.white),
            ),
            if (unreadCount > 0)
              Positioned(
                right: -4,
                top: -4,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: isUrgent ? Colors.orange : Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    unreadCount.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                otherUser.name ?? 'Unknown',
                style: TextStyle(
                  color: Colors.white, 
                  fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.normal
                ),
              ),
            ),
            if (isUrgent)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text('URGENT', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
              )
            else if (hasReservation && currentUser.role == 'doctor')
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text('BOOKED', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
              )
          ],
        ),
        subtitle: Text(
          lastMessage.isNotEmpty ? lastMessage : 'Tap to start chat',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: unreadCount > 0 ? Colors.white : Colors.white.withValues(alpha: 0.6),
            fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        trailing: const Icon(Icons.chevron_right, color: Colors.white),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChatDetailPage(
                currentUser: currentUser,
                otherUser: otherUser,
              ),
            ),
          );
        },
      ),
    )).animate().fadeIn(delay: (index * 50).ms).slideX();
  }
}
