import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../providers/auth_provider.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/shared/widgets/eco_button.dart';
import '../../../../core/shared/widgets/eco_text_field.dart';
import '../../../../core/shared/widgets/image_source_picker_sheet.dart';

class RegisterScreen extends HookConsumerWidget {
  const RegisterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fullNameController = useTextEditingController();
    final emailController = useTextEditingController();
    final phoneController = useTextEditingController();
    final passwordController = useTextEditingController();
    final confirmPasswordController = useTextEditingController();
    final addressController = useTextEditingController();
    final gpsController = useTextEditingController();

    final agreedToTerms = useState(false);
    final profileImagePath = useState<String?>(null);
    final profileImageBytes = useState<Uint8List?>(null);
    final formKey = useMemoized(() => GlobalKey<FormState>());

    // Listen to registration status
    ref.listen<AuthState>(authStateControllerProvider, (previous, next) {
      if (next is AuthAuthenticated) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Registration successful! Welcome to EcoWaste.'),
            backgroundColor: Colors.green,
          ),
        );
        context.go('/customer/home');
      } else if (next is AuthError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.message), backgroundColor: Colors.red),
        );
      }
    });

    final authState = ref.watch(authStateControllerProvider);
    final isLoading = authState.isLoading;

    // Geolocator logic to fetch location
    Future<void> detectLocation() async {
      gpsController.text = 'Fetching current location...';
      final access = await LocationService.instance.ensurePermission();

      if (!context.mounted) return;

      switch (access) {
        case LocationAccess.granted:
          final position = await LocationService.instance.currentPosition();
          if (!context.mounted) return;
          if (position != null) {
            gpsController.text = _formatMapCoordinates(
              position.latitude,
              position.longitude,
            );
          } else {
            gpsController.clear();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Could not get your current location. Try again.'),
                backgroundColor: Colors.red,
              ),
            );
          }
        case LocationAccess.serviceDisabled:
          gpsController.clear();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Turn on location services to use this.'),
              action: SnackBarAction(
                label: 'Open settings',
                onPressed: LocationService.instance.openLocationSettings,
              ),
            ),
          );
        case LocationAccess.deniedForever:
          gpsController.clear();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Location permission is blocked for CleanConnect.'),
              action: SnackBarAction(
                label: 'Open settings',
                onPressed: LocationService.instance.openAppSettings,
              ),
            ),
          );
        case LocationAccess.denied:
          gpsController.clear();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permission was not granted.')),
          );
      }
    }

    // Image Picker logic
    Future<void> pickImage() async {
      final source = await showImageSourcePickerSheet(
        context,
        title: 'Upload House Picture',
      );
      if (source == null) return;

      if (!kIsWeb && source == ImageSource.gallery) {
        final status = await Permission.photos.request();
        if (status.isDenied) {
          // Fallback for newer Android/iOS or custom handling
        }
      }

      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 600,
        maxHeight: 600,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        profileImagePath.value = pickedFile.path;
        profileImageBytes.value = await pickedFile.readAsBytes();
      }
    }

    void handleRegister() {
      if (!agreedToTerms.value) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Please accept the Terms & Conditions and Privacy Policy.',
            ),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      if (formKey.currentState?.validate() ?? false) {
        ref
            .read(authStateControllerProvider.notifier)
            .register(
              fullName: fullNameController.text.trim(),
              email: emailController.text.trim(),
              phoneNumber: phoneController.text.trim(),
              password: passwordController.text,
              address: addressController.text.trim(),
              gpsLocation: gpsController.text,
              housePhotoBytes: profileImageBytes.value,
              housePhotoFileName: profileImagePath.value,
            );
      }
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header navigation
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.arrow_back,
                        color: Color(0xFF1A1A1A),
                      ),
                      onPressed: () => context.pop(),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'EcoWaste',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFFC78200), // Brand Orange text
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Card Wrapper (beige border tint or white card layout)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isDark
                        ? theme.cardTheme.color
                        : const Color(0xFFFFFDF9),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: isDark
                          ? Colors.grey.shade800
                          : const Color(0xFFFFF7EA),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Form(
                    key: formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Center(
                          child: Text(
                            'Create Account',
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF1A1A1A),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Center(
                          child: Text(
                            'Join CleanConnectto manage your sustainability goals.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Fields
                        EcoTextField(
                          labelText: 'Full Name',
                          hintText: 'Jane Doe',
                          controller: fullNameController,
                          prefixIcon: const Icon(
                            Icons.person_outline,
                            size: 20,
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter your full name';
                            }
                            return null;
                          },
                        ),
                        EcoTextField(
                          labelText: 'Email Address',
                          hintText: 'jane.doe@example.com',
                          controller: emailController,
                          keyboardType: TextInputType.emailAddress,
                          prefixIcon: const Icon(
                            Icons.email_outlined,
                            size: 20,
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter your email';
                            }
                            if (!RegExp(
                              r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                            ).hasMatch(value)) {
                              return 'Please enter a valid email address';
                            }
                            return null;
                          },
                        ),
                        EcoTextField(
                          labelText: 'Phone Number',
                          hintText: '024 881 4260',
                          controller: phoneController,
                          keyboardType: TextInputType.phone,
                          prefixIcon: const Icon(
                            Icons.phone_outlined,
                            size: 20,
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter your phone number';
                            }
                            // Valid Ghana phone number format (0XXXXXXXXX or +233XXXXXXXXX)
                            final clean = value.replaceAll(RegExp(r'[\s-]'), '');
                            final ghanaPattern = RegExp(r'^(\+?233|0)[235][0-9]{8}$');
                            if (!ghanaPattern.hasMatch(clean)) {
                              return 'Enter a valid 10-digit Ghana phone number';
                            }
                            return null;
                          },
                        ),
                        EcoTextField(
                          labelText: 'Password',
                          hintText: '••••••••',
                          controller: passwordController,
                          isPassword: true,
                          prefixIcon: const Icon(Icons.lock_outline, size: 20),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please create a password';
                            }
                            if (value.length < 6) {
                              return 'Password must be at least 6 characters';
                            }
                            return null;
                          },
                        ),
                        EcoTextField(
                          labelText: 'Confirm Password',
                          hintText: '••••••••',
                          controller: confirmPasswordController,
                          isPassword: true,
                          prefixIcon: const Icon(Icons.lock_outline, size: 20),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please confirm your password';
                            }
                            if (value != passwordController.text) {
                              return 'Passwords do not match';
                            }
                            return null;
                          },
                        ),
                        EcoTextField(
                          labelText: 'GPS Location',
                          hintText: 'Detecting location...',
                          controller: gpsController,
                          readOnly: true,
                          onTap: detectLocation,
                          prefixIcon: const Icon(
                            Icons.location_on_outlined,
                            size: 20,
                          ),
                          suffixIcon: IconButton(
                            icon: const Icon(
                              Icons.my_location,
                              color: Color(0xFFF0A500),
                            ),
                            onPressed: detectLocation,
                          ),
                          validator: (value) {
                            if (value == null ||
                                value.isEmpty ||
                                value == 'Fetching current location...') {
                              return 'Please capture your GPS coordinates';
                            }
                            return null;
                          },
                        ),
                        EcoTextField(
                          labelText: 'House Address',
                          hintText: '123 Green St, Eco City',
                          controller: addressController,
                          prefixIcon: const Icon(Icons.home_outlined, size: 20),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter your house address';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 8),
                        // Terms & Conditions Checkbox
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 24,
                              height: 24,
                              child: Checkbox(
                                value: agreedToTerms.value,
                                activeColor: const Color(0xFFF0A500),
                                onChanged: (value) =>
                                    agreedToTerms.value = value ?? false,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: GestureDetector(
                                onTap: () =>
                                    agreedToTerms.value = !agreedToTerms.value,
                                child: RichText(
                                  text: TextSpan(
                                    style: TextStyle(
                                      color: Colors.grey.shade700,
                                      fontSize: 13,
                                      height: 1.3,
                                    ),
                                    children: const [
                                      TextSpan(text: 'I agree to the '),
                                      TextSpan(
                                        text: 'Terms and Conditions',
                                        style: TextStyle(
                                          color: Color(0xFFF0A500),
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      TextSpan(text: ' and '),
                                      TextSpan(
                                        text: 'Privacy Policy',
                                        style: TextStyle(
                                          color: Color(0xFFF0A500),
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      TextSpan(text: '.'),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        // Photo Upload Card
                        const Text(
                          'Upload House Picture',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1A1A1A),
                          ),
                        ),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: pickImage,
                          child: Container(
                            width: double.infinity,
                            height: 140,
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.black26
                                  : const Color(0xFFFFF7EA),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(
                                  0xFFF0A500,
                                ).withValues(alpha: 0.4),
                                width: 1.5,
                                style: BorderStyle.solid,
                              ),
                            ),
                            child: profileImagePath.value != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: kIsWeb
                                        ? Image.memory(
                                            profileImageBytes.value!,
                                            fit: BoxFit.cover,
                                          )
                                        : Image.file(
                                            File(profileImagePath.value!),
                                            fit: BoxFit.cover,
                                          ),
                                  )
                                : Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(
                                        Icons.add_a_photo_outlined,
                                        size: 32,
                                        color: Color(0xFFF0A500),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Tap to upload or take a photo',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey.shade600,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                        const SizedBox(height: 32),
                        // Register button
                        EcoButton(
                          text: 'Create Account',
                          onPressed: handleRegister,
                          isLoading: isLoading,
                        ),
                        const SizedBox(height: 24),
                        // Login footer link
                        Center(
                          child: GestureDetector(
                            onTap: () => context.go('/login'),
                            child: RichText(
                              text: TextSpan(
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade700,
                                ),
                                children: const [
                                  TextSpan(text: 'Already have an account? '),
                                  TextSpan(
                                    text: 'Log in',
                                    style: TextStyle(
                                      color: Color(0xFFF0A500),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _formatMapCoordinates(double latitude, double longitude) {
  return '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}';
}
