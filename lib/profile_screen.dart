import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart'; // ক্লিপবোর্ডে কপি করার জন্য
import 'login_screen.dart'; // লগইন স্ক্রিন ইমপোর্ট করা হলো
import 'social_hub_screen.dart'; // সোশ্যাল হাব স্ক্রিন ইমপোর্ট করা হলো

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Profile',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                ),
                IconButton(
                  icon: Icon(Icons.settings_outlined, color: Theme.of(context).colorScheme.onSurface),
                  onPressed: () {},
                ),
              ],
            ),
            const SizedBox(height: 24),
            // ১. ইউজারের ছবি ও নাম
            CircleAvatar(
              radius: 50,
              backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
              child: Text(
                user?.displayName?.substring(0, 1).toUpperCase() ?? 'U',
                style: TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              user?.displayName ?? 'StudyMate User',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            Text(
              user?.email ?? 'No email available',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Colors.grey),
            ),
            const SizedBox(height: 12),
            // ৫. ইউনিক আইডি কপি করার অপশন
            InkWell(
              onTap: () async {
                if (user?.uid != null) {
                  await Clipboard.setData(ClipboardData(text: user!.uid));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ID copied to clipboard!')));
                  }
                }
              },
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'ID: ${user?.uid ?? 'Unknown'}',
                      style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.copy_rounded, size: 14, color: Theme.of(context).colorScheme.primary),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),

            // ২. স্টাডি স্ট্যাটিসটিক্স
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildStatCard(context, '12', 'Tasks Done', Icons.check_circle_rounded, Colors.green),
                _buildStatCard(context, '34h', 'Studied', Icons.access_time_filled_rounded, Colors.blue),
                _buildStatCard(context, '5', 'Day Streak', Icons.local_fire_department_rounded, Colors.orange),
              ],
            ),
            const SizedBox(height: 32),

            // ৩. অ্যাপ সেটিংস লিস্ট
            _buildListTile(context, Icons.people_alt_rounded, 'Social Hub', onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const SocialHubScreen()));
            }),
            _buildListTile(context, Icons.person_outline_rounded, 'Edit Profile'),
            _buildListTile(context, Icons.notifications_none_rounded, 'Notifications'),
            _buildListTile(context, Icons.dark_mode_outlined, 'Dark Mode', isToggle: true),
            _buildListTile(context, Icons.privacy_tip_outlined, 'Privacy Policy'),
            const SizedBox(height: 20),
            
            // ৪. লগআউট বাটন
            ElevatedButton.icon(
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
                if (context.mounted) {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => const LoginScreen()),
                    (route) => false, // লগআউট হওয়ার পর আগের সব স্ক্রিন (হিস্ট্রি) মুছে ফেলবে
                  );
                }
              },
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Log Out'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error.withValues(alpha: 0.1),
                foregroundColor: Theme.of(context).colorScheme.error,
                elevation: 0,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(BuildContext context, String value, String label, IconData icon, Color color) {
    return Container(
      width: MediaQuery.of(context).size.width * 0.28,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildListTile(BuildContext context, IconData icon, String title, {bool isToggle = false, VoidCallback? onTap}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Theme.of(context).colorScheme.primary),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        trailing: isToggle
            ? Switch(
                value: false, // ডার্ক মোডের স্টেট এখানে বসবে
                onChanged: (val) {},
                activeColor: Theme.of(context).colorScheme.primary,
              )
            : const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey),
        onTap: isToggle ? null : onTap,
      ),
    );
  }
}