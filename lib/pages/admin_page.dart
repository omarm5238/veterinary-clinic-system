import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import '../models/user.dart' as app_models;
import '../theme/app_theme.dart';
import '../widgets/glass_container.dart';
import '../widgets/glass_button.dart';
import '../widgets/glass_nav_bar.dart';
import 'admin_reservations_page.dart';
import 'sign_in_page.dart';

class AdminPage extends StatefulWidget {
  final app_models.User user;

  const AdminPage({super.key, required this.user});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  int _currentIndex = 0;

  final _newDoctorNameController = TextEditingController();
  final _newDoctorEmailController = TextEditingController();
  final _newDoctorPasswordController = TextEditingController();
  bool _obscureNewDoctorPassword = true;
  bool _isCreatingDoctor = false;

  @override
  void dispose() {
    _newDoctorNameController.dispose();
    _newDoctorEmailController.dispose();
    _newDoctorPasswordController.dispose();
    super.dispose();
  }

  Future<void> _logout() async {
    await firebase_auth.FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const SignInPage()),
        (route) => false,
      );
    }
  }

  Future<void> _createDoctorAccount() async {
    if (_newDoctorNameController.text.trim().isEmpty ||
        _newDoctorEmailController.text.trim().isEmpty ||
        _newDoctorPasswordController.text.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Please fill all fields'),
            backgroundColor: Colors.orange.withValues(alpha: 0.8),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    if (_newDoctorPasswordController.text.trim().length < 6) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Password must be at least 6 characters'),
            backgroundColor: Colors.orange.withValues(alpha: 0.8),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    setState(() => _isCreatingDoctor = true);

    try {
      final credential = await firebase_auth.FirebaseAuth.instance
          .createUserWithEmailAndPassword(
        email: _newDoctorEmailController.text.trim(),
        password: _newDoctorPasswordController.text.trim(),
      );

      final uid = credential.user!.uid;

      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'name': _newDoctorNameController.text.trim(),
        'email': _newDoctorEmailController.text.trim(),
        'role': 'doctor',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Doctor account created: ${_newDoctorEmailController.text.trim()}',
            ),
            backgroundColor: Colors.green.withValues(alpha: 0.8),
            behavior: SnackBarBehavior.floating,
          ),
        );
        _newDoctorNameController.clear();
        _newDoctorEmailController.clear();
        _newDoctorPasswordController.clear();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red.withValues(alpha: 0.8),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCreatingDoctor = false);
      }
    }
  }

  Future<void> _deleteUser(String uid, String email) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2C),
        title: const Text('Confirm Deletion', style: TextStyle(color: Colors.white)),
        content: Text('Are you sure you want to delete user $email?', style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      // Note: We delete the Firestore doc to revoke access/roles. 
      // Deleting from Auth requires Admin SDK, so this acts as a logical delete.
      await FirebaseFirestore.instance.collection('users').doc(uid).delete();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User removed successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error removing user: $e')),
      );
    }
  }


  Widget _buildStatCard(String title, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.8),
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildDashboard() {
    return Center(
      child: GlassContainer(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.admin_panel_settings, color: Colors.white, size: 64),
            const SizedBox(height: 16),
            const Text(
              'Admin Dashboard',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('users').snapshots(),
              builder: (context, usersSnapshot) {
                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('reservations').snapshots(),
                  builder: (context, reservationsSnapshot) {
                    if (!usersSnapshot.hasData || !reservationsSnapshot.hasData) {
                      return const Center(child: CircularProgressIndicator(color: Colors.white));
                    }

                    int doctors = 0;
                    int customers = 0;

                    for (var doc in usersSnapshot.data!.docs) {
                      final data = doc.data() as Map<String, dynamic>?;
                      if (data == null) continue;
                      if (data['role'] == 'doctor') doctors++;
                      if (data['role'] == 'customer') customers++;
                    }

                    final reservationsCount = reservationsSnapshot.data!.docs.length;

                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildStatCard('Doctors', doctors.toString()),
                        _buildStatCard('Users', customers.toString()),
                        _buildStatCard('Reservations', reservationsCount.toString()),
                      ],
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AdminReservationsPage()),
                );
                // Force rebuild so StreamBuilders re-subscribe with fresh data
                if (mounted) setState(() {});
              },
              icon: const Icon(Icons.list_alt),
              label: const Text('Manage Reservations'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppTheme.primaryRed,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildManageUsers() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Colors.white));
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error loading users',
              style: const TextStyle(color: Colors.red),
            ),
          );
        }

        final users = snapshot.data?.docs ?? [];

        if (users.isEmpty) {
          return const Center(
            child: Text(
              'No users found.',
              style: TextStyle(color: Colors.white70),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: users.length,
          itemBuilder: (context, index) {
            final doc = users[index];
            final data = doc.data() as Map<String, dynamic>;
            final role = data['role'] ?? 'customer';
            
            return GlassContainer(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              child: ListTile(
                leading: Icon(
                  role == 'admin'
                      ? Icons.admin_panel_settings
                      : (role == 'doctor' ? Icons.local_hospital : Icons.person),
                  color: Colors.white,
                ),
                title: Text(
                  data['name'] ?? 'No Name',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  '${data['email']}\nRole: $role',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
                ),
                trailing: role == 'admin' ? null : IconButton(
                  icon: const Icon(Icons.delete, color: Colors.redAccent),
                  onPressed: () => _deleteUser(doc.id, data['email']),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAddDoctor() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: GlassContainer(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.person_add, color: Colors.white, size: 28),
                const SizedBox(width: 12),
                const Text(
                  'Create New Doctor Account',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _newDoctorNameController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Doctor Name',
                labelStyle: const TextStyle(color: Colors.white70),
                prefixIcon: const Icon(Icons.person, color: Colors.white70),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.1),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _newDoctorEmailController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Email',
                labelStyle: const TextStyle(color: Colors.white70),
                prefixIcon: const Icon(Icons.email, color: Colors.white70),
                hintText: 'doctor@example.com',
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.1),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _newDoctorPasswordController,
              obscureText: _obscureNewDoctorPassword,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Password',
                labelStyle: const TextStyle(color: Colors.white70),
                prefixIcon: const Icon(Icons.lock, color: Colors.white70),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureNewDoctorPassword ? Icons.visibility : Icons.visibility_off,
                    color: Colors.white70,
                  ),
                  onPressed: () {
                    setState(() => _obscureNewDoctorPassword = !_obscureNewDoctorPassword);
                  },
                ),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.1),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 24),
            GlassButton(
              text: _isCreatingDoctor ? 'Processing...' : 'Create Doctor Account',
              icon: Icons.person_add,
              onPressed: _isCreatingDoctor ? null : _createDoctorAccount,
              textColor: Colors.white,
            ),
          ],
        ),
      ),
    );
  }

  Widget _getCurrentPage() {
    switch (_currentIndex) {
      case 0:
        return _buildDashboard();
      case 1:
        return _buildManageUsers();
      case 2:
        return _buildAddDoctor();
      default:
        return _buildDashboard();
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
                    const Icon(Icons.admin_panel_settings, color: Colors.white, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Admin Portal',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          Text(
                            widget.user.name ?? widget.user.email,
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
                      tooltip: 'Logout',
                    ),
                  ],
                ),
              ),
              // Main Content
              Expanded(
                child: _getCurrentPage(),
              ),
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
            icon: Icon(Icons.dashboard),
            activeIcon: Icon(Icons.dashboard, color: Colors.white),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people),
            activeIcon: Icon(Icons.people, color: Colors.white),
            label: 'Users',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_add),
            activeIcon: Icon(Icons.person_add, color: Colors.white),
            label: 'Add Doctor',
          ),
        ],
      ),
    );
  }
}
