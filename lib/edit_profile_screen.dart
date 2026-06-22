import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'language_manager.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  bool _isLoading = false;
  bool _isSaving = false;
  bool _isUploadingImage = false;

  // Image upload properties
  String? _photoUrl;
  File? _localImageFile;

  // Controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  final TextEditingController _institutionController = TextEditingController();
  final TextEditingController _majorController = TextEditingController();
  final TextEditingController _goalController = TextEditingController();

  String _academicYear = "School / College";
  final List<String> _academicYears = [
    "School / College",
    "University 1st Year",
    "University 2nd Year",
    "University 3rd Year",
    "University 4th Year",
    "Post-graduate",
    "Other"
  ];

  @override
  void initState() {
    super.initState();
    _photoUrl = _currentUser?.photoURL;
    _loadProfileData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _institutionController.dispose();
    _majorController.dispose();
    _goalController.dispose();
    super.dispose();
  }

  Future<void> _loadProfileData() async {
    if (_currentUser == null) return;
    setState(() => _isLoading = true);

    _nameController.text = _currentUser.displayName ?? "";

    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(_currentUser.uid).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        if (mounted) {
          setState(() {
            _bioController.text = data['bio'] as String? ?? "";
            _institutionController.text = data['institution'] as String? ?? "";
            _majorController.text = data['major'] as String? ?? "";
            _goalController.text = (data['dailyStudyGoalHours'] ?? 2).toString();
            if (data['photoUrl'] != null) {
              _photoUrl = data['photoUrl'] as String;
            }
            
            final year = data['academicYear'] as String?;
            if (year != null && _academicYears.contains(year)) {
              _academicYear = year;
            }
          });
        }
      }
    } catch (e) {
      debugPrint("Error loading profile: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Camera & Gallery Image Picker Dialogue
  Future<void> _selectImageSource() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF162D24),
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library_rounded, color: Colors.white70),
                title: Text('গ্যালারি থেকে বেছে নিন'.tr(), style: const TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_rounded, color: Colors.white70),
                title: Text('ক্যামেরা দিয়ে ছবি তুলুন'.tr(), style: const TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.camera);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    try {
      final XFile? picked = await picker.pickImage(source: source, imageQuality: 70);
      if (picked != null) {
        setState(() {
          _localImageFile = File(picked.path);
        });
        _saveImageLocally();
      }
    } catch (e) {
      debugPrint("Error picking image: $e");
    }
  }

  Future<void> _saveImageLocally() async {
    if (_localImageFile == null || _currentUser == null) return;
    setState(() => _isUploadingImage = true);

    try {
      final directory = await getApplicationDocumentsDirectory();
      final localPath = '${directory.path}/profile_${_currentUser.uid}.jpg';
      
      // Copy selected file to app documents directory
      final savedFile = await _localImageFile!.copy(localPath);

      // Update Local photoURL
      setState(() {
        _photoUrl = savedFile.path;
      });

      // Update Auth instance instantly
      await _currentUser.updatePhotoURL(savedFile.path);

      // Save to Firestore directly so that it persists instantly
      await FirebaseFirestore.instance.collection('users').doc(_currentUser.uid).set({
        'photoUrl': savedFile.path,
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Profile picture updated locally!'.tr()), backgroundColor: Colors.teal),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${'Error saving profile picture locally: '.tr()}$e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploadingImage = false);
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate() || _currentUser == null) return;

    setState(() => _isSaving = true);
    try {
      // 1. Update Firebase Auth displayName & photoUrl
      await _currentUser.updateDisplayName(_nameController.text.trim());
      if (_photoUrl != null) {
        await _currentUser.updatePhotoURL(_photoUrl);
      }

      // 2. Update Firestore document
      final double dailyGoal = double.tryParse(_goalController.text) ?? 2.0;
      await FirebaseFirestore.instance.collection('users').doc(_currentUser.uid).set({
        'name': _nameController.text.trim(),
        'bio': _bioController.text.trim(),
        'institution': _institutionController.text.trim(),
        'major': _majorController.text.trim(),
        'academicYear': _academicYear,
        'dailyStudyGoalHours': dailyGoal,
        'photoUrl': _photoUrl,
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Profile updated successfully!'.tr()), backgroundColor: Colors.teal),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${'Error updating profile: '.tr()}$e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryGreen = Color(0xFF0F3625);
    const accentGreen = Color(0xFF1D5C42);

    ImageProvider? avatarImage;
    if (_localImageFile != null) {
      avatarImage = FileImage(_localImageFile!);
    } else if (_photoUrl != null && _photoUrl!.isNotEmpty) {
      avatarImage = _photoUrl!.startsWith('http')
          ? NetworkImage(_photoUrl!)
          : FileImage(File(_photoUrl!)) as ImageProvider;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Edit Profile'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [primaryGreen, accentGreen],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: accentGreen))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header Avatar Placeholder
                    Center(
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 48,
                            backgroundColor: accentGreen.withValues(alpha: 0.15),
                            backgroundImage: avatarImage,
                            child: _isUploadingImage
                                ? const CircularProgressIndicator(color: Colors.white)
                                : avatarImage == null
                                    ? Text(
                                        _nameController.text.isNotEmpty
                                            ? _nameController.text.substring(0, 1).toUpperCase()
                                            : "U",
                                        style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: accentGreen),
                                      )
                                    : null,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: CircleAvatar(
                              radius: 16,
                              backgroundColor: accentGreen,
                              child: IconButton(
                                icon: const Icon(Icons.camera_alt_rounded, size: 14, color: Colors.white),
                                onPressed: _isUploadingImage ? null : _selectImageSource,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Full name
                    TextFormField(
                      controller: _nameController,
                      validator: (v) => (v == null || v.isEmpty) ? "Name cannot be empty".tr() : null,
                      decoration: InputDecoration(
                        labelText: 'Display Name'.tr(),
                        prefixIcon: const Icon(Icons.person_outline_rounded),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Bio
                    TextFormField(
                      controller: _bioController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: 'Short Bio / Goal'.tr(),
                        prefixIcon: const Icon(Icons.description_outlined),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Institution Name
                    TextFormField(
                      controller: _institutionController,
                      decoration: InputDecoration(
                        labelText: 'School / College / University'.tr(),
                        prefixIcon: const Icon(Icons.school_outlined),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Major / Subject
                    TextFormField(
                      controller: _majorController,
                      decoration: InputDecoration(
                        labelText: 'Major / Subject'.tr(),
                        prefixIcon: const Icon(Icons.book_outlined),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Academic Year Dropdown
                    DropdownButtonFormField<String>(
                      value: _academicYear,
                      items: _academicYears.map((String y) {
                        return DropdownMenuItem<String>(
                          value: y,
                          child: Text(y.tr()),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _academicYear = val);
                        }
                      },
                      decoration: InputDecoration(
                        labelText: 'Class / Year'.tr(),
                        prefixIcon: const Icon(Icons.layers_outlined),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Daily Study Goal Hours
                    TextFormField(
                      controller: _goalController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (v) {
                        if (v == null || v.isEmpty) return "Enter target hours".tr();
                        final val = double.tryParse(v);
                        if (val == null || val <= 0 || val > 24) return "Enter valid hours (1-24)".tr();
                        return null;
                      },
                      decoration: InputDecoration(
                        labelText: 'Daily Study Goal (Hours)'.tr(),
                        prefixIcon: const Icon(Icons.timer_outlined),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 36),

                    // Save Button
                    ElevatedButton(
                      onPressed: _isSaving ? null : _saveProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentGreen,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isSaving
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text('Save Profile Details'.tr(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
