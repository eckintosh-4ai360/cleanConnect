import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../providers/auth_provider.dart';
import '../../../../core/shared/widgets/eco_button.dart';
import '../../../../core/shared/widgets/eco_text_field.dart';

class RegisterScreen extends HookConsumerWidget {
  const RegisterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fullNameController = useTextEditingController();
    final emailController = useTextEditingController();
    final phoneController = useTextEditingController();
    final passwordController = useTextEditingController();
    final addressController = useTextEditingController();
    final gpsController = useTextEditingController();

    final agreedToTerms = useState(false);
    final profileImagePath = useState<String?>(null);
    final formKey = useMemoized(() => GlobalKey<FormState>());

    // Listen to registration status
    ref.listen(authStateControllerProvider, (previous, next) {
      next.when(
        data: (user) {
          if (user != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Registration successful! Directing to verification...'),
                backgroundColor: Colors.green,
              ),
            );
            // Navigate to OTP page, passing the phone number as parameter
            context.go('/otp?phone=${Uri.encodeComponent(phoneController.text)}');
          }
        },
        error: (err, _) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(err.toString().replaceAll('Exception: ', '')),
              backgroundColor: Colors.red,
            ),
          );
        },
        loading: () {},
      );
    });

    final authState = ref.watch(authStateControllerProvider);
    final isLoading = authState.isLoading;

    // Geolocator logic to fetch location
    Future<void> detectLocation() async {
      try {
        final permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          final requested = await Geolocator.requestPermission();
          if (requested == LocationPermission.denied || requested == LocationPermission.deniedForever) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Location permission is denied.')),
            );
            return;
          }
        }

        gpsController.text = 'Fetching current location...';
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 8),
        );
        gpsController.text = '${position.latitude.toStringAsFixed(4)}° N, ${position.longitude.toStringAsFixed(4)}° W';
      } catch (e) {
        gpsController.text = '5.6037° N, 0.1870° W (Fallback)';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not fetch GPS location: $e')),
        );
      }
    }

    // Image Picker logic
    Future<void> pickImage() async {
      final status = await Permission.photos.request();
      if (status.isDenied) {
        // Fallback for newer Android/iOS or custom handling
      }

      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 600,
        maxHeight: 600,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        profileImagePath.value = pickedFile.path;
      }
    }

    void handleRegister() {
      if (!agreedToTerms.value) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please accept the Terms & Conditions and Privacy Policy.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      if (formKey.currentState?.validate() ?? false) {
        ref.read(authStateControllerProvider.notifier).register(
              fullName: fullNameController.text.trim(),
              email: emailController.text.trim(),
              phoneNumber: phoneController.text.trim(),
              password: passwordController.text,
              address: addressController.text.trim(),
              gpsLocation: gpsController.text.isEmpty ? '5.6037° N, 0.1870° W' : gpsController.text,
              profilePicturePath: profileImagePath.value,
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
                      icon: const Icon(Icons.arrow_back, color: Color(0xFF1A1A1A)),
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
                    color: isDark ? theme.cardTheme.color : const Color(0xFFFFFDF9),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: isDark ? Colors.grey.shade800 : const Color(0xFFFFF7EA),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.02),
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
                            'Join EcoWaste to manage your sustainability goals.',
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
                          prefixIcon: const Icon(Icons.person_outline, size: 20),
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
                          prefixIcon: const Icon(Icons.email_outlined, size: 20),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter your email';
                            }
                            if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                              return 'Please enter a valid email address';
                            }
                            return null;
                          },
                        ),
                        EcoTextField(
                          labelText: 'Phone Number',
                          hintText: '+1 (555) 000-0000',
                          controller: phoneController,
                          keyboardType: TextInputType.phone,
                          prefixIcon: const Icon(Icons.phone_outlined, size: 20),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter your phone number';
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
                          labelText: 'GPS Location',
                          hintText: 'Detecting location...',
                          controller: gpsController,
                          readOnly: true,
                          onTap: detectLocation,
                          prefixIcon: const Icon(Icons.location_on_outlined, size: 20),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.my_location, color: Color(0xFFF0A500)),
                            onPressed: detectLocation,
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
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
                                onChanged: (value) => agreedToTerms.value = value ?? false,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => agreedToTerms.value = !agreedToTerms.value,
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
                              color: isDark ? Colors.black26 : const Color(0xFFFFF7EA),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFFF0A500).withOpacity(0.4),
                                width: 1.5,
                                style: BorderStyle.solid,
                              ),
                            ),
                            child: profileImagePath.value != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: Image.file(
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
