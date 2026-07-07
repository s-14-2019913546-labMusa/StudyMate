import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'language_manager.dart';
import 'theme_manager.dart';

class AboutUsScreen extends StatefulWidget {
  const AboutUsScreen({super.key});

  @override
  State<AboutUsScreen> createState() => _AboutUsScreenState();
}

class _AboutUsScreenState extends State<AboutUsScreen> {
  // Method to launch external URLs safely
  Future<void> _launchURL(String urlString) async {
    final Uri url = Uri.parse(urlString);
    try {
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${'Could not launch'.tr()} $urlString')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error launching link: $e')),
        );
      }
    }
  }

  // Shows the Privacy Policy bottom sheet (migrated from profile_screen)
  void _showPrivacyPolicyDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SafeArea(
            top: true,
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 48,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Icon(
                        Icons.privacy_tip_rounded,
                        color: Theme.of(context).colorScheme.primary,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Privacy Policy'.tr(),
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Last Updated: June 2026'.tr(),
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildPrivacySection(
                            '১. তথ্য সংগ্রহ (Information Collection)'.tr(),
                            'StudyMate আপনার প্রোফাইল তৈরি করতে নাম, ইমেল এবং প্রোফাইল ছবি সংগ্রহ করে। আপনার স্টাডি সেশন, টাস্ক ট্র্যাকিং এবং ইসলামিক লাইফ স্ক্রিনের কার্যক্রম শুধুমাত্র আপনার ব্যক্তিগত অগ্রগতির জন্য ব্যবহার করা হয়।'.tr(),
                          ),
                          _buildPrivacySection(
                            '২. তথ্যের নিরাপত্তা (Data Security)'.tr(),
                            'আমরা আপনার তথ্যের নিরাপত্তা নিশ্চিত করতে Firebase Authentication এবং Cloud Firestore-এর সিকিউরিটি রুলস ব্যবহার করি। আপনার পাসওয়ার্ড ও ব্যক্তিগত তথ্য সম্পূর্ণ সুরক্ষিত অবস্থায় সংরক্ষিত থাকে।'.tr(),
                          ),
                          _buildPrivacySection(
                            '৩. থার্ড-পার্টি সার্ভিস (Third-Party Services)'.tr(),
                            'আমাদের অ্যাপটি Firebase (Google-এর অংশ) সার্ভিসসমূহ ব্যবহার করে ডেটা স্টোর ও অথেন্টিকেশনের জন্য। Google-এর প্রাইভেসি পলিসি অনুযায়ী এই ডেটা প্রসেস করা হয়।'.tr(),
                          ),
                          _buildPrivacySection(
                            '৪. আপনার অধিকার (Your Rights)'.tr(),
                            'আপনি যেকোনো সময় আপনার প্রোফাইল এডিট করে তথ্য পরিবর্তন করতে পারেন অথবা আমাদের সাপোর্ট সেন্টারে যোগাযোগ করে আপনার অ্যাকাউন্ট ও সংশ্লিষ্ট সকল ডেটা সম্পূর্ণ মুছে ফেলার অনুরোধ জানাতে পারেন।'.tr(),
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text('Close'.tr()),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPrivacySection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            content,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: Text('About Us'.tr()),
        centerTitle: true,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 20),
            // Premium Brand Header
            Center(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: primaryColor.withValues(alpha: 0.2),
                    width: 2,
                  ),
                ),
                child: Icon(
                  Icons.school_rounded,
                  size: 72,
                  color: primaryColor,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'StudyMate'.tr(),
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              '${'Version'.tr()} 1.0.0',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 28),
            // Mission / Description Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: ThemeManager.getCardDecoration(context),
              child: Text(
                'about_us_description'.tr(),
                textAlign: TextAlign.start,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.6,
                ),
              ),
            ),
            const SizedBox(height: 32),
            // Privacy Policy List Tile - Integrated Inside About Us
            Card(
              margin: EdgeInsets.zero,
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.privacy_tip_outlined, color: primaryColor),
                ),
                title: Text(
                  'Privacy Policy'.tr(),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey),
                onTap: () => _showPrivacyPolicyDialog(context),
              ),
            ),
            const SizedBox(height: 32),
            // Section Title: Connect with Us
            Align(
              alignment: Alignment.centerLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Connect with Us'.tr(),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Follow us on social media for updates and support.'.tr(),
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Social Media Buttons
            _buildSocialButton(
              context: context,
              icon: Icons.facebook_rounded,
              label: 'Facebook',
              color: const Color(0xFF1877F2),
              url: 'https://www.facebook.com/profile.php?id=61590601895144',
            ),
            const SizedBox(height: 12),
            _buildSocialButton(
              context: context,
              icon: Icons.play_arrow_rounded, // Best fit for YouTube
              label: 'YouTube',
              color: const Color(0xFFFF0000),
              url: 'https://www.youtube.com/@StudyMate-S-26',
            ),
            const SizedBox(height: 12),
            _buildSocialButton(
              context: context,
              icon: Icons.camera_alt_rounded, // Best fit for Instagram
              label: 'Instagram',
              color: const Color(0xFFE1306C),
              url: 'https://www.instagram.com/studymates26/',
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildSocialButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required Color color,
    required String url,
  }) {
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color),
        ),
        title: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        trailing: const Icon(Icons.open_in_new_rounded, size: 16, color: Colors.grey),
        onTap: () => _launchURL(url),
      ),
    );
  }
}
