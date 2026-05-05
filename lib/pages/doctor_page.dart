import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/user.dart';
import '../services/local_storage_service.dart';
import '../services/reservation_service.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_container.dart';
import '../widgets/glass_nav_bar.dart';
import 'reservation_page.dart';
import 'chat_list_page.dart';
import 'doctor_settings_page.dart';
import 'sign_in_page.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:cloud_firestore/cloud_firestore.dart';

class DoctorPage extends StatefulWidget {
  final User user;

  const DoctorPage({super.key, required this.user});

  @override
  State<DoctorPage> createState() => _DoctorPageState();
}

class _DoctorPageState extends State<DoctorPage> {
  int _currentIndex = 0;

  User? _currentUser;

  @override
  void initState() {
    super.initState();
    _currentUser = widget.user;
  }

  Future<void> _logout() async {
    await firebase_auth.FirebaseAuth.instance.signOut();
    await LocalStorageService.instance.clearSession();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const SignInPage()),
        (route) => false,
      );
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
              // Glass AppBar
              GlassContainer(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                margin: const EdgeInsets.all(16),
                borderRadius: BorderRadius.circular(20),
                child: Row(
                  children: [
                    const Icon(Icons.local_hospital, color: Colors.white, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Doctor Dashboard',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            (_currentUser ?? widget.user).name ?? 
                            (_currentUser ?? widget.user).email,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.logout, color: Colors.white),
                      onPressed: _logout,
                    ),
                  ],
                ),
              ),
              Expanded(child: _getCurrentPage()),
            ],
          ),
        ),
      ),
      extendBody: true,
      bottomNavigationBar: GlassNavBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today),
            activeIcon: Icon(Icons.calendar_today, color: Colors.white),
            label: 'Reservations',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.add_circle),
            activeIcon: Icon(Icons.add_circle, color: Colors.white),
            label: 'Create',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.event_available),
            activeIcon: Icon(Icons.event_available, color: Colors.white),
            label: 'My Slots',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat),
            activeIcon: Icon(Icons.chat, color: Colors.white),
            label: 'Chat',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            activeIcon: Icon(Icons.settings, color: Colors.white),
            label: 'Settings',
          ),
        ],
      ),
    );
  }

  Widget _getCurrentPage() {
    switch (_currentIndex) {
      case 0:
        return _buildReservationsList();
      case 1:
        return ReservationPage(
          user: widget.user,
          onReservationCreated: () {
            setState(() {
              _currentIndex = 2; // Go to slots list after creating
            });
          },
        );
      case 2:
        return _buildMySlotsList();
      case 3:
        return ChatListPage(currentUser: widget.user);
      case 4:
        return DoctorSettingsPage(
          user: _currentUser ?? widget.user,
        );
      default:
        return _buildReservationsList();
    }
  }

  Widget _buildReservationsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('reservations')
          .where('doctorId', isEqualTo: widget.user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Colors.white));
        }

        if (snapshot.hasError) {
          return const Center(
            child: Text(
              'Error loading reservations',
              style: TextStyle(color: Colors.red),
            ),
          );
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return Center(
            child: GlassContainer(
              padding: const EdgeInsets.all(40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.calendar_today, size: 80, color: Colors.white54),
                  SizedBox(height: 16),
                  Text(
                    'No reservations yet',
                    style: TextStyle(color: Colors.white70, fontSize: 18),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Reservations will appear here once customers start booking.',
                    style: TextStyle(color: Colors.white38),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final status = data['status'] ?? 'pending';
            final cancelledBy = data['cancelledBy'] as String?;

            Color statusColor;
            String displayStatus = status.toString()[0].toUpperCase() + status.toString().substring(1);
            String? hintText;

            if (status == 'cancelled' && cancelledBy == 'customer') {
              displayStatus = 'Active';
              statusColor = Colors.green;
              hintText = 'Canceled by the customer';
            } else {
              switch (status) {
                case 'confirmed':
                  statusColor = Colors.blue;
                  break;
                case 'completed':
                  statusColor = Colors.green;
                  break;
                case 'cancelled':
                  statusColor = Colors.red;
                  break;
                case 'pending':
                default:
                  statusColor = Colors.yellow;
              }
            }

            return GlassContainer(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: statusColor.withValues(alpha: 0.8),
                    radius: 30,
                    child: Icon(
                      status == 'completed' ? Icons.check_circle : Icons.person,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${data['date'] ?? 'Unknown Date'} at ${data['time'] ?? 'Unknown Time'}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Status: $displayStatus',
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (hintText != null)
                          Text(
                            hintText,
                            style: const TextStyle(
                              color: Color(0xFFFFB74D), // light orange
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        Text(
                          'Customer: ${data['customerName'] ?? 'Unknown Customer'}',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                        ),
                        if (data['notes'] != null)
                          Text(
                            'Notes: ${data['notes']}',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Column(
                    children: [
                      if (status == 'pending')
                        ElevatedButton(
                          onPressed: () => ReservationService.confirmReservation(doc.id),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                          child: const Text('Confirm', style: TextStyle(color: Colors.white)),
                        ),
                      if (status == 'confirmed')
                        ElevatedButton(
                          onPressed: () => ReservationService.completeReservation(doc.id),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                          child: const Text('Complete', style: TextStyle(color: Colors.white)),
                        ),
                      if (status != 'cancelled' && status != 'completed')
                        TextButton(
                          onPressed: () => ReservationService.cancelReservation(doc.id, role: 'doctor'),
                          child: const Text('Cancel', style: TextStyle(color: Colors.red)),
                        ),
                    ],
                  ),
                ],
              ),
            ).animate().fadeIn(delay: (index * 100).ms).slideX();
          },
        );
      },
    );
  }

  Widget _buildMySlotsList() {
    // Outer stream: ALL doctor's slots (no filter on isBooked — doctor sees everything)
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('available_slots')
          .where('doctorId', isEqualTo: widget.user.uid)
          .snapshots(),
      builder: (context, slotsSnapshot) {
        if (slotsSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Colors.white));
        }

        final slotDocs = slotsSnapshot.data?.docs ?? [];

        if (slotDocs.isEmpty) {
          return Center(
            child: GlassContainer(
              padding: const EdgeInsets.all(40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.event_available, size: 80, color: Colors.white54),
                  SizedBox(height: 16),
                  Text(
                    'No slots created',
                    style: TextStyle(color: Colors.white70, fontSize: 18),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Use the Create tab to add available slots.',
                    style: TextStyle(color: Colors.white38),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        // Inner stream: ALL reservations for this doctor
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('reservations')
              .where('doctorId', isEqualTo: widget.user.uid)
              .snapshots(),
          builder: (context, reservationsSnapshot) {
            // Build TWO lookup maps for backward compatibility:
            // 1. bySlotId: for new reservations that have slotId stored
            // 2. byDateTime: for old reservations that only have date+time
            final Map<String, Map<String, String?>> bySlotId = {};
            final Map<String, Map<String, String?>> byDateTime = {};

            if (reservationsSnapshot.hasData) {
              for (final res in reservationsSnapshot.data!.docs) {
                final resData = res.data() as Map<String, dynamic>;
                final resSlotId = resData['slotId'] as String?;
                final resDate = resData['date'] as String? ?? '';
                final resTime = resData['time'] as String? ?? '';
                final status = resData['status'] as String? ?? 'pending';
                final cancelledBy = resData['cancelledBy'] as String?;
                final info = {'status': status, 'cancelledBy': cancelledBy};

                // Map by slotId (new reservations)
                if (resSlotId != null && resSlotId.isNotEmpty) {
                  final existing = bySlotId[resSlotId];
                  if (existing == null || existing['status'] == 'cancelled') {
                    bySlotId[resSlotId] = info;
                  }
                }

                // Map by date|time (backward compat for old reservations)
                if (resDate.isNotEmpty && resTime.isNotEmpty) {
                  final key = '$resDate|$resTime';
                  final existing = byDateTime[key];
                  if (existing == null || existing['status'] == 'cancelled') {
                    byDateTime[key] = info;
                  }
                }
              }
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: slotDocs.length,
              itemBuilder: (context, index) {
                final doc = slotDocs[index];
                final data = doc.data() as Map<String, dynamic>;
                final date = data['date'] as String? ?? 'Unknown Date';
                final time = data['time'] as String? ?? 'Unknown Time';
                final slotDocId = doc.id;

                // Look up: try slotId first, then fallback to date|time
                final infoById = bySlotId[slotDocId];
                final infoByDT = byDateTime['$date|$time'];
                // Merge: prefer active status over cancelled
                Map<String, String?>? info;
                if (infoById != null && infoByDT != null) {
                  info = (infoById['status'] != 'cancelled') ? infoById : infoByDT;
                } else {
                  info = infoById ?? infoByDT;
                }
                final reservationStatus = info?['status'];
                final cancelledBy = info?['cancelledBy'];

                // Determine how to display this slot
                final String displayStatus;
                final Color statusColor;
                final IconData statusIcon;
                // Extra hint text (e.g. customer-cancelled hint)
                String? hintText;

                final bool cancelledByCustomer =
                    reservationStatus == 'cancelled' && cancelledBy == 'customer';
                final bool cancelledByOther =
                    reservationStatus == 'cancelled' && cancelledBy != 'customer';

                if (reservationStatus == null || cancelledByCustomer) {
                  // No reservation OR customer-cancelled → slot is available
                  displayStatus = 'Available';
                  statusColor = Colors.green;
                  statusIcon = Icons.event_available;
                  if (cancelledByCustomer) {
                    hintText = '(Cancelled by customer)';
                  }
                } else if (cancelledByOther) {
                  // Cancelled by doctor or admin → slot stays Cancelled
                  displayStatus = 'Cancelled';
                  statusColor = Colors.red;
                  statusIcon = Icons.cancel;
                } else {
                  switch (reservationStatus) {
                    case 'pending':
                      displayStatus = 'Pending';
                      statusColor = Colors.yellow;
                      statusIcon = Icons.hourglass_empty;
                      break;
                    case 'confirmed':
                      displayStatus = 'Confirmed';
                      statusColor = Colors.blue;
                      statusIcon = Icons.check_circle_outline;
                      break;
                    case 'completed':
                      displayStatus = 'Completed';
                      statusColor = Colors.green;
                      statusIcon = Icons.check_circle;
                      break;
                    default:
                      displayStatus = 'Available';
                      statusColor = Colors.green;
                      statusIcon = Icons.event_available;
                  }
                }

                // Only allow deleting slots that are available (no active reservation)
                final bool canDelete =
                    reservationStatus == null || cancelledByCustomer;

                return GlassContainer(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: statusColor.withValues(alpha: 0.8),
                        radius: 30,
                        child: Icon(statusIcon, color: Colors.white),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$date at $time',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Status: $displayStatus',
                              style: TextStyle(
                                color: statusColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (hintText != null)
                              Text(
                                hintText,
                                style: const TextStyle(
                                  color: Color(0xFFFFB74D), // light orange
                                  fontSize: 12,
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (canDelete)
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () async {
                            await FirebaseFirestore.instance
                                .collection('available_slots')
                                .doc(doc.id)
                                .delete();
                          },
                        ),
                    ],
                  ),
                ).animate().fadeIn(delay: (index * 100).ms).slideX();
              },
            );
          },
        );
      },
    );
  }
}

