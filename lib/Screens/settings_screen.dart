import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../functions/supportive_functions.dart';
import '../provider/notification_provider.dart';
import '../services/notification_service.dart';
import '../services/auth_service.dart';

const cameraIcon =
'''<svg width="20" height="16" viewBox="0 0 20 16" fill="none" xmlns="http://www.w3.org/2000/svg">
<path fill-rule="evenodd" clip-rule="evenodd" d="M10 12.0152C8.49151 12.0152 7.26415 10.8137 7.26415 9.33902C7.26415 7.86342 8.49151 6.6619 10 6.6619C11.5085 6.6619 12.7358 7.86342 12.7358 9.33902C12.7358 10.8137 11.5085 12.0152 10 12.0152ZM10 5.55543C7.86698 5.55543 6.13208 7.25251 6.13208 9.33902C6.13208 11.4246 7.86698 13.1217 10 13.1217C12.133 13.1217 13.8679 11.4246 13.8679 9.33902C13.8679 7.25251 12.133 5.55543 10 5.55543ZM18.8679 13.3967C18.8679 14.2226 18.1811 14.8935 17.3368 14.8935H2.66321C1.81887 14.8935 1.13208 14.2226 1.13208 13.3967V5.42346C1.13208 4.59845 1.81887 3.92664 2.66321 3.92664H4.75C5.42453 3.92664 6.03396 3.50952 6.26604 2.88753L6.81321 1.41746C6.88113 1.23198 7.06415 1.10739 7.26604 1.10739H12.734C12.9358 1.10739 13.1189 1.23198 13.1877 1.41839L13.734 2.88845C13.966 3.50952 14.5755 3.92664 15.25 3.92664H17.3368C18.1811 3.92664 18.8679 4.59845 18.8679 5.42346V13.3967ZM17.3368 2.82016H15.25C15.0491 2.82016 14.867 2.69466 14.7972 2.50917L14.2519 1.04003C14.0217 0.418041 13.4113 0 12.734 0H7.26604C6.58868 0 5.9783 0.418041 5.74906 1.0391L5.20283 2.50825C5.13302 2.69466 4.95094 2.82016 4.75 2.82016H2.66321C1.19434 2.82016 0 3.98846 0 5.42346V13.3967C0 14.8326 1.19434 16 2.66321 16H17.3368C18.8057 16 20 14.8326 20 13.3967V5.42346C20 3.98846 18.8057 2.82016 17.3368 2.82016Z" fill="#757575"/>
</svg>''';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key, this.setRefreshCallback});

  final Function(Function)? setRefreshCallback;

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  Map<String, dynamic>? profile;
  bool isLoading = true;
  String? error;
  File? _selectedImage;
  String defaultProfileImage =
      'https://cdn.pixabay.com/photo/2023/02/18/11/00/icon-7797704_640.png';

  @override
  void initState() {
    super.initState();
    _loadProfile();
    widget.setRefreshCallback?.call(_refreshProfile);
  }

  Future<void> _loadProfile() async {
    setState(() {
      isLoading = true;
      error = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser!;
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (mounted) {
        setState(() {
          profile = userDoc.exists 
              ? userDoc.data() 
              : {
                  'email': user.email,
                  'profile_url': defaultProfileImage,
                };
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = e.toString();
          isLoading = false;
        });
      }
    }
  }

  void _refreshProfile() {
    if (!mounted) return;
    
    // Clear any cached images
    imageCache.clear();
    imageCache.clearLiveImages();
    
    _loadProfile();
  }

  Future<void> _logout() async {
    try {
      final authService = AuthService();
      await authService.logout();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Logout failed: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final pickedImage = await picker.pickImage(source: source);
      if (pickedImage == null) return;

      if (!mounted) return;

      // Set the selected image and save profile
      _selectedImage = File(pickedImage.path);
      await _saveProfile();

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error selecting image: $e'),
          duration: const Duration(seconds: 3),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _saveProfile() async {
    if (_selectedImage == null) return;

    try {
      debugPrint('Starting profile image upload to Cloudinary...');
      
      // Optimistic update - show new image immediately
      final tempImagePath = _selectedImage!.path;
      setState(() {
        profile = {
          ...profile ?? {},
          'profile_url': tempImagePath,
          'isUploading': true,
        };
      });

      // Upload to Cloudinary
      final imageUrl = await uploadToCloudinary(_selectedImage!);
      
      if (imageUrl == null) {
        throw Exception('Failed to upload image to Cloudinary');
      }

      debugPrint('Image uploaded successfully to Cloudinary: $imageUrl');

      // Update Firestore with Cloudinary URL
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .set({
          'profile_url': imageUrl,
          'email': user.email,
          'updated_at': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        debugPrint('Firestore updated successfully');

        // Update local profile
        setState(() {
          profile = {
            ...profile ?? {},
            'profile_url': imageUrl,
            'isUploading': false,
          };
        });

        // Refresh to ensure consistency
        _refreshProfile();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile updated successfully'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        throw Exception('No authenticated user');
      }
    } catch (e) {
      debugPrint('Error saving profile: $e');
      
      // Revert optimistic update
      setState(() {
        profile = {
          ...profile ?? {},
          'profile_url': defaultProfileImage,
          'isUploading': false,
        };
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update profile: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      _selectedImage = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool isDarkMode = ref.watch(bgProvider);

    return Scaffold(
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Error: $error'),
                      ElevatedButton(
                        onPressed: _loadProfile,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Profile Section
                        Center(
                          child: Stack(
                            children: [
                              CircleAvatar(
                                radius: 60,
                                backgroundImage: profile!['profile_url']?.startsWith('/') == true
                                    ? FileImage(
                                        File(profile!['profile_url']),
                                      ) as ImageProvider
                                    : NetworkImage(
                                        '${profile!['profile_url'] ?? defaultProfileImage}?t=${DateTime.now().millisecondsSinceEpoch}',
                                      ),
                                onBackgroundImageError: (_, __) {
                                  // Fallback to default image
                                },
                                child: profile!['profile_url'] == null
                                    ? Icon(
                                        Icons.person,
                                        size: 60,
                                        color: Colors.grey[400],
                                      )
                                    : null,
                              ),
                              // Upload progress indicator
                              if (profile!['isUploading'] == true)
                                Positioned.fill(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.5),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Center(
                                      child: CircularProgressIndicator(
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    ),
                                  ),
                                ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: GestureDetector(
                                  onTap: profile!['isUploading'] == true ? null : () {
                                    showModalBottomSheet(
                                      context: context,
                                      builder: (context) => SafeArea(
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            ListTile(
                                              leading: const Icon(Icons.photo_library),
                                              title: const Text('Choose from Gallery'),
                                              onTap: () {
                                                Navigator.pop(context);
                                                _pickImage(ImageSource.gallery);
                                              },
                                            ),
                                            ListTile(
                                              leading: const Icon(Icons.camera_alt),
                                              title: const Text('Take Photo'),
                                              onTap: () {
                                                Navigator.pop(context);
                                                _pickImage(ImageSource.camera);
                                              },
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: profile!['isUploading'] == true 
                                          ? Colors.grey 
                                          : theme.primaryColor,
                                      shape: BoxShape.circle,
                                    ),
                                    child: SvgPicture.string(
                                      cameraIcon,
                                      width: 20,
                                      height: 16,
                                      colorFilter: ColorFilter.mode(
                                        Colors.white,
                                        BlendMode.srcIn,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        Center(
                          child: Text(
                            profile?['email'] ?? 'No email',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 40),
                        Text(
                          'APPEARANCE',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 12),
                        SwitchListTile(
                          secondary: Icon(
                            isDarkMode ? Icons.dark_mode : Icons.light_mode,
                            size: 28,
                          ),
                          title: const Text(
                            'Dark Mode',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          value: isDarkMode,
                          onChanged: (value) {
                            ref.read(bgProvider.notifier).toggleTheme();
                          },
                        ),
                        const SizedBox(height: 30),
                        Text(
                          'GENERAL',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 12),
                        SwitchListTile(
                          secondary: const Icon(
                            Icons.notifications_none,
                            size: 28,
                          ),
                          title: const Text(
                            'Notifications',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          value: ref.watch(notificationsEnabledProvider),
                          onChanged: (value) async {
                            ref.read(notificationsEnabledProvider.notifier).state = value;
                            final notiService = ref.read(notiServiceProvider);

                            if (value) {
                              await notiService.showNotification(
                                title: "Notifications Enabled",
                                body: "You have enabled local notifications. You'll now receive reminders and updates.",
                              );
                              
                              // TODO: Reschedule all existing reminders
                              print('Notifications enabled - existing reminders will now work');
                            } else {
                              await notiService.showNotification(
                                title: "Notifications Disabled",
                                body: "You have disabled local notifications. You won't receive any reminders or updates.",
                              );
                              
                              // Cancel all scheduled notifications
                              await notiService.cancelAllNotifications();
                              print('Notifications disabled - all scheduled reminders cancelled');
                            }
                          },
                        ),
                        ListTile(
                          leading: Icon(
                            Icons.logout,
                            size: 28,
                            color: Theme.of(context).colorScheme.error,
                          ),
                          title: Text(
                            'Logout',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w500,
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                          trailing: const Icon(
                            Icons.arrow_forward_ios,
                            size: 18,
                          ),
                          onTap: _logout,
                        ),
                        const SizedBox(height: 150),
                        Center(
                          child: Text(
                            'Version 1.0.0',
                            style: TextStyle(
                              fontSize: 16,
                              color: theme.colorScheme.onSurface.withOpacity(0.8),
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }
}