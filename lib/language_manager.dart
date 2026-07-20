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
    String translated;
    if (_currentLanguage == 'bn') {
      translated = _enToBn[key] ?? key;
    } else {
      translated = _bnToEn[key] ?? key;
    }
    return _cleanBilingualString(translated, _currentLanguage);
  }

  String _cleanBilingualString(String input, String langCode) {
    if (input.length > 80 || input.contains('\n')) {
      return input;
    }
    if (!input.contains('(') || !input.contains(')')) {
      return input;
    }

    final openParen = input.indexOf('(');
    final closeParen = input.indexOf(')', openParen);
    if (closeParen == -1) return input;

    final partA = input.substring(0, openParen).trim();
    final partB = input.substring(openParen + 1, closeParen).trim();

    final hasBengaliA = _containsBengali(partA);
    final hasBengaliB = _containsBengali(partB);
    final hasEnglishA = _containsEnglish(partA);
    final hasEnglishB = _containsEnglish(partB);

    // Check if it's actually bilingual (one part has Bengali, the other has English)
    final isBilingual = (hasBengaliA && !hasBengaliB && hasEnglishB) ||
                        (!hasBengaliA && hasBengaliB && hasEnglishA);

    if (!isBilingual) {
      // If both parts are Bengali or both are English, do not strip!
      return input;
    }

    if (langCode == 'bn') {
      return hasBengaliA ? partA : partB;
    } else {
      return hasEnglishA ? partA : partB;
    }
  }

  bool _containsBengali(String text) {
    final reg = RegExp(r'[\u0980-\u09ff]');
    return reg.hasMatch(text);
  }

  bool _containsEnglish(String text) {
    final reg = RegExp(r'[a-zA-Z]');
    return reg.hasMatch(text);
  }


  static const Map<String, String> _enToBn = {
    // Alarm Repeat translation additions
    'Alarm Repeat': 'অ্যালার্ম পুনরাবৃত্তি',
    'Loop Continuously': 'লুপে বাজতে থাকবে',
    '1 Time': '১ বার',
    '2 Times': '২ বার',
    '3 Times': '৩ বার',
    '4 Times': '৪ বার',
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
    
    // Cloud Backup & Sync
    'Cloud Backup & Sync': 'ক্লাউড ব্যাকআপ এবং সিঙ্ক',
    'Secure Your Data': 'আপনার ডেটা সুরক্ষিত করুন',
    'Your data is automatically synced with Firebase while online. You can also create a manual backup to Firebase Storage to secure your diary, notes, flashcards, and progress across devices.': 'আপনার ডেটা অনলাইনে থাকাকালীন স্বয়ংক্রিয়ভাবে ফায়ারবেসের সাথে সিঙ্ক হয়। ডিভাইস পরিবর্তন করলেও আপনার ডায়েরি, নোট, ফ্ল্যাশকার্ড এবং প্রোগ্রেস সুরক্ষিত রাখতে আপনি ম্যানুয়ালি ব্যাকআপ নিতে পারেন।',
    'Last Backup': 'সর্বশেষ ব্যাকআপ',
    'No backup found': 'কোনো ব্যাকআপ পাওয়া যায়নি',
    'Backup Now': 'এখন ব্যাকআপ নিন',
    'Restore Data': 'ডেটা রিস্টোর করুন',
    'Backup successful!': 'ব্যাকআপ সফল হয়েছে!',
    'Backup failed: ': 'ব্যাকআপ ব্যর্থ হয়েছে: ',
    'Restore Backup': 'ব্যাকআপ রিস্টোর করুন',
    'Are you sure you want to restore your data? This will merge your backed up data with your current data.': 'আপনি কি নিশ্চিত যে আপনি আপনার ডেটা রিস্টোর করতে চান? এটি আপনার বর্তমান ডেটার সাথে ব্যাকআপ ডেটা মার্জ করবে।',
    'Restore successful!': 'রিস্টোর সফল হয়েছে!',
    'Restore failed: ': 'রিস্টোর ব্যর্থ হয়েছে: ',
    'Drive backup successful!': 'গুগল ড্রাইভ ব্যাকআপ সফল হয়েছে!',
    'Drive backup failed: ': 'গুগল ড্রাইভ ব্যাকআপ ব্যর্থ হয়েছে: ',
    'Restore from Google Drive': 'গুগল ড্রাইভ থেকে রিস্টোর করুন',
    'Are you sure you want to restore your data from Google Drive? This will merge your backed up data with your current data.': 'আপনি কি নিশ্চিত যে আপনি গুগল ড্রাইভ থেকে আপনার ডেটা রিস্টোর করতে চান? এটি আপনার বর্তমান ডেটার সাথে ব্যাকআপ ডেটা মার্জ করবে।',
    'Restore from Drive successful!': 'ড্রাইভ থেকে রিস্টোর সফল হয়েছে!',
    'Restore from Drive failed: ': 'ড্রাইভ থেকে রিস্টোর ব্যর্থ হয়েছে: ',
    'Keep your diary, notes, and tasks safe. Choose where you want to store your backup.': 'আপনার ডায়েরি, নোট এবং টাস্কগুলো সুরক্ষিত রাখুন। ব্যাকআপ কোথায় সেভ করবেন তা নির্বাচন করুন।',
    'Firebase Storage': 'ফায়ারবেস স্টোরেজ',
    'Your data is automatically synced with Firebase while online. Manual backups are stored securely on our servers for easy recovery.': 'আপনার ডেটা অনলাইনে থাকাকালীন স্বয়ংক্রিয়ভাবে ফায়ারবেসের সাথে সিঙ্ক হয়। রিকভার করার সুবিধার্থে ম্যানুয়াল ব্যাকআপ আমাদের সার্ভারে সুরক্ষিত থাকে।',
    'Google Drive': 'গুগল ড্রাইভ',
    'Export a copy of your data directly to your personal Google Drive account. You have full control over your backup file.': 'আপনার ডেটার একটি কপি সরাসরি আপনার ব্যক্তিগত গুগল ড্রাইভ অ্যাকাউন্টে এক্সপোর্ট করুন। ব্যাকআপ ফাইলের সম্পূর্ণ নিয়ন্ত্রণ আপনার হাতেই থাকবে।',
    'Recommended': 'প্রস্তাবিত',
    'Restore': 'রিস্টোর',
    'Backup': 'ব্যাকআপ',

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
    'about_us_description': 'স্টাডিমেট (StudyMate) হলো একটি অল-ইন-ওয়ান প্রোডাক্টিভিটি অ্যাপ, যা স্কুল, কলেজ, বিশ্ববিদ্যালয় এবং বিসিএস বা ব্যাংক জবসহ বিভিন্ন প্রতিযোগিতামূলক পরীক্ষার পরীক্ষার্থীদের জন্য বিশেষভাবে ডিজাইন করা হয়েছে।\n\nআমাদের লক্ষ্য হলো আপনাকে আরও স্মার্টলি পড়াশোনা করতে সাহায্য করা, শৃঙ্খলিত রাখা এবং একটি স্বাস্থ্যকর ও ভারসাম্যপূর্ণ জীবনধারা বজায় রাখতে সহায়তা করা।\n\nমূল ফিচারসমূহ:\n• স্মার্ট স্টাডি প্ল্যানার: কাস্টম রুটিন এবং এআই (AI) জেনারেটরের মাধ্যমে আপনার দৈনিক ও সাপ্তাহিক পড়াশোনা খুব সহজেই সাজিয়ে নিন।\n• ফোকাস ও প্রোডাক্টিভিটি: পোমোডোরো টাইমার, স্টপওয়াচ, ফোকাস মিউজিক এবং ডেডিকেটেড ফোকাস মোডের সাহায্যে পড়াশোনায় গভীর মনোযোগ ধরে রাখুন।\n• কার্যকর লার্নিং টুলস: ফ্ল্যাশকার্ড, ডিকশনারি, পিডিএফ রিডার এবং বৈজ্ঞানিক ১-৪-৭ রিভিশন পদ্ধতির মাধ্যমে পড়া সহজে মনে রাখুন।\n• সহযোগিতামূলক পড়াশোনা: সোশ্যাল হাব, স্টাডি রুম এবং পার্টনার টাস্কের মাধ্যমে বন্ধুদের সাথে যুক্ত থেকে একসাথে পড়াশোনা করুন।\n• সুস্থতা ও ইসলামিক লাইফ: ঘুম ও মেজাজ ট্র্যাক করুন, শ্বাস-প্রশ্বাসের ব্যায়াম করুন এবং নামাজের সময়সূচী, কুরআন, কিবলা কম্পাস ও তাসবিহ রিডারের মতো ফিচারগুলো ব্যবহার করুন।\n• গ্যামিফিকেশন: প্রতিদিনের স্ট্রিক বজায় রেখে এক্সপি (XP), লেভেল এবং ব্যাজ আনলক করে নিজের পড়ার আগ্রহ দ্বিগুণ করুন।\n\nপরবর্তী ক্লাস কিংবা ক্যারিয়ার গড়ার যুদ্ধ—আপনার প্রতিটি পদক্ষেপে স্টাডিমেট থাকবে আপনার বিশ্বস্ত সারথী হিসেবে!',
    'Add New Task': 'নতুন টাস্ক যুক্ত করুন',
    'Add to Next-day Routine': 'নেক্সট ডে রুটিনে যুক্ত করুন',
    'Add Shared Task': 'নতুন শেয়ার্ড টাস্ক যুক্ত করুন',
    'Reschedule': 'রিশিডিউল',
    'Reschedule Task': 'টাস্ক রিশিডিউল করুন',
    'Select Date': 'তারিখ নির্বাচন করুন',
    'Today': 'আজ',
    'Tomorrow': 'আগামীকাল',
    'Confirm Reschedule': 'রিশিডিউল নিশ্চিত করুন',
    'Reschedule successful!': 'রিশিডিউল সফল হয়েছে!',
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
    'Peak Focus Hours': 'পিক ফোকাস আওয়ার',
    'Monthly Study Trend': 'মাসিক স্টাডি ট্রেন্ড',
    'Study Calendar Heatmap': 'স্টাডি ক্যালেন্ডার হিটম্যাপ',
    'Less': 'কম',
    'More': 'বেশি',

    'Collaborative Studying': 'যৌথ পড়াশোনা',
    'Study Room': 'স্টাডি রুম',
    'Partner Tasks': 'পার্টনার টাস্ক',
    'done this task': 'এই টাস্কটি সম্পন্ন করেছেন',
    'You have done this task': 'আপনি এই টাস্কটি সম্পন্ন করেছেন',
    'Partner Task': 'পার্টনার টাস্ক',
    'P Task': 'পি টাস্ক',
    'Warning': 'সতর্কবার্তা',
    'OK': 'ঠিক আছে',
    'Removed': 'রিমুভ করা হয়েছে',
    'You have not completed 80% of your shared tasks. Please complete them. If you still do not complete them after being warned 3 times every 3 hours, you will be removed from this partner space.': 'আপনি আপনার শেয়ার করা টাস্কগুলোর ৮০% শেষ করেননি। দয়া করে টাস্কগুলো শেষ করুন। প্রতি ৩ ঘণ্টা পর পর ৩ বার সতর্ক করার পরেও সম্পন্ন না করলে আপনাকে এই পার্টনার স্পেস থেকে রিমুভ করা হবে।',
    'You have been removed from this partner space for not completing 80% of your tasks on time. To enter again, you must obtain the code and join again.': 'টাস্কের ৮০% সময়মতো সম্পন্ন না করায় আপনাকে এই পার্টনার স্পেস থেকে রিমুভ করা হয়েছে। পুনরায় ঢুকতে হলে আপনাকে আবার কোড সংগ্রহ করে প্রবেশ করতে হবে।',
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
    'Study Map': 'স্টাডি ম্যাপ',
    'Web Study': 'ওয়েব স্টাডি',
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
    'Please select start and end time.': 'অনুগ্রহ করে শুরু ও শেষের সময় দিন',
    'End time must be after start time.': 'শেষের সময় শুরুর সময়ের পরে হতে হবে',
    'Failed to save task.': 'টাস্ক সেভ করতে সমস্যা হয়েছে',
    'PDFs imported successfully!': 'টি PDF সফলভাবে ইম্পোর্ট হয়েছে!',
    'Error importing PDF:': 'PDF ইম্পোর্টে সমস্যা হয়েছে:',
    "Yesterday's Missed Tasks": 'গতকালের মিসড টাস্ক',
    'You have some missed tasks from yesterday:': 'আপনার গতকালের কিছু টাস্ক বাকি আছে:',
    'Reminder set for': 'রিমাইন্ডার সেট করা হয়েছে',
    'Remind me later': 'পরে মনে করান',
    'Take a Short Break': 'একটু বিরতি নিন',
    'Stay Focused': 'মনোযোগ ধরে রাখুন',
    'You have been working for almost 4 hours. A short breathing exercise will help boost your concentration.': 'আপনি প্রায় চারঘণ্টা একাধারে কাজ করে যাচ্ছেন, একটু ব্রিথিং এক্সারসাইজ আপনার মনোযোগ বাড়াতে সাহায্য করবে।',
    'Let us take a short breathing exercise to improve focus and relieve fatigue!': 'পড়াশোনায় মনোযোগ বাড়াতে এবং ক্লান্তি দূর করতে চলুন একটু ব্রিথিং এক্সারসাইজ করে নিই!',
    'Not Now': 'এখন না',
    'Do Exercise': 'এক্সারসাইজ করুন',
    'Confirm': 'নিশ্চিত করুন',
    'Are you sure you want to exit the app?': 'আপনি কি সত্যিই অ্যাপ থেকে বের হতে চান?',
    'Yes': 'হ্যাঁ',
    'Did you face any challenges? (Notes)': 'পড়তে গিয়ে কোনো সমস্যার সম্মুখীন হয়েছেন কি? (নোট)',
    'Write your notes here...': 'আপনার নোট লিখুন...',
    'Add to Weekly Routine': 'উইকলি রুটিনে যুক্ত করুন',
    'Change Password': 'পাসওয়ার্ড পরিবর্তন',
    'Countdown': 'কাউন্টডাউন',
    'Notification Settings': 'নোটিফিকেশন সেটিংস',
    'Notification Configuration': 'নোটিফিকেশন কনফিগারেশন',
    'Customize your study alerts and reminders.': 'আপনার পড়াশোনার তাগিদ ও রিমাইন্ডার কাস্টমাইজ করুন।',
    'Global Notifications': 'গ্লোবাল নোটিফিকেশন',
    'Keep all app notifications on or off': 'অ্যাপের সকল নোটিফিকেশন চালু বা বন্ধ রাখুন',
    'Study Goal Reminders': 'স্টাডি গোল রিমাইন্ডার',
    'Remind if daily study goal is not met': 'দৈনিক পড়াশোনার লক্ষ্য পূরণ না হলে মনে করিয়ে দেওয়া',
    'Task Deadline Alerts': 'টাস্ক সময়সীমা অ্যালার্ট',
    'Send notification before a specific task ends': 'কোনো নির্দিষ্ট কাজ শেষ হওয়ার পূর্বে নোটিফিকেশন পাঠানো',
    'Revision Reminders': 'রিভিশন রিমাইন্ডার',
    'Remind of revision for 1-4-7 spaced revision schedule': '১-৪-৭ স্পেসড রিভিশন শিডিউলের রিভিশন মনে করিয়ে দেওয়া',
    'Social Notifications': 'সোশ্যাল নোটিফিকেশন',
    'New friend requests or Social Hub update notifications': 'নতুন ফ্রেন্ড রিকোয়েস্ট বা সোশ্যাল হাবের আপডেট নোটিফিকেশন',
    'Motivational Push': 'অনুপ্রেরণামূলক পুশ',
    'Motivational messages to start studying every day': 'প্রতিদিন পড়াশোনা শুরু করার জন্য মোটিভেশনাল মেসেজ',
    'Sound & Vibration Settings': 'সাউন্ড ও ভাইব্রেশন সেটিংস',
    'Notification Sound': 'নোটিফিকেশন সাউন্ড',
    'Play sound when receiving notifications': 'নোটিফিকেশন আসার সময়ে সাউন্ড প্লে হবে',
    'Active (ON)': 'চালু (ON)',
    'Disabled (OFF)': 'বন্ধ (OFF)',
    'Vibration': 'ভাইব্রেশন',
    'Vibrate device when receiving notifications': 'নোটিফিকেশন আসার সাথে ডিভাইস ভাইব্রেট করবে',
    'Push Notification Sound': 'পুশ নোটিফিকেশন সাউন্ড',
    'Test Sound': 'টেস্ট সাউন্ড',
    'Alarm Sound': 'অ্যালার্ম সাউন্ড',
    'Volume Level': 'সাউন্ডের মাত্রা',
    'Special Note: The prayer time and Azan alarms for the Islamic Life feature are exempt from this global setting. To fully control prayer notifications, please go to the "Islamic Life" option.': 'বিশেষ দ্রষ্টব্য: ইসলামিক লাইফ ফিচারের নামাজের ওয়াক্ত ও আযানের অ্যালার্মগুলো এই গ্লোবাল সেটিং এর আওতামুক্ত। নামাজের নোটিফিকেশনগুলো সম্পূর্ণভাবে নিয়ন্ত্রণ করতে দয়া করে "Islamic Life" অপশনে যান।',
    'Create your study routine for tomorrow.': 'আগামীকালের পড়ার রুটিন তৈরি করুন',
    'Customize and update your weekly routine.': 'সাপ্তাহিক রুটিন কাস্টমাইজ ও আপডেট করুন',
    'Choose from phone...': 'ফোন থেকে সিলেক্ট করুন',
    'Start': 'শুরু করুন',
    'Pause': 'বিরতি',
    'Resume': 'আবার শুরু',
    'Done': 'সম্পন্ন',
    'Edit': 'সম্পাদনা',
    'Reactions': 'রিঅ্যাকশনস',
    'Copy Text': 'কপি করুন',
    'Message copied to clipboard!': 'মেসেজ ক্লিপবোর্ডে কপি করা হয়েছে!',
    'Reply': 'রিপ্লাই',
    'Replying to': 'রিপ্লাই দিচ্ছেন',
    'This message was deleted': 'এই বার্তাটি মুছে ফেলা হয়েছে',
    'Edited': 'সম্পাদিত',
    'Editing Message': 'মেসেজ এডিট করা হচ্ছে',
    'Delete Message': 'বার্তাটি মুছুন',
    'Are you sure you want to delete this message?': 'আপনি কি নিশ্চিত যে আপনি এই বার্তাটি মুছে ফেলতে চান?',
    'Seen': 'সিন',
    'Auto Login': 'অটো লগইন',
    'Security Settings': 'নিরাপত্তা সেটিংস',
    'Remembers you on this device': 'ডিভাইসে আপনাকে মনে রাখবে',
    'Monthly Password Check': 'মাসে একবার পাসওয়ার্ড যাচাইকরণ',
    'Force login once a month so you do not forget your password': 'মাসে একবার ইমেইল-পাসওয়ার্ড দিয়ে লগইন করানো হবে যাতে ভুলে না যান',
    'Requires Internet': 'ইন্টারনেট প্রয়োজন',
    'Biometric Unlock': 'বায়োমেট্রিক আনলক',
    'Do you want to enable Fingerprint/Face Unlock?': 'আপনি কি ফিঙ্গারপ্রিন্ট/ফেস আনলক চালু করতে চান?',
    'Set a 4-Digit Security PIN': 'একটি ৪-ডিজিটের পিন সেট করুন',
    'Confirm your 4-Digit PIN': 'আপনার পিনটি নিশ্চিত করুন',
    'Enter PIN to Unlock': 'আনলক করতে পিন দিন',
    'Enter PIN to Disable Lock': 'লক বন্ধ করতে পিন দিন',
    'PINs do not match. Try again.': 'পিন ম্যাচ করেনি, আবার চেষ্টা করুন।',
    'Incorrect PIN': 'ভুল পিন',
    'Forgot PIN?': 'পিন ভুলে গেছেন?',
    'If you forget your PIN, you must log out and log back in to reset it. Do you want to log out now?': 'পিন ভুলে গেলে রিসেটের জন্য আপনাকে লগআউট করতে হবে। আপনি কি এখনই লগআউট করতে চান?',
    'Accept': 'গ্রহণ করুন',
    'Where would you like to go?': 'আপনি কোথায় যেতে চান?',
    'Messages': 'মেসেজ',
    'Friend Requests': 'ফ্রেন্ড রিকোয়েস্ট',
    'This profile is private.': 'এই প্রোফাইলটি ব্যক্তিগত।',
    'You must be friends with this user to view their task list.': 'এই ইউজারের টাস্ক লিস্ট দেখতে হলে আপনাকে অবশ্যই তার ফ্রেন্ডলিস্টে থাকতে হবে।',

    // Islamic Life & Prayer History
    'Prayer History & Report': 'নামাজের ইতিহাস ও রিপোর্ট',
    'Today\'s Prayer Status': 'আজকের নামাজের অবস্থা',
    'All Completed': 'সব আদায়',
    'Waqt Missed': 'ওয়াক্ত মিস',
    'Daily': 'দৈনিক',
    'Weekly': 'সাপ্তাহিক',
    'Monthly': 'মাসিক',
    'Yearly': 'বাৎসরিক',
    'Detailed Report': 'বিস্তারিত রিপোর্ট',
    'Past prayer history is locked and cannot be edited.': 'অতীতের নামাজের ইতিহাস লক করা রয়েছে, এটি পরিবর্তন করা যাবে না।',
    'Missed Prayer Details': 'মিস যাওয়া নামাজের বিস্তারিত',
    'No missed prayers found for this period!': 'এই সময়ে কোনো ওয়াক্ত নামাজ মিস যায়নি, আলহামদুলিল্লাহ!',
    'Fajr': 'ফজর',
    'Dhuhr': 'যোহর',
    'Jumma': 'জুমা',
    'Asr': 'আসর',
    'Maghrib': 'মাগরিব',
    'Isha': 'এশা',
    'Alhamdulillah, no prayers were missed today.': 'আলহামদুলিল্লাহ, আজকের কোনো ওয়াক্ত নামাজ মিস নাই।',
    'Alhamdulillah, no prayers were missed this week.': 'আলহামদুলিল্লাহ, এই সপ্তাহে কোনো ওয়াক্ত নামাজ মিস নাই।',
    'Alhamdulillah, no prayers were missed this month.': 'আলহামদুলিল্লাহ, এই মাসে কোনো ওয়াক্ত নামাজ মিস নাই।',
    'Alhamdulillah, no prayers were missed this year.': 'আলহামদুলিল্লাহ, এই বছরে কোনো ওয়াক্ত নামাজ মিস নাই।',
    'prayers missed today.': 'ওয়াক্ত নামাজ আজ মিস গেছে।',
    'prayers missed this week.': 'ওয়াক্ত নামাজ এই সপ্তাহে মিস গেছে।',
    'prayers missed this month.': 'ওয়াক্ত নামাজ এই মাসে মিস গেছে।',
    'prayers missed this year.': 'ওয়াক্ত নামাজ এই বছরে মিস গেছে।',
    'Yesterday': 'গতকাল',
    'Islamic Features': 'আজকের গুরুত্বপূর্ণ ফিচারসমূহ',
    'Today\'s Verse': 'আজকের আয়াত',
    'Today\'s Hadith': 'আজকের হাদিস',
    'Quran Sharif': 'কুরআন কারীম',
    'Holy Quran Sharif': 'পবিত্র কুরআন শরীফ',
    'Surah-based Reading • Hafezi Quran (604 Pages) • Offline Support': 'সুরা-ভিত্তিক পাঠ • হাফেজি কুরআন (৬০৪ পৃষ্ঠা) • অফলাইন সাপোর্ট',
    'Qibla Compass': 'কিবলা কম্পাস',
    'Qibla Direction': 'কিবলা দিকনির্দেশনা',
    'Tasbeeh Counter': 'তাসবিহ কাউন্টার',
    'Prayer Schedule': 'নামাজের সময়সূচী',
    'Friday Special Deeds': 'জুম্মাবারের বিশেষ আমলসমূহ',
    'Complete Friday Sunnahs': 'আজকের দিনের সুন্নত আমলগুলো সম্পন্ন করুন',
    'Study Duas & Deeds': 'পড়াশোনার দোয়া ও আমল',
    'Memory Increase • Easy Learning • Duas before Study': 'স্মৃতিশক্তি বৃদ্ধি • কঠিন বিষয় সহজ হওয়া • পড়াশোনা শুরুর দোয়া',
    'Today\'s Hijri Date:': 'আজকের হিজরি তারিখ:',
    'Perform Ghusl (Bath)': 'গোসল করা',
    'Wear Clean Clothes & Apply Attar': 'পরিষ্কার পোশাক পরা ও সুগন্ধি লাগানো',
    'Recite Surah Al-Kahf': 'সূরা আল-কাহাফ তেলাওয়াত করা',
    'Send Salawat / Durood upon Prophet (pbuh)': 'রাসূলুল্লাহ (সা.) এর ওপর দরুদ পাঠ করা',
    'Go Early to Mosque for Jummah': 'জুমার সালাতে আগে যাওয়া',
    'Dua collection for studying and boosting memory': 'পড়াশোনা শুরু ও মেধা বিকাশের দোয়া কালেকশন',
    'Urgent Waqt End Countdown': 'জরুরী ওয়াক্ত শেষ হওয়ার কাউন্টডাউন',
    'Jumma Mubarak': 'জুম্মাবার মোবারক',
    'Prayer Countdown': 'নামাজের কাউন্টডাউন',
    'Time Remaining to End': 'ওয়াক্ত শেষ হতে বাকি সময়',
    'Time Remaining to Start': 'শুরু হতে বাকি সময়',
    'Sunrise': 'সূর্যোদয়',
    'Sunset': 'সূর্যাস্ত',
    'Ongoing': 'চলমান',
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
    'about_us_description': 'StudyMate is the ultimate all-in-one productivity companion designed specifically for school, college, and university students, as well as competitive exam candidates (such as BCS and Bank exams).\n\nOur mission is to help you study smarter, stay disciplined, and maintain a healthy, balanced lifestyle.\n\nKey Features:\n• Smart Study Planner: Plan your days and weeks effortlessly with our custom Study Planner and AI Routine Generator.\n• Focus & Productivity: Beat distractions with the Pomodoro Timer, Stopwatch, Focus Music, and dedicated Focus Mode.\n• Effective Learning Aids: Enhance retention using Flashcards, a built-in Dictionary, PDF Reader, and the scientific 1-4-7 Revision method.\n• Collaborative Studying: Connect with peers through the Social Hub, Study Rooms, and shared Partner Tasks.\n• Well-being & Islamic Life: Track your sleep and mood, practice breathing exercises, and access spiritual tools like Prayer Times, Quran, Qibla Compass, and Tasbeeh.\n• Gamification: Stay motivated with Daily Streaks, XP points, Levels, and Unlocked Badges.\n\nWhether you are preparing for your next class or a major career exam, StudyMate is here to guide you every step of the way!',
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
