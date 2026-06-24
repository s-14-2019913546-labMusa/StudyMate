import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

extension TranslationExtension on String {
  String tr() {
    return LanguageManager().translate(this);
  }
}

class LanguageManager extends ChangeNotifier {
  static final LanguageManager _instance = LanguageManager._internal();
  factory LanguageManager() => _instance;
  LanguageManager._internal();

  static String formatDate(DateTime date) {
    return DateFormat('EEEE, d MMMM', LanguageManager().currentLanguage).format(date);
  }

  String _currentLanguage = 'en'; // default: English
  String get currentLanguage => _currentLanguage;

  bool get isBengali => _currentLanguage == 'bn';

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _currentLanguage = prefs.getString('app_language') ?? 'en';
    notifyListeners();
  }

  Future<void> changeLanguage(String langCode) async {
    if (langCode != _currentLanguage) {
      _currentLanguage = langCode;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('app_language', langCode);
      notifyListeners();
    }
  }

  String translate(String key) {
    if (_currentLanguage == 'bn') {
      return _enToBn[key] ?? key;
    } else {
      return _bnToEn[key] ?? key;
    }
  }

  static const Map<String, String> _enToBn = {
    // Splash / Login / Signup
    'StudyMate': 'স্টাডিমেট',
    'Your Educational Companion': 'আপনার শিক্ষামূলক সঙ্গী',
    'Create Account': 'অ্যাকাউন্ট তৈরি করুন',
    'Sign up to get started!': 'শুরু করতে সাইন আপ করুন!',
    'Display Name': 'প্রদর্শন নাম',
    'Full Name': 'পুরো নাম',
    'Please enter your full name': 'দয়া করে আপনার পুরো নাম লিখুন',
    'Email Address': 'ইমেইল এড্রেস',
    'Please enter your email': 'দয়া করে আপনার ইমেইল লিখুন',
    'Please enter a valid email address': 'দয়া করে একটি সঠিক ইমেইল ঠিকানা লিখুন',
    'Password': 'পাসওয়ার্ড',
    'Please enter your password': 'দয়া করে আপনার পাসওয়ার্ড লিখুন',
    'Please enter a password': 'দয়া করে একটি পাসওয়ার্ড লিখুন',
    'Password must be at least 6 characters long': 'পাসওয়ার্ড অবশ্যই কমপক্ষে ৬ অক্ষরের হতে হবে',
    'Confirm Password': 'পাসওয়ার্ড নিশ্চিত করুন',
    'Please confirm your password': 'দয়া করে আপনার পাসওয়ার্ড নিশ্চিত করুন',
    'Passwords do not match': 'পাসওয়ার্ড মেলেনি',
    'Passwords do not match!': 'পাসওয়ার্ড মেলেনি!',
    'Forgot Password?': 'পাসওয়ার্ড ভুলে গেছেন?',
    'Enter your email address and we will send you a link to reset your password.': 'আপনার ইমেল ঠিকানা লিখুন এবং আমরা আপনাকে আপনার পাসওয়ার্ড রিসেট করার জন্য একটি লিঙ্ক পাঠাব।',
    'Cancel': 'বাতিল',
    'Reset Password': 'পাসওয়ার্ড রিসেট করুন',
    'Password reset email sent to ': 'পাসওয়ার্ড রিসেটের ইমেল পাঠানো হয়েছে ',
    'An error occurred. Please try again.': 'একটি ত্রুটি ঘটেছে। দয়া করে আবার চেষ্টা করুন।',
    'Log In': 'লগ ইন',
    "Don't have an account?": 'অ্যাকাউন্ট নেই?',
    'Create New Account': 'নতুন অ্যাকাউন্ট তৈরি করুন',
    'No user found for that email.': 'ঐ ইমেইলের জন্য কোনো ইউজার পাওয়া যায়নি।',
    'Wrong password provided for that user.': 'ভুল পাসওয়ার্ড দেওয়া হয়েছে।',
    'The email address is not valid.': 'ইমেইল এড্রেসটি সঠিক নয়।',
    'This user account has been disabled.': 'এই ইউজার অ্যাকাউন্টটি নিষ্ক্রিয় করা হয়েছে।',
    'Login failed. Please try again.': 'লগইন ব্যর্থ হয়েছে। আবার চেষ্টা করুন।',
    'The password provided is too weak.': 'প্রদত্ত পাসওয়ার্ডটি খুব দুর্বল।',
    'The email address is already in use by another account.': 'ইমেইল এড্রেসটি ইতিমধ্যে অন্য একটি অ্যাকাউন্ট দ্বারা ব্যবহৃত হচ্ছে।',
    'Email/password accounts are not enabled.': 'ইমেল/পাসওয়ার্ড অ্যাকাউন্ট সচল নয়।',
    'Sign up failed. Please try again.': 'সাইন আপ ব্যর্থ হয়েছে। আবার চেষ্টা করুন।',

    // Focus Mode
    'Focus Mode On': 'ফোকাস মোড চালু',
    'Continue to Home': 'হোমে যান',

    // Dashboard
    'Welcome back!': 'স্বাগতম!',
    'Day Streak': 'দিনের স্ট্রিক',
    "Today's Progress": 'আজকের অগ্রগতি',
    "Today's Tasks": 'আজকের কাজ',
    'Missed Tasks': 'মিসড টাস্ক',
    'Other Tasks': 'অন্যান্য কাজ',
    'New Task': 'নতুন টাস্ক',
    'Home': 'হোম',
    'Tools': 'টুলস',
    'Profile': 'প্রোফাইল',
    'Task Added Successfully!': 'টাস্ক সফলভাবে যুক্ত হয়েছে!',
    'AI Routine Added Successfully!': 'এআই রুটিন সফলভাবে যুক্ত হয়েছে!',
    'Please select both Start and End Time.': 'দয়া করে শুরু এবং শেষের সময় উভয়ই নির্বাচন করুন।',
    'All Missed Tasks': 'সব মিসড টাস্ক',
    'No tasks set for today': 'আজকের জন্য কোনো টাস্ক নেই',
    "Tap the 'New Task' button at the bottom of the screen to plan your study routine and stay productive!": "আপনার স্টাডি রুটিন পরিকল্পনা করতে এবং উৎপাদনশীল থাকতে স্ক্রিনের নিচের 'নতুন টাস্ক' বোতামটি চাপুন!",

    // Profile Settings
    'Social Hub': 'সোশ্যাল হাব',
    'Edit Profile': 'প্রোফাইল এডিট করুন',
    'Notifications': 'নোটিফিকেশনস',
    'Dark Mode': 'ডার্ক মোড',
    'Privacy Policy': 'প্রাইভেসি পলিসি',
    'Missed Task Alert': 'মিসড টাস্ক অ্যালার্ট',
    'This was a missed task.': 'এটি একটি মিসড টাস্ক ছিল।',
    'Scheduled Start Time': 'নির্ধারিত শুরুর সময়',
    'Scheduled End Time': 'নির্ধারিত শেষের সময়',
    'Do you want to start it now?': 'আপনি কি এটি এখন শুরু করতে চান?',
    'Yes, Start': 'হ্যাঁ, শুরু করুন',
    'No': 'না',
    'Completed': 'সম্পন্ন',
    'Missed': 'মিসড',
    'Running': 'চলমান',
    'Paused': 'স্থগিত',
    'Pending': 'অপেক্ষমান',
    'Private Task': 'ব্যক্তিগত টাস্ক',
    'About Us': 'আমাদের সম্পর্কে',
    'Version': 'ভার্সন',
    'Connect with Us': 'আমাদের সাথে যুক্ত হোন',
    'Follow us on social media for updates and support.': 'আপডেট এবং সাপোর্টের জন্য আমাদের সোশ্যাল মিডিয়ায় ফলো করুন।',
    'StudyMate is the ultimate all-in-one productivity companion designed specifically for school, college, and university students, as well as competitive exam candidates (such as BCS and Bank exams).\n\nOur mission is to help you study smarter, stay disciplined, and maintain a healthy, balanced lifestyle.\n\nKey Features:\n• Smart Study Planner: Plan your days and weeks effortlessly with our custom Study Planner and AI Routine Generator.\n• Focus & Productivity: Beat distractions with the Pomodoro Timer, Stopwatch, Focus Music, and dedicated Focus Mode.\n• Effective Learning Aids: Enhance retention using Flashcards, a built-in Dictionary, PDF Reader, and the scientific 1-4-7 Revision method.\n• Collaborative Studying: Connect with peers through the Social Hub, Study Rooms, and shared Partner Tasks.\n• Well-being & Islamic Life: Track your sleep and mood, practice breathing exercises, and access spiritual tools like Prayer Times, Quran, Qibla Compass, and Tasbeeh.\n• Gamification: Stay motivated with Daily Streaks, XP points, Levels, and Unlocked Badges.\n\nWhether you are preparing for your next class or a major career exam, StudyMate is here to guide you every step of the way!': 'স্টাডিমেট (StudyMate) হলো একটি অল-ইন-ওয়ান প্রোডাক্টিভিটি অ্যাপ, যা স্কুল, কলেজ, বিশ্ববিদ্যালয় এবং বিসিএস বা ব্যাংক জবসহ বিভিন্ন প্রতিযোগিতামূলক পরীক্ষার পরীক্ষার্থীদের জন্য বিশেষভাবে ডিজাইন করা হয়েছে।\n\nআমাদের লক্ষ্য হলো আপনাকে আরও স্মার্টলি পড়াশোনা করতে সাহায্য করা, শৃঙ্খলিত রাখা এবং একটি স্বাস্থ্যকর ও ভারসাম্যপূর্ণ জীবনধারা বজায় রাখতে সহায়তা করা।\n\nমূল ফিচারসমূহ:\n• স্মার্ট স্টাডি প্ল্যানার: কাস্টম রুটিন এবং এআই (AI) জেনারেটরের মাধ্যমে আপনার দৈনিক ও সাপ্তাহিক পড়াশোনা খুব সহজেই সাজিয়ে নিন।\n• ফোকাস ও প্রোডাক্টিভিটি: পোমোডোরো টাইমার, স্টপওয়াচ, ফোকাস মিউজিক এবং ডেডিকেটেড ফোকাস মোডের সাহায্যে পড়াশোনায় গভীর মনোযোগ ধরে রাখুন।\n• কার্যকর লার্নিং টুলস: ফ্ল্যাশকার্ড, ডিকশনারি, পিডিএফ রিডার এবং বৈজ্ঞানিক ১-৪-৭ রিভিশন পদ্ধতির মাধ্যমে পড়া সহজে মনে রাখুন।\n• সহযোগিতামূলক পড়াশোনা: সোশ্যাল হাব, স্টাডি রুম এবং পার্টনার টাস্কের মাধ্যমে বন্ধুদের সাথে যুক্ত থেকে একসাথে পড়াশোনা করুন।\n• সুস্থতা ও ইসলামিক লাইফ: ঘুম ও মেজাজ ট্র্যাক করুন, শ্বাস-প্রশ্বাসের ব্যায়াম করুন এবং নামাজের সময়সূচী, কুরআন, কিবলা কম্পাস ও তাসবিহ রিডারের মতো ফিচারগুলো ব্যবহার করুন।\n• গ্যামিফিকেশন: প্রতিদিনের স্ট্রিক বজায় রেখে এক্সপি (XP), লেভেল এবং ব্যাজ আনলক করে নিজের পড়ার আগ্রহ দ্বিগুণ করুন।\n\nপরবর্তী ক্লাস কিংবা ক্যারিয়ার গড়ার যুদ্ধ—আপনার প্রতিটি পদক্ষেপে স্টাডিমেট থাকবে আপনার বিশ্বস্ত সারথী হিসেবে!',
    'Log Out': 'লগ আউট',
    'Tasks Done': 'সম্পন্ন কাজ',
    'Goal/Day': 'লক্ষ্য/দিন',
    'Level ': 'লেভেল ',
    ' XP': ' এক্সপি',
    ' XP to next level': ' এক্সপি পরের লেভেলের জন্য',
    'Unlocked Badges': 'আনলক করা ব্যাজসমূহ',
    'ID copied to clipboard!': 'আইডি ক্লিপবোর্ডে কপি করা হয়েছে!',
    'Close': 'বন্ধ করুন',
    'Language': 'ভাষা',
    'Language (ভাষা)': 'ভাষা (Language)',

    // Edit Profile Screen
    'Short Bio / Goal': 'সংক্ষিপ্ত বিবরণ / লক্ষ্য',
    'School / College / University': 'স্কুল / কলেজ / বিশ্ববিদ্যালয়',
    'Major / Subject': 'মেজর / বিষয়',
    'Class / Year': 'ক্লাস / বছর',
    'Daily Study Goal (Hours)': 'দৈনিক পড়াশোনার লক্ষ্য (ঘণ্টা)',
    'Save Profile Details': 'প্রোফাইল সংরক্ষণ করুন',
    'Name cannot be empty': 'নাম খালি রাখা যাবে না',
    'Enter target hours': 'লক্ষ্য ঘণ্টা লিখুন',
    'Enter valid hours (1-24)': 'সঠিক ঘণ্টা লিখুন (১-২৪)',
    'Profile picture uploaded successfully!': 'প্রোফাইল ছবি সফলভাবে আপলোড করা হয়েছে!',
    'Error uploading profile picture: ': 'প্রোফাইল ছবি আপলোডে ত্রুটি: ',
    'Profile updated successfully!': 'প্রোফাইল সফলভাবে আপডেট করা হয়েছে!',
    'Error updating profile: ': 'প্রোফাইল আপডেটে ত্রুটি: ',
    
    // Tools Screen
    'Study Tools': 'স্টাডি টুলস',
    'AI Study Planner': 'এআই স্টাডি প্ল্যানার',
    'Plan your study smartly in one click!': 'এক ক্লিকে আপনার পড়ার রুটিন তৈরি করুন!',
    'Next-day Routine (নেক্সট ডে রুটিন)': 'নেক্সট-ডে রুটিন',
    'Weekly Routine (উইকলি রুটিন)': 'উইকলি রুটিন',
    'Study & Revision': 'পড়াশোনা ও রিভিশন',
    'Study Analytics': 'স্টাডি অ্যানালিটিক্স',
    'PDF Reader': 'পিডিএফ রিডার',
    '1-4-7 Revision': '১-৪-৭ রিভিশন',
    'Flashcards': 'ফ্ল্যাশকার্ড',
    'Dictionary': 'ডিকশনারি',
    'Focus & Productivity': 'মনোযোগ ও প্রোডাক্টিভিটি',
    'Pomodoro': 'পোমোডোরো',
    'Stopwatch': 'স্টপওয়াচ',
    'Focus Music': 'ফোকাস মিউজিক',
    'Quick Notes': 'কুইক নোটস',
    'Notes': 'নোটস',
    'Collaborative Studying': 'যৌথ পড়াশোনা',
    'Study Room': 'স্টাডি রুম',
    'Partner Tasks': 'পার্টনার টাস্ক',
    'Well-being & Utilities': 'সুস্থতা ও ইউটিলিটি',
    'Breathing': 'শ্বাস-প্রশ্বাস ব্যায়াম',
    'Breathing Exercise': 'ব্রিথিং এক্সারসাইজ',
    'Mood Tracker': 'মুড ট্র্যাকার',
    'Sleep Tracker': 'স্লিপ ট্র্যাকার',
    'Islamic Life': 'ইসলামিক লাইফ',
    'Calculator': 'ক্যালকুলেটর',
    'Theme Option': 'থিম অপশন',
    'Theme': 'থিম',
    'Focus': 'মনোযোগ',
    'is coming soon!': 'শীঘ্রই আসছে!',
    'Select Day (দিন নির্বাচন)': 'দিন নির্বাচন করুন',
    'Subject Name (বিষয়)': 'বিষয়',
    'Enter Subject Name': 'বিষয়ের নাম লিখুন',
    'Topic Name (বিষয়বস্তু)': 'বিষয়বস্তু',
    'Enter Topic Name': 'বিষয়বস্তুর নাম লিখুন',
    'Possible Challenges (সম্ভাব্য সমস্যা)': 'সম্ভাব্য সমস্যা',
    'Describe potential issues or difficulties...': 'সম্ভাব্য সমস্যা বা অসুবিধা বর্ণনা করুন...',
    'Task Goal / Notes (লক্ষ্য ও নোট)': 'লক্ষ্য ও নোট',
    'Enter notes or specific goals...': 'নোট বা নির্দিষ্ট লক্ষ্য লিখুন...',
    'Start Time': 'শুরুর সময়',
    'End Time': 'শেষের সময়',
    'Hide task name from others': 'অন্যদের থেকে টাস্কের নাম লুকান',
    'Category': 'ক্যাটাগরি',
    
    // Theme names
    'Slate Minimal': 'স্লেট মিনিমাল',
    'Midnight Indigo': 'মিডনাইট ইন্ডিগো',
    'Aurora Dream': 'অরোরা ড্রিম',
    'Ocean Blues': 'ওশান ব্লুজ',
    'Sunset Velvet': 'সানসেট ভেলভেট',
    'Cyberpunk Wasp': 'সাইবারপাঙ্ক ওয়াস্প',
    'Sakura Dream': 'সাকুরা ড্রিম',
    'Nebula Purple': 'নেবুলা পার্পল',

    // Theme descriptions
    'Clean, crisp and high-contrast light theme.': 'সহজ, পরিষ্কার ও আকর্ষণীয় লাইট থিম।',
    'Relaxing dark theme with indigo accents.': 'চোখের জন্য আরামদায়ক ইন্ডিগো ডার্ক থিম।',
    'Emerald green tones for visual relaxation.': 'সবুজ আভার চমৎকার আরামদায়ক থিম।',
    'Deep sapphire blue that improves focus.': 'মনোযোগ বৃদ্ধিতে সহায়ক গভীর নীল থিম।',
    'Warm sunset colors that stimulate memory.': 'স্মৃতিশক্তি উদ্দীপিত করতে সহায়ক সানসেট গোল্ড থিম।',
    'High-contrast yellow and deep black cyberpunk theme.': 'হলুদ এবং কালো রঙের আকর্ষণীয় সাইবারপাঙ্ক থিম।',
    'Soft pastel cherry blossom pink light theme.': 'চেরি ব্লসম গোলাপি রঙের মিষ্টি ও মনোরম লাইট থিম।',
    'Cosmic dark theme with neon purple accents.': 'মহাজাগতিক পার্পল টোনের আকর্ষণীয় ডার্ক থিম।',
    'Task History': 'টাস্ক হিস্টোরি',
    'Filter by Category:': 'ক্যাটাগরি ফিল্টার:',
    'Successful Tasks': 'সফল টাস্ক',
    'Missed/Pending Tasks': 'অসম্পূর্ণ/মিসড টাস্ক',
    'No tasks found for this period': 'এই সময়ে কোনো টাস্ক পাওয়া যায়নি',
    'Delete Task': 'টাস্ক মুছুন',
    'Are you sure you want to delete this task from history?': 'আপনি কি নিশ্চিত যে আপনি ইতিহাস থেকে এই টাস্কটি মুছে ফেলতে চান?',
    'Day': 'দিন',
    'Week': 'সপ্তাহ',
    'Month': 'মাস',
    'Delete': 'মুছে ফেলুন',
    'Task Deleted Successfully!': 'টাস্ক সফলভাবে মুছে ফেলা হয়েছে!',
    'Failed to delete task!': 'টাস্ক মুছতে ব্যর্থ হয়েছে!',
    'Delete Sleep Record': 'স্লিপ রেকর্ড মুছুন',
    'Are you sure you want to delete this sleep record?': 'আপনি কি নিশ্চিত যে আপনি এই স্লিপ রেকর্ডটি মুছে ফেলতে চান?',
    'Sleep record deleted successfully!': 'স্লিপ রেকর্ডটি সফলভাবে মুছে ফেলা হয়েছে!',
    'Failed to delete sleep record!': 'স্লিপ রেকর্ডটি মুছতে ব্যর্থ হয়েছে!',
    'Profile picture updated locally!': 'প্রোফাইল ছবি লোকালি সেভ করা হয়েছে!',
    'Error saving profile picture locally: ': 'লোকালি ছবি সেভ করতে ব্যর্থ হয়েছে: ',
    'Topic': 'টপিক',
    'Planned Duration': 'পরিকল্পিত সময়',
    'Completed Duration': 'সম্পূর্ণ হওয়া সময়',
    'Time Window': 'নির্ধারিত সময়',
    'Challenges / Weaknesses': 'সমস্যা / দুর্বলতা',
    'No challenges recorded.': 'কোনো সমস্যা বা দুর্বলতা রেকর্ড করা হয়নি।',
    'Notes / Summary': 'নোট / সারসংক্ষেপ',
    'No notes recorded.': 'কোনো নোট রেকর্ড করা হয়নি।',
    'Completion Note': 'সমাপ্তির নোট',
    'Subject:': 'বিষয়:',
    'BCS': 'বিসিএস',
    'Bank': 'ব্যাংক',
    'Special Hub': 'স্পেশাল হাব',
    'Create Folder': 'ফোল্ডার তৈরি করুন',
    'Folder Name': 'ফোল্ডারের নাম',
    'Syllabus': 'সিলেবাস',
    'Subjects': 'বিষয়সমূহ',
    'Add Subject': 'বিষয় যুক্ত করুন',
    'Add Topic': 'টপিক যুক্ত করুন',
    'Subject Name': 'বিষয়',
    'Topic Name': 'টপিক',
    'Progress': 'অগ্রগতি',
    'Total Study Time': 'মোট পড়াশোনার সময়',
    'Success Rate': 'সফলতার হার',
    'Tasks in Folder': 'ফোল্ডারের টাস্কসমূহ',
    'Folder Deleted Successfully!': 'ফোল্ডার সফলভাবে মুছে ফেলা হয়েছে!',
    'Failed to delete folder!': 'ফোল্ডার মুছতে ব্যর্থ হয়েছে!',
    'Enter folder name': 'ফোল্ডারের নাম লিখুন',
    'Choose Color': 'রঙ নির্বাচন করুন',
    'No folders created yet': 'এখনো কোনো ফোল্ডার তৈরি করা হয়নি',
    'Tap the + button to create a folder': 'ফোল্ডার তৈরি করতে + বোতামটি চাপুন',
    'No subjects added yet': 'এখনো কোনো বিষয় যুক্ত করা হয়নি',
    'Enter subject name': 'বিষয়ের নাম লিখুন',
    'Enter topic name': 'টপিকের নাম লিখুন',
    'Are you sure you want to delete this folder?': 'আপনি কি নিশ্চিত যে আপনি এই ফোল্ডারটি মুছে ফেলতে চান?',
    'Are you sure you want to delete this subject?': 'আপনি কি নিশ্চিত যে আপনি এই বিষয়টি মুছে ফেলতে চান?',
    'Are you sure you want to delete this topic?': 'আপনি কি নিশ্চিত যে আপনি এই টপিকটি মুছে ফেলতে চান?',
    'Select Subject from Syllabus': 'সিলেবাস থেকে বিষয় নির্বাচন করুন',
    'Select Topic from Syllabus': 'সিলেবাস থেকে টপিক নির্বাচন করুন',
    'No topics in this subject': 'এই বিষয়ে কোনো টপিক নেই',
    'Subject Target': 'বিষয়ের লক্ষ্য',
    'Edit Target': 'লক্ষ্য সংশোধন করুন',
    'Save': 'সংরক্ষণ করুন',
    'Enter subject target or timeline...': 'বিষয়ের লক্ষ্য বা সময়সীমা লিখুন...',
    'Set a study target for this subject...': 'এই বিষয়ের জন্য একটি লক্ষ্য নির্ধারণ করুন...',
  };

  static const Map<String, String> _bnToEn = {
    // General
    'সব দেখুন': 'See All',
    'আজকের এখন কোনো টাস্ক লিস্টেড নেই।': 'No tasks listed for today.',
    'গ্যালারি থেকে বেছে নিন': 'Choose from Gallery',
    'ক্যামেরা দিয়ে ছবি তুলুন': 'Take photo with Camera',
    'উইকলি রুটিনে যুক্ত করুন (Add to Weekly)': 'Add to Weekly Routine',
    'Added to tomorrow\'s routine!': 'Added to tomorrow\'s routine!',
    'Added to ': 'Added to ',
    ' weekly routine!': ' weekly routine!',

    // Privacy policy section title
    '১. তথ্য সংগ্রহ (Information Collection)': '1. Information Collection',
    'StudyMate আপনার প্রোফাইল তৈরি করতে নাম, ইমেল এবং প্রোফাইল ছবি সংগ্রহ করে। আপনার স্টাডি সেশন, টাস্ক ট্র্যাকিং এবং ইসলামিক লাইফ স্ক্রিনের কার্যক্রম শুধুমাত্র আপনার ব্যক্তিগত অগ্রগতির জন্য ব্যবহার করা হয়।':
        'StudyMate collects your name, email and profile picture to create your profile. Your study sessions, task tracking and Islamic Life activities are only used for your personal progress.',
    '২. তথ্যের নিরাপত্তা (Data Security)': '2. Data Security',
    'আমরা আপনার তথ্যের নিরাপত্তা নিশ্চিত করতে Firebase Authentication এবং Cloud Firestore-এর সিকিউরিটি রুলস ব্যবহার করি। আপনার পাসওয়ার্ড ও ব্যক্তিগত তথ্য সম্পূর্ণ সুরক্ষিত অবস্থায় সংরক্ষিত থাকে।':
        'We use Firebase Authentication and Cloud Firestore security rules to ensure the safety of your information. Your password and personal data remain completely secure.',
    '৩. থার্ড-পার্টি সার্ভিস (Third-Party Services)': '3. Third-Party Services',
    'আমাদের অ্যাপটি Firebase (Google-এর অংশ) সার্ভিসসমূহ ব্যবহার করে ডেটা স্টোর ও অথেন্টিকেশনের জন্য। Google-এর প্রাইভেসি পলিসি অনুযায়ী এই ডেটা প্রসেস করা হয়।':
        'Our app uses Firebase (part of Google) services for data storage and authentication. This data is processed in accordance with Google\'s privacy policy.',
    '৪. আপনার অধিকার (Your Rights)': '4. Your Rights',
    'আপনি যেকোনো সময় আপনার প্রোফাইল এডিট করে তথ্য পরিবর্তন করতে পারেন অথবা আমাদের সাপোর্ট সেন্টারে যোগাযোগ করে আপনার অ্যাকাউন্ট ও সংশ্লিষ্ট সকল ডেটা সম্পূর্ণ মুছে ফেলার অনুরোধ জানাতে পারেন।':
        'You can edit your profile information at any time or contact our support center to request complete deletion of your account and all associated data.',
  };
}
