import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'dart:math';

void main() async {
  // Ensure that Flutter binding is initialized
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize Firebase
  await Firebase.initializeApp();

  runApp(const StudyMateApp());
}

class StudyMateApp extends StatelessWidget {
  const StudyMateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'StudyMate',
      debugShowCheckedModeBanner: false, // ডানদিকের রেড ট্যাগটি লুকানোর জন্য
      theme: ThemeData( // Use colorScheme instead of the deprecated primarySwatch
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ), // প্রফেশনাল কালার
      home: const SplashScreen(),
    );
  }
}

// ==========================================
// 1. Splash Screen (স্প্ল্যাশ স্ক্রিন)
// ==========================================

// ... (SplashScreen code remains the same)

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // ২ সেকেন্ড পর স্বয়ংক্রিয়ভাবে লগইন পেইজে চলে যাবে
    Future.delayed(const Duration(seconds: 2), () {
      // চেক করবে ইউজার আগে থেকে লগইন করা আছে কিনা
      if (FirebaseAuth.instance.currentUser != null) {
        Navigator.pushReplacement(
          context, // Navigate to FocusModeScreen if logged in
          MaterialPageRoute(builder: (context) => const FocusModeScreen()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.indigo,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.school,
              size: 100,
              color: Colors.white,
            ),
            const SizedBox(height: 20),
            const Text(
              'StudyMate',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Your Educational Companion',
              style: TextStyle(
                fontSize: 16,
            color: Colors.white.withOpacity(0.8), // Already correct, no change needed
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 2. Login Screen (লগইন স্ক্রিন)
// ==========================================
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isPasswordVisible = false;
  bool _isLoading = false;
  final _formKey = GlobalKey<FormState>(); // Add a GlobalKey for the Form

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // লগইন করার ফায়ারবেস লজিক
  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) {
      return; // If form is not valid, do not proceed
    }

    setState(() => _isLoading = true);
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      if (mounted) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const FocusModeScreen()));
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        String message;
        if (e.code == 'user-not-found') {
          message = 'No user found for that email.';
        } else if (e.code == 'wrong-password') {
          message = 'Wrong password provided for that user.';
        } else if (e.code == 'invalid-email') {
          message = 'The email address is not valid.';
        } else if (e.code == 'user-disabled') {
          message = 'This user account has been disabled.';
        }
        else {
          message = e.message ?? 'Login failed. Please try again.';
        }
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Form( // Wrap your Column with a Form widget
            key: _formKey, // Assign the form key
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // লোগো এবং শিরোনাম
                const Icon(Icons.school, size: 80, color: Colors.indigo),
                const SizedBox(height: 10),
                const Text(
                  'StudyMate',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.indigo,
                  ),
                ),
                const SizedBox(height: 40),

                // ইমেইল ইনপুট
                TextFormField( // Use TextFormField for validation
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) { // Add validator
                    if (value == null || value.isEmpty) {
                      return 'Please enter your email';
                    }
                    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                      return 'Please enter a valid email address';
                    }
                    return null;
                  },
                  decoration: InputDecoration(
                    labelText: 'Email Address',
                    prefixIcon: const Icon(Icons.email_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),),),),
                const SizedBox(height: 16),

                // পাসওয়ার্ড ইনপুট
                TextFormField(
                  controller: _passwordController,
                  obscureText: !_isPasswordVisible,
                  validator: (value) { // Add validator
                    if (value == null || value.isEmpty) {
                      return 'Please enter your password';
                    }
                    return null;
                  },
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() {
                          _isPasswordVisible = !_isPasswordVisible;
                        });
                      },
                    ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),),
                  ),
                ),

                // ফরগেট পাসওয়ার্ড
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      // ফরগেট পাসওয়ার্ড লজিক এখানে হবে
                    },
                    child: const Text('Forgot Password?'),
                  ),
                ),
                const SizedBox(height: 10),

                // লগইন বাটন (ইমেইল দিয়ে)
                ElevatedButton(
                  onPressed: _isLoading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading 
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Log In',
                          style: TextStyle(fontSize: 18, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 24),

                // সাইন আপ বাটন
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("Don't have an account?"),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const SignUpScreen()),
                        );
                      },
                      child: const Text(
                        'Create New Account',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          ),
        ),
      ),
    );
  }
}

