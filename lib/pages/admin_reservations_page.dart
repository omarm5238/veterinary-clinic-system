import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_container.dart';
import '../services/reservation_service.dart';

class AdminReservationsPage extends StatelessWidget {
  const AdminReservationsPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          'Manage Reservations',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        decoration: AppTheme.glassBackground,
        child: SafeArea(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('reservations')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                );
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
                        Icon(
                          Icons.calendar_today,
                          size: 80,
                          color: Colors.white54,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No reservations found',
                          style: TextStyle(color: Colors.white70, fontSize: 18),
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

                  Color statusColor;
                  switch (status) {
                    case 'confirmed':
                      statusColor = Colors.blue;
                      break;
                    case 'completed':
                      statusColor = Colors.green[800]!;
                      break;
                    case 'cancelled':
                      statusColor = Colors.red;
                      break;
                    case 'pending':
                    default:
                      statusColor = Colors.amber;
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
                            status == 'completed'
                                ? Icons.check_circle
                                : Icons.event,
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
                                'Doctor: ${data['doctorName'] ?? data['doctorId'] ?? 'Unknown Doctor'}',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.8),
                                ),
                              ),
                              Text(
                                'Customer: ${data['customerName'] ?? data['userId'] ?? 'Unknown Customer'}',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.8),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Status: $status',
                                style: TextStyle(
                                  color: statusColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          children: [
                            if (status == 'pending')
                              ElevatedButton(
                                onPressed: () =>
                                    ReservationService.confirmReservation(
                                      doc.id,
                                    ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                ),
                                child: const Text(
                                  'Confirm',
                                  style: TextStyle(color: Colors.white),
                                ),
                              ),
                            if (status == 'confirmed')
                              ElevatedButton(
                                onPressed: () =>
                                    ReservationService.completeReservation(
                                      doc.id,
                                    ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                ),
                                child: const Text(
                                  'Complete',
                                  style: TextStyle(color: Colors.white),
                                ),
                              ),
                            if (status != 'cancelled' && status != 'completed')
                              TextButton(
                                onPressed: () =>
                                    ReservationService.cancelReservation(
                                      doc.id,
                                      role: 'admin',
                                    ),
                                child: const Text(
                                  'Cancel',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ),
                            if (status == 'cancelled' || status == 'completed')
                              IconButton(
                                icon: const Icon(
                                  Icons.delete,
                                  color: Colors.red,
                                ),
                                tooltip: 'Delete Reservation',
                                onPressed: () async {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      backgroundColor: const Color(0xFF2C2C2C),
                                      title: const Text('Delete Reservation?', style: TextStyle(color: Colors.white)),
                                      content: const Text('Are you sure you want to delete this reservation? This action cannot be undone.', style: TextStyle(color: Colors.white70)),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel', style: TextStyle(color: Colors.white70))),
                                        TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
                                      ],
                                    ),
                                  );
                                  
                                  if (confirm == true) {
                                    // Release the slot before deleting the reservation
                                    await ReservationService.releaseSlotForReservation(
                                      doc.id,
                                    );
                                    await FirebaseFirestore.instance
                                        .collection('reservations')
                                        .doc(doc.id)
                                        .delete();
                                    
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reservation deleted successfully.')));
                                    }
                                  }
                                },
                              ),
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.white),
                              tooltip: 'Edit Reservation',
                              onPressed: () =>
                                  _showEditDialog(context, doc.id, data),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ).animate().fadeIn(delay: (index * 100).ms).slideX();
                },
              );
            },
          ),
        ),
      ),
    );
  }

  void _showEditDialog(
    BuildContext context,
    String docId,
    Map<String, dynamic> data,
  ) {
    final dateController = TextEditingController(text: data['date']);
    final timeController = TextEditingController(text: data['time']);
    String currentStatus = data['status'] ?? 'pending';

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: StatefulBuilder(
            builder: (context, setState) {
              return GlassContainer(
                padding: const EdgeInsets.all(24),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Edit Reservation',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      DropdownButtonFormField<String>(
                        value: currentStatus,
                        dropdownColor: const Color(0xFF2C2C2C),
                        iconEnabledColor: Colors.white,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Status',
                          labelStyle: const TextStyle(color: Colors.white70),
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.1),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'pending',
                            child: Text('Pending'),
                          ),
                          DropdownMenuItem(
                            value: 'confirmed',
                            child: Text('Confirmed'),
                          ),
                          DropdownMenuItem(
                            value: 'completed',
                            child: Text('Completed'),
                          ),
                          DropdownMenuItem(
                            value: 'cancelled',
                            child: Text('Cancelled'),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => currentStatus = val);
                        },
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: dateController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Date (e.g. 2026-05-04)',
                          labelStyle: const TextStyle(color: Colors.white70),
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.1),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: timeController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Time (e.g. 10:30 AM)',
                          labelStyle: const TextStyle(color: Colors.white70),
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.1),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text(
                              'Cancel',
                              style: TextStyle(color: Colors.white70),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () async {
                              final updateData = <String, dynamic>{
                                'status': currentStatus,
                                'date': dateController.text,
                                'time': timeController.text,
                              };

                              // If setting to active state, clear cancelledBy
                              if (currentStatus != 'cancelled') {
                                updateData['cancelledBy'] = null;
                              } else if (data['cancelledBy'] == null) {
                                updateData['cancelledBy'] = 'admin';
                              }

                              await FirebaseFirestore.instance
                                  .collection('reservations')
                                  .doc(docId)
                                  .update(updateData);

                              // Handle slot booking based on status change
                              final slotId = data['slotId'] as String?;
                              final previousStatus =
                                  data['status'] as String? ?? 'pending';
                              if (slotId != null && slotId.isNotEmpty) {
                                final slotRef = FirebaseFirestore.instance
                                    .collection('available_slots')
                                    .doc(slotId);
                                // Admin cancellation does NOT release the slot.
                                // Only re-book if re-activating a customer-cancelled reservation
                                // (customer cancel released the slot, so re-activating needs to re-book it).
                                if (currentStatus != 'cancelled' &&
                                    previousStatus == 'cancelled') {
                                  final previousCancelledBy =
                                      data['cancelledBy'] as String?;
                                  if (previousCancelledBy == 'customer') {
                                    await slotRef.update({'isBooked': true});
                                  }
                                }
                              }

                              if (context.mounted) Navigator.pop(context);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text(
                              'Save',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
