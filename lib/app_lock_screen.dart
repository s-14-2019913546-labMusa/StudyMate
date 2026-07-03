import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'app_lock_service.dart';
import 'language_manager.dart';
import 'login_screen.dart';

enum AppLockMode { setup, confirm, unlock, disable }

class AppLockScreen extends StatefulWidget {
  final AppLockMode mode;
  final String? setupPin; // Used in confirm mode
  final VoidCallback? onSuccess;

  const AppLockScreen({
    super.key,
    required this.mode,
    this.setupPin,
    this.onSuccess,
  });

  @override
  State<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends State<AppLockScreen> with SingleTickerProviderStateMixin {
  String _enteredPin = '';
  late AppLockMode _currentMode;
  String? _firstPin; // Stored first PIN during setup
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;
  bool _hasError = false;
  bool _isBiometricsSupported = false;

  @override
  void initState() {
    super.initState();
    _currentMode = widget.mode;
    _firstPin = widget.setupPin;
    
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _shakeAnimation = Tween<double>(begin: 0.0, end: 10.0)
        .chain(CurveTween(curve: Curves.elasticIn))
        .animate(_shakeController);

    _checkBiometricsSupport();
    
    // Automatically trigger biometrics if we are unlocking
    if (_currentMode == AppLockMode.unlock) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _triggerBiometricAuth();
      });
    }
  }

  Future<void> _checkBiometricsSupport() async {
    final supported = await AppLockService().isBiometricsSupported();
    if (mounted) {
      setState(() {
        _isBiometricsSupported = supported;
      });
    }
  }

  Future<void> _triggerBiometricAuth() async {
    if (_isBiometricsSupported && AppLockService().isBiometricEnabled()) {
      final success = await AppLockService().authenticateWithBiometrics();
      if (success && mounted) {
        _handleSuccess();
      }
    }
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  void _handleNumberPress(String number) {
    if (_enteredPin.length >= 4) return;

    setState(() {
      _enteredPin += number;
      _hasError = false;
    });

    if (_enteredPin.length == 4) {
      // Small delay for user to see the 4th dot filled
      Future.delayed(const Duration(milliseconds: 150), () {
        _processPin();
      });
    }
  }

  void _handleDelete() {
    if (_enteredPin.isEmpty) return;
    setState(() {
      _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
      _hasError = false;
    });
  }

  void _processPin() {
    final service = AppLockService();
    switch (_currentMode) {
      case AppLockMode.setup:
        setState(() {
          _firstPin = _enteredPin;
          _enteredPin = '';
          _currentMode = AppLockMode.confirm;
        });
        break;

      case AppLockMode.confirm:
        if (_firstPin == _enteredPin) {
          // Setup success
          _showBiometricOptionDialog();
        } else {
          _triggerShakeError();
        }
        break;

      case AppLockMode.unlock:
        if (service.verifyPin(_enteredPin)) {
          _handleSuccess();
        } else {
          _triggerShakeError();
        }
        break;

      case AppLockMode.disable:
        if (service.verifyPin(_enteredPin)) {
          service.disableAppLock().then((_) {
            _handleSuccess();
          });
        } else {
          _triggerShakeError();
        }
        break;
    }
  }

  void _showBiometricOptionDialog() {
    if (_isBiometricsSupported) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF162D24),
          title: Text(
            'Biometric Unlock'.tr(),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: Text(
            'Do you want to enable Fingerprint/Face Unlock?'.tr(),
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _saveSetupAndFinish(false);
              },
              child: Text('No'.tr(), style: const TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _saveSetupAndFinish(true);
              },
              child: Text('Yes'.tr(), style: const TextStyle(color: Color(0xFFE5B842))),
            ),
          ],
        ),
      );
    } else {
      _saveSetupAndFinish(false);
    }
  }

  void _saveSetupAndFinish(bool useBiometrics) {
    AppLockService().enableAppLock(_firstPin!, useBiometrics).then((_) {
      _handleSuccess();
    });
  }

  void _triggerShakeError() {
    HapticFeedback.vibrate();
    setState(() {
      _hasError = true;
      _enteredPin = '';
    });
    _shakeController.forward(from: 0.0);
  }

  void _handleSuccess() {
    if (widget.onSuccess != null) {
      widget.onSuccess!();
    } else {
      Navigator.pop(context, true);
    }
  }

  String _getInstructionText() {
    switch (_currentMode) {
      case AppLockMode.setup:
        return 'Set a 4-Digit Security PIN'.tr();
      case AppLockMode.confirm:
        return 'Confirm your 4-Digit PIN'.tr();
      case AppLockMode.unlock:
        return 'Enter PIN to Unlock'.tr();
      case AppLockMode.disable:
        return 'Enter PIN to Disable Lock'.tr();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    // Premium dark-green theme colors for lock screen
    const primaryBg = Color(0xFF0F1E19);
    const goldAccent = Color(0xFFE5B842);
    const textLight = Colors.white;

    return Scaffold(
      backgroundColor: primaryBg,
      body: SafeArea(
        child: Column(
          children: [
            // Header / Close button (only show close button if not in force unlock mode)
            if (_currentMode != AppLockMode.unlock)
              Align(
                alignment: Alignment.topLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 16.0, top: 16.0),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back_rounded, color: textLight),
                    onPressed: () => Navigator.pop(context, false),
                  ),
                ),
              )
            else
              const SizedBox(height: 50),

            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // App Icon / Logo
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: goldAccent.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.lock_outline_rounded,
                      size: 48,
                      color: goldAccent,
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Instruction
                  Text(
                    _getInstructionText(),
                    style: const TextStyle(
                      color: textLight,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  if (_currentMode == AppLockMode.confirm && _hasError)
                    Text(
                      'PINs do not match. Try again.'.tr(),
                      style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                    )
                  else if (_hasError)
                    Text(
                      'Incorrect PIN'.tr(),
                      style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                    ),
                  
                  const SizedBox(height: 32),

                  // PIN indicator dots
                  AnimatedBuilder(
                    animation: _shakeAnimation,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(
                          _shakeController.isAnimating 
                              ? (2.0 * (_shakeController.value < 0.5 ? 1 : -1) * (1.0 - _shakeController.value) * 15.0) 
                              : 0.0,
                          0.0,
                        ),
                        child: child,
                      );
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(4, (index) {
                        final isFilled = index < _enteredPin.length;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          margin: const EdgeInsets.symmetric(horizontal: 12),
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isFilled 
                                ? goldAccent 
                                : (_hasError ? Colors.redAccent.withValues(alpha: 0.3) : Colors.white24),
                            border: Border.all(
                              color: isFilled 
                                  ? goldAccent 
                                  : (_hasError ? Colors.redAccent : Colors.white38),
                              width: 1.5,
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ],
              ),
            ),

            // Number Keyboard Pad
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 24.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: ['1', '2', '3'].map((n) => _buildKeyboardButton(n)).toList(),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: ['4', '5', '6'].map((n) => _buildKeyboardButton(n)).toList(),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: ['7', '8', '9'].map((n) => _buildKeyboardButton(n)).toList(),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Biometric or empty button
                      _currentMode == AppLockMode.unlock && _isBiometricsSupported && AppLockService().isBiometricEnabled()
                          ? _buildBiometricButton()
                          : const SizedBox(width: 70, height: 70),
                      _buildKeyboardButton('0'),
                      _buildDeleteButton(),
                    ],
                  ),
                  if (_currentMode == AppLockMode.unlock) ...[
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: _showForgotPinDialog,
                      child: Text(
                        'Forgot PIN?'.tr(),
                        style: const TextStyle(
                          color: Color(0xFFE5B842),
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showForgotPinDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF162D24),
        title: Text(
          'Forgot PIN?'.tr(),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'If you forget your PIN, you must log out and log back in to reset it. Do you want to log out now?'.tr(),
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'.tr(), style: const TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context); // Close dialog
              
              // Disable App Lock
              await AppLockService().disableAppLock();
              
              // Sign out from Firebase
              await FirebaseAuth.instance.signOut();
              
              // Navigate to Login Screen
              if (mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
            child: Text('Log Out'.tr(), style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildKeyboardButton(String label) {
    return SizedBox(
      width: 70,
      height: 70,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Colors.white10),
          shape: const CircleBorder(),
          backgroundColor: Colors.white.withValues(alpha: 0.03),
          foregroundColor: Colors.white,
        ),
        onPressed: () => _handleNumberPress(label),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildBiometricButton() {
    return SizedBox(
      width: 70,
      height: 70,
      child: IconButton(
        icon: const Icon(
          Icons.fingerprint_rounded,
          color: Color(0xFFE5B842),
          size: 36,
        ),
        onPressed: _triggerBiometricAuth,
      ),
    );
  }

  Widget _buildDeleteButton() {
    return SizedBox(
      width: 70,
      height: 70,
      child: IconButton(
        icon: const Icon(
          Icons.backspace_outlined,
          color: Colors.white70,
          size: 24,
        ),
        onPressed: _handleDelete,
      ),
    );
  }
}