// ==========================================
// 3. Sign Up Screen (সাইন আপ স্ক্রিন)
// ==========================================
class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _isLoading = false;
  final _formKey = GlobalKey<FormState>(); // Add a GlobalKey for the Form

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // সাইন-আপ করার ফায়ারবেস লজিক
  Future<void> _signUp() async {
    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Passwords do not match!')));
      return;
    }
    if (!_formKey.currentState!.validate()) {
      return; // If form is not valid, do not proceed
    }

    setState(() => _isLoading = true);
    try {
      UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      await userCredential.user?.updateDisplayName(_nameController.text.trim());
      if (mounted) {
        Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const FocusModeScreen()), (route) => false);
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        String message;
        if (e.code == 'weak-password') {
          message = 'The password provided is too weak.';
        } else if (e.code == 'email-already-in-use') {
          message = 'The email address is already in use by another account.';
        } else if (e.code == 'invalid-email') {
          message = 'The email address is not valid.';
        } else if (e.code == 'operation-not-allowed') {
          message = 'Email/password accounts are not enabled.';
        }
        else {
          message = e.message ?? 'Sign up failed. Please try again.';
        }
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.indigo),
          onPressed: () {
            Navigator.pop(context); // আগের পেইজে (Login) ফিরে যাওয়ার লজিক
          },
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Form( // Wrap your Column with a Form widget
              key: _formKey, // Assign the form key
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // শিরোনাম
                const Text(
                  'Create Account',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.indigo,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Sign up to get started!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 40),

                // নাম ইনপুট
                TextFormField( // Use TextFormField for validation
                  controller: _nameController,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your full name';
                    }
                    return null;
                  },
                  decoration: InputDecoration(
                    labelText: 'Full Name',
                    prefixIcon: const Icon(Icons.person_outline),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),),),),
                const SizedBox(height: 16),

                // ইমেইল ইনপুট
                TextFormField( // Use TextFormField for validation
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your email';
                    }
                    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                      return 'Please enter a valid email address';
                    }
                    return null;
                  },
                  decoration: InputDecoration(
                    labelText: 'Email Address',
                    prefixIcon: const Icon(Icons.email_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),),),),
                const SizedBox(height: 16),

                // পাসওয়ার্ড ইনপুট
                TextFormField( // Use TextFormField for validation
                  controller: _passwordController,
                  obscureText: !_isPasswordVisible,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a password';
                    }
                    if (value.length < 6) {
                      return 'Password must be at least 6 characters long';
                    }
                    return null;
                  },
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() {
                          _isPasswordVisible = !_isPasswordVisible;
                        });
                      },
                    ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),),),),
                const SizedBox(height: 16),

                // কনফার্ম পাসওয়ার্ড ইনপুট
                TextFormField( // Use TextFormField for validation
                  controller: _confirmPasswordController,
                  obscureText: !_isConfirmPasswordVisible,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please confirm your password';
                    }
                    if (value != _passwordController.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                  decoration: InputDecoration(
                    labelText: 'Confirm Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isConfirmPasswordVisible ? Icons.visibility : Icons.visibility_off,
                      ), 
                      onPressed: () {
                        setState(() {
                          _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
                        });
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 30),

                // সাইন আপ বাটন
                ElevatedButton(
                  onPressed: _isLoading ? null : _signUp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading 
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Sign Up',
                          style: TextStyle(fontSize: 18, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
          ),
        ),
      ),
    );
  }
}

// ==========================================
// 5. Focus Mode Screen (ফোকাস মোড স্ক্রিন)
// ==========================================
class FocusModeScreen extends StatefulWidget {
  const FocusModeScreen({super.key});

  @override
  State<FocusModeScreen> createState() => _FocusModeScreenState();
}

class _FocusModeScreenState extends State<FocusModeScreen> {
  String _randomQuote = '';

  // আপনার দেওয়া বাণীগুলির তালিকা
  final List<String> _quotes = [
    "\"স্বপ্ন সেটা নয় যা তুমি ঘুমিয়ে দেখো, স্বপ্ন হলো সেটাই যা তোমাকে ঘুমাতে দেয় না।\"\n– এ. পি. জে. আব্দুল কালাম",
    "\"সাফল্য হলো প্রতিদিনের ছোট ছোট প্রচেষ্টার নিরলস যোগফল।\"\n– রবার্ট কলিয়ার",
    "\"কাজ শুরু করার সেরা উপায় হলো কথা বলা বন্ধ করে কাজে লেগে পড়া।\"\n– ওয়াল্ট ডিজনি",
    "\"সময়ের সঠিক ব্যবহারই সাফল্যের মূল চাবিকাঠি।\"\n– বেঞ্জামিন ফ্র্যাঙ্কলিন",
    "\"শুরু করার জন্য মহান হওয়ার দরকার নেই, কিন্তু মহান হতে হলে তোমাকে শুরু করতে হবে।\"\n– জিগ জিগলার",
    "\"তুমি যদি তোমার সময়কে মূল্যায়ন না করো, তবে অন্যরাও করবে না।\"\n– কিম গার্স্ট",
    "\"ভবিষ্যৎ তাদেরই যারা তাদের স্বপ্নের সৌন্দর্যে বিশ্বাস করে।\"\n– এলিনর রুজভেল্ট",
    "\"পরাজয় মানেই সব শেষ নয়, বরং এটি নতুন করে আরও বুদ্ধিমানের মতো শুরু করার সুযোগ।\"\n– হেনরি ফোর্ড",
    "\"নিজেকে বদলাও, ভাগ্য নিজেই বদলে যাবে।\"\n– স্বামী বিবেকানন্দ",
    "\"তুমি যদি ক্লান্ত হয়ে পড়ো, তবে বিশ্রাম নিতে শেখো, হাল ছাড়তে নয়।\"\n– ব্যাংকসি",
    "\"সাফল্যের কোনো শর্টকাট নেই, কঠোর পরিশ্রমই একমাত্র পথ।\"\n– কলিন পাওয়েল",
    "\"যেখানে পরিশ্রম নেই, সেখানে কোনো সাফল্য নেই।\"\n– সোফোক্লিস",
    "\"সুযোগ আসে না, সুযোগ তৈরি করে নিতে হয়।\"\n– ক্রিস গ্রসার",
    "\"বিদ্যা অর্জন হলো এমন এক সম্পদ, যা কেউ তোমার কাছ থেকে কেড়ে নিতে পারবে না।\"\n– বি. বি. কিং",
    "\"ব্যর্থতা হলো সাফল্যের মশলা যা এর স্বাদ বাড়িয়ে দেয়।\"\n– ট্রুম্যান ক্যাপোটে",
    "\"তোমার আজকের পরিশ্রম তোমার আগামীকালের ভবিষ্যৎ নির্ধারণ করবে।\"\n– সংগৃহীত",
    "\"আজকের দিনটি আর কখনো ফিরে আসবে না, তাই প্রতিটি মুহূর্ত কাজে লাগাও।\"\n– সংগৃহীত",
    "\"তুমি যা হতে চাও, তার জন্য আজ থেকেই কাজ শুরু করো।\"\n– সংগৃহীত",
    "\"নিজের প্রতি বিশ্বাস রাখো, তুমি তোমার ধারণার চেয়েও বেশি শক্তিশালী।\"\n– সংগৃহীত",
    "\"আজকের কষ্ট কালকের সাফল্যের সবচেয়ে বড় ভিত্তি।\"\n– সংগৃহীত",
    "\"The secret of getting ahead is getting started.\"\n– Mark Twain",
    "\"Don't watch the clock; do what it does. Keep going.\"\n– Sam Levenson",
    "\"It always seems impossible until it's done.\"\n– Nelson Mandela",
    "\"The future depends on what you do today.\"\n– Mahatma Gandhi",
    "\"Focus on being productive instead of busy.\"\n– Tim Ferriss",
    "\"Success is no accident. It is hard work, perseverance, learning, studying, sacrifice.\"\n– Pelé",
    "\"Believe you can and you're halfway there.\"\n– Theodore Roosevelt",
    "\"Work hard in silence, let your success be your noise.\"\n– Frank Ocean",
    "\"The only place where success comes before work is in the dictionary.\"\n– Vidal Sassoon",
    "\"You don't have to be great to start, but you have to start to be great.\"\n– Zig Ziglar",
  ];

  @override
  void initState() {
    super.initState();
    _selectRandomQuote();
  }

  void _selectRandomQuote() {
    final random = Random();
    final index = random.nextInt(_quotes.length);
    setState(() {
      _randomQuote = _quotes[index];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.indigo[50],
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Focus Mode On',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.indigo,
                ),
              ),
              const SizedBox(height: 60),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.indigo.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Text(
                  _randomQuote,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontStyle: FontStyle.italic,
                    height: 1.5, // Line spacing
                  ),
                ),
              ),
              const SizedBox(height: 80),
              ElevatedButton(
                onPressed: () {
                  Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const DashboardScreen()));
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Continue to Home', style: TextStyle(fontSize: 18, color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================
// 4. Dashboard Screen (ড্যাশবোর্ড স্ক্রিন)
// ==========================================
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final String todayDate = DateFormat('EEEE, d MMMM').format(DateTime.now());

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20.0),
          children: [
            // টপ বার: অ্যাপের নাম, ইউজার ইনফো, মেসেজ আইকন
            _buildTopBar(context, user),
            const SizedBox(height: 20),

            // তারিখ
            Text(
              todayDate,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 20),

            // আজকের প্রোগ্রেসবার
            _buildTodayProgressCard(),
            const SizedBox(height: 30),

            // Other Active Tasks section will go here
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // New Task বাটন লজিক এখানে হবে
        },
        label: const Text('New Task'),
        icon: const Icon(Icons.add),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildTopBar(BuildContext context, User? user) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'StudyMate',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.indigo,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Welcome, ${user?.displayName ?? "User"}!',
              style: const TextStyle(
                fontSize: 18,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        Stack(
          children: [
            IconButton(
              icon: Icon(Icons.message_outlined, color: Colors.grey[700], size: 30),
              onPressed: () {
                // মেসেজ পেইজে যাওয়ার লজিক এখানে হবে
              },
            ),
            Positioned(
              right: 8,
              top: 8,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(10),
                ),
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                child: const Text(
                  '3', // মেসেজের সংখ্যা এখানে দেখাবে
                  style: TextStyle(color: Colors.white, fontSize: 10),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTodayProgressCard() {
    // এখানে রুটিন চেক করার লজিক থাকবে। আপাতত একটি ডেমো ডিজাইন দেওয়া হলো।
    bool hasRoutine = false; // এটি পরে ডাইনামিক হবে

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Today's Progress",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (hasRoutine)
              // প্রোগ্রেসবার এখানে থাকবে
              const Text('Progress bar will be here.')
            else
              Center(
                child: Column(
                  children: [
                    Text(
                      'No routine set for today. Progress is 0%.',
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () {
                        // রুটিন পেইজে যাওয়ার লজিক এখানে হবে
                      },
                      child: const Text('Set Today\'s Routine'),
                    )
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}