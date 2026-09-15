import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../../core/config/map_config.dart';
import '../../../../core/services/profile_image_picker_service.dart';
import '../../../../core/shared/widgets/house_photo_thumbnail.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/customer_providers.dart';
import '../../domain/entities/customer_entities.dart';
import 'location_picker_screen.dart';
import '../widgets/customer_nav_bar.dart';
import '../../../../core/shared/widgets/clean_connect_button.dart';
import '../../../../core/shared/widgets/clean_connect_text_field.dart';

class ProfileSettingsScreen extends HookConsumerWidget {
  const ProfileSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Current active expanded section ('none', 'info', 'address', 'payment', 'notifications')
    final activeSection = useState('none');

    // Personal Info state — pre-filled from registration data
    final authState = ref.watch(authStateControllerProvider);
    final user = authState is AuthAuthenticated ? authState.user : null;
    final nameController = useTextEditingController(text: user?.fullName ?? '');
    final emailController = useTextEditingController(
      text: user?.email ?? '',
    );
    final phoneController = useTextEditingController(text: user?.phoneNumber ?? '');
    final dobController = useTextEditingController(text: '');

    // Address Management state -- saved in customer_addresses, each with the
    // map coordinates riders navigate to.
    final addressesState = ref.watch(customerAddressesProvider);
    final newAddressLabelController = useTextEditingController();
    final newAddressDetailsController = useTextEditingController();
    final newAddressPosition = useState<LatLng?>(null);
    final isSavingAddress = useState(false);

    // Payment Methods state — starts empty (no hardcoded cards)
    final cardMethods = useState<List<Map<String, String>>>([]);

    // Notifications state
    final pickupReminders = useState(true);
    final serviceUpdates = useState(true);
    final paymentConfirmations = useState(true);
    final marketingOffers = useState(false);
    final emailNotifications = useState(true);
    final smsNotifications = useState(false);

    final theme = Theme.of(context);

    // authState and user are declared above (Personal Info state section)
    final currentUser = Supabase.instance.client.auth.currentUser;
    // The profiles row, not auth metadata — a picture in user_metadata rides on
    // every access token and blows the gateway's header limit.
    final currentPhotoUrlFromAuth = user?.profilePictureUrl;
    final photoUrlState = useState<String?>(currentPhotoUrlFromAuth);
    final isUploading = useState(false);

    final subState = ref.watch(customerSubscriptionProvider);
    final housePhotoUrl = subState.value?.housePhotoUrl;
    final isUploadingHousePhoto = useState(false);

    final displayName =
        user?.fullName ?? currentUser?.userMetadata?['full_name'] as String? ?? 'Mark Aggrey';
    final displayEmail = user?.email ?? currentUser?.email ?? 'mark.aggrey@cleanconnect.com';
    final currentPhotoUrl = photoUrlState.value ?? currentPhotoUrlFromAuth;

    Future<void> pickNewAddressOnMap() async {
      final addresses = addressesState.value ?? const <CustomerAddressEntity>[];
      final anchor = addresses.where((a) => a.hasCoordinates).firstOrNull;
      final result = await Navigator.of(context).push<PickedLocation>(
        MaterialPageRoute(
          builder: (_) => LocationPickerScreen(
            initialPosition: newAddressPosition.value ??
                (anchor != null
                    ? LatLng(anchor.latitude!, anchor.longitude!)
                    : MapConfig.fallbackCenter),
          ),
        ),
      );
      if (result == null) return;
      newAddressPosition.value = result.position;
      if (newAddressDetailsController.text.trim().isEmpty &&
          (result.label?.trim().isNotEmpty ?? false)) {
        newAddressDetailsController.text = result.label!.trim();
      }
    }

    Future<void> saveNewAddress() async {
      final label = newAddressLabelController.text.trim();
      final details = newAddressDetailsController.text.trim();
      final position = newAddressPosition.value;

      String? problem;
      if (label.isEmpty) {
        problem = 'Give the address a label, e.g. Home or Work.';
      } else if (position == null) {
        problem = 'Pick the address on the map so riders can find it.';
      } else if (details.isEmpty) {
        problem = 'Add the address details.';
      }
      if (problem != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(problem), backgroundColor: Colors.orange),
        );
        return;
      }

      isSavingAddress.value = true;
      try {
        await ref.read(customerAddressesProvider.notifier).add(
              label: label,
              address: details,
              latitude: position!.latitude,
              longitude: position.longitude,
            );
        newAddressLabelController.clear();
        newAddressDetailsController.clear();
        newAddressPosition.value = null;
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Address saved.'), backgroundColor: Colors.green),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not save address: $e'), backgroundColor: Colors.red),
          );
        }
      } finally {
        isSavingAddress.value = false;
      }
    }

    Future<void> runAddressAction(Future<void> Function() action, String failure) async {
      try {
        await action();
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$failure: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }

    void handleLogout() async {
      await ref.read(authStateControllerProvider.notifier).logout();
      if (context.mounted) {
        context.go('/login');
      }
    }

    Future<void> showImagePickerModal() async {
      showModalBottomSheet(
        context: context,
        useSafeArea: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (ctx) => SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Update Profile Photo',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(Icons.photo_camera, color: Color(0xFFF0A500)),
                  title: const Text('Take a Photo'),
                  onTap: () async {
                    Navigator.pop(ctx);
                    isUploading.value = true;
                    try {
                      final newUrl = await ProfileImagePickerService.pickAndUploadProfileImage(
                        source: ImageSource.camera,
                      );
                      if (newUrl != null) {
                        photoUrlState.value = newUrl;
                        ref.invalidate(authStateControllerProvider);
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Upload failed: $e'), backgroundColor: Colors.red),
                        );
                      }
                    } finally {
                      isUploading.value = false;
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library, color: Color(0xFFF0A500)),
                  title: const Text('Choose from Gallery'),
                  onTap: () async {
                    Navigator.pop(ctx);
                    isUploading.value = true;
                    try {
                      final newUrl = await ProfileImagePickerService.pickAndUploadProfileImage(
                        source: ImageSource.gallery,
                      );
                      if (newUrl != null) {
                        photoUrlState.value = newUrl;
                        ref.invalidate(authStateControllerProvider);
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Upload failed: $e'), backgroundColor: Colors.red),
                        );
                      }
                    } finally {
                      isUploading.value = false;
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      );
    }

    Future<void> pickAndUploadHousePhoto(ImageSource source) async {
      final pickedFile = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (pickedFile == null) return;

      isUploadingHousePhoto.value = true;
      try {
        final bytes = await pickedFile.readAsBytes();
        await ref.read(customerSubscriptionProvider.notifier).updateHousePhoto(
              bytes: bytes,
              fileName: pickedFile.name,
            );
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('House photo updated!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Upload failed: $e'), backgroundColor: Colors.red),
          );
        }
      } finally {
        isUploadingHousePhoto.value = false;
      }
    }

    void showHousePhotoPickerModal() {
      showModalBottomSheet(
        context: context,
        useSafeArea: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (ctx) => SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  housePhotoUrl == null || housePhotoUrl.isEmpty
                      ? 'Add House Photo'
                      : 'Update House Photo',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(Icons.photo_camera, color: Color(0xFFF0A500)),
                  title: const Text('Take a Photo'),
                  onTap: () {
                    Navigator.pop(ctx);
                    pickAndUploadHousePhoto(ImageSource.camera);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library, color: Color(0xFFF0A500)),
                  title: const Text('Choose from Gallery'),
                  onTap: () {
                    Navigator.pop(ctx);
                    pickAndUploadHousePhoto(ImageSource.gallery);
                  },
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      extendBody: true,
      bottomNavigationBar: const CustomerBottomNavBar(currentIndex: 3),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(left: 24.0, right: 24.0, top: 24.0, bottom: 100.0),
          child: Column(
            children: [
              // Avatar details with interactive camera picker
              GestureDetector(
                onTap: showImagePickerModal,
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    CircleAvatar(
                      radius: 48,
                      backgroundColor: theme.colorScheme.primaryContainer,
                      backgroundImage: currentPhotoUrl != null && currentPhotoUrl.isNotEmpty
                          ? (currentPhotoUrl.startsWith('data:image')
                              ? MemoryImage(base64Decode(currentPhotoUrl.split(',').last)) as ImageProvider
                              : NetworkImage(currentPhotoUrl))
                          : null,
                      child: currentPhotoUrl == null || currentPhotoUrl.isEmpty
                          ? Text(
                              displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U',
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                              ),
                            )
                          : null,
                    ),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Color(0xFFF0A500),
                        shape: BoxShape.circle,
                      ),
                      child: isUploading.value
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                displayName,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                displayEmail,
                style: const TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 32),

              // Settings Option menus
              _SettingsTile(
                title: 'Personal Information',
                icon: Icons.person_outline,
                isExpanded: activeSection.value == 'info',
                onTap: () => activeSection.value = activeSection.value == 'info'
                    ? 'none'
                    : 'info',
                expandedContent: Column(
                  children: [
                    const SizedBox(height: 16),
                    CleanConnectTextField(
                      labelText: 'Full Name',
                      hintText: 'Mark Aggrey',
                      controller: nameController,
                    ),
                    CleanConnectTextField(
                      labelText: 'Email Address',
                      hintText: 'mark.aggrey@cleanconnect.com',
                      controller: emailController,
                    ),
                    CleanConnectTextField(
                      labelText: 'Phone Number',
                      hintText: '+1 (555) 019-2834',
                      controller: phoneController,
                    ),
                    CleanConnectTextField(
                      labelText: 'Date of Birth',
                      hintText: 'MM/DD/YYYY',
                      controller: dobController,
                    ),
                    const SizedBox(height: 8),
                    CleanConnectButton(
                      text: 'Save Changes',
                      onPressed: () {
                        activeSection.value = 'none';
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Changes saved successfully!'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),

              _SettingsTile(
                title: 'Address Management',
                icon: Icons.location_on_outlined,
                isExpanded: activeSection.value == 'address',
                onTap: () => activeSection.value =
                    activeSection.value == 'address' ? 'none' : 'address',
                expandedContent: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    ...addressesState.when(
                      loading: () => const [
                        Padding(
                          padding: EdgeInsets.all(12),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                      ],
                      error: (e, _) => [
                        Text(
                          'Could not load your addresses.',
                          style: TextStyle(fontSize: 12, color: Colors.red.shade700),
                        ),
                      ],
                      data: (addresses) => addresses.isEmpty
                          ? [
                              Text(
                                'No saved addresses yet. Add one below to reuse it when requesting a pickup.',
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                              ),
                            ]
                          : addresses.map(
                              (addr) => Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  leading: Icon(
                                    _addressIcon(addr.label),
                                    color: theme.colorScheme.primary,
                                  ),
                                  title: Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          addr.label,
                                          style: const TextStyle(fontWeight: FontWeight.bold),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (addr.isDefault) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.green.shade50,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: const Text(
                                            'DEFAULT',
                                            style: TextStyle(
                                              color: Colors.green,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  subtitle: Text(
                                    addr.hasCoordinates
                                        ? addr.address
                                        : '${addr.address}\nNo map pin — add it again to use it for pickups',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  trailing: PopupMenuButton<String>(
                                    icon: const Icon(Icons.more_vert),
                                    onSelected: (action) {
                                      final notifier = ref.read(customerAddressesProvider.notifier);
                                      if (action == 'default') {
                                        runAddressAction(
                                          () => notifier.setDefault(addr.id),
                                          'Could not set default address',
                                        );
                                      } else if (action == 'delete') {
                                        runAddressAction(
                                          () => notifier.delete(addr.id),
                                          'Could not delete address',
                                        );
                                      }
                                    },
                                    itemBuilder: (_) => [
                                      if (!addr.isDefault)
                                        const PopupMenuItem(
                                          value: 'default',
                                          child: Text('Set as default'),
                                        ),
                                      const PopupMenuItem(
                                        value: 'delete',
                                        child: Text('Delete', style: TextStyle(color: Colors.red)),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Add New Address',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: newAddressLabelController,
                      decoration: const InputDecoration(
                        labelText: 'Label (e.g. Home, Work)',
                        contentPadding: EdgeInsets.all(12),
                      ),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: pickNewAddressOnMap,
                      icon: Icon(
                        newAddressPosition.value == null ? Icons.map_outlined : Icons.check_circle,
                        size: 18,
                        color: newAddressPosition.value == null ? null : Colors.green,
                      ),
                      label: Text(
                        newAddressPosition.value == null
                            ? 'Pick Location on Map'
                            : 'Pinned ${newAddressPosition.value!.latitude.toStringAsFixed(5)}, '
                                '${newAddressPosition.value!.longitude.toStringAsFixed(5)}',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: newAddressDetailsController,
                      minLines: 1,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Address details (street, landmark)',
                        contentPadding: EdgeInsets.all(12),
                      ),
                    ),
                    const SizedBox(height: 12),
                    CleanConnectButton(
                      text: 'Add Address',
                      isLoading: isSavingAddress.value,
                      onPressed: saveNewAddress,
                    ),
                  ],
                ),
              ),

              _SettingsTile(
                title: 'House Photo',
                icon: Icons.home_outlined,
                isExpanded: activeSection.value == 'house_photo',
                onTap: () => activeSection.value =
                    activeSection.value == 'house_photo' ? 'none' : 'house_photo',
                expandedContent: Column(
                  children: [
                    const SizedBox(height: 12),
                    Text(
                      'Riders use this photo to confirm your exact house or building, since a map pin alone can be off by a few metres.',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: housePhotoUrl != null && housePhotoUrl.isNotEmpty
                          ? HousePhotoThumbnail(photoUrl: housePhotoUrl, size: 120)
                          : Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(
                                Icons.home_outlined,
                                size: 36,
                                color: Colors.grey.shade400,
                              ),
                            ),
                    ),
                    const SizedBox(height: 16),
                    CleanConnectButton(
                      text: housePhotoUrl == null || housePhotoUrl.isEmpty
                          ? 'Add House Photo'
                          : 'Update House Photo',
                      isLoading: isUploadingHousePhoto.value,
                      onPressed: showHousePhotoPickerModal,
                    ),
                  ],
                ),
              ),

              _SettingsTile(
                title: 'Payment Methods',
                icon: Icons.credit_card_outlined,
                isExpanded: activeSection.value == 'payment',
                onTap: () => activeSection.value =
                    activeSection.value == 'payment' ? 'none' : 'payment',
                expandedContent: Column(
                  children: [
                    const SizedBox(height: 16),
                    ...cardMethods.value.map(
                      (card) => Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: Icon(
                            card['type'] == 'Visa'
                                ? Icons.credit_card
                                : Icons.credit_card,
                            color: card['type'] == 'Visa'
                                ? Colors.blue
                                : Colors.orange,
                          ),
                          title: Text(
                            '${card['type']} (Ending ${card['last4']})',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            'Expires ${card['expiry']}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          trailing: card['last4'] == '4240'
                              ? Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    'DEFAULT',
                                    style: TextStyle(
                                      color: Colors.green,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                )
                              : null,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    CleanConnectButton(
                      text: 'Add Payment Method',
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Card verification processing...'),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),

              _SettingsTile(
                title: 'Notification Settings',
                icon: Icons.notifications_none_outlined,
                isExpanded: activeSection.value == 'notifications',
                onTap: () =>
                    activeSection.value = activeSection.value == 'notifications'
                    ? 'none'
                    : 'notifications',
                expandedContent: Column(
                  children: [
                    _SwitchRow(
                      label: 'Pickup Reminders',
                      val: pickupReminders.value,
                      onChanged: (v) => pickupReminders.value = v,
                    ),
                    _SwitchRow(
                      label: 'Service Updates',
                      val: serviceUpdates.value,
                      onChanged: (v) => serviceUpdates.value = v,
                    ),
                    _SwitchRow(
                      label: 'Payment Confirmations',
                      val: paymentConfirmations.value,
                      onChanged: (v) => paymentConfirmations.value = v,
                    ),
                    _SwitchRow(
                      label: 'Marketing Offers',
                      val: marketingOffers.value,
                      onChanged: (v) => marketingOffers.value = v,
                    ),
                    _SwitchRow(
                      label: 'Email Notifications',
                      val: emailNotifications.value,
                      onChanged: (v) => emailNotifications.value = v,
                    ),
                    _SwitchRow(
                      label: 'SMS Notifications',
                      val: smsNotifications.value,
                      onChanged: (v) => smsNotifications.value = v,
                    ),
                  ],
                ),
              ),

              _SettingsTile(
                title: 'Help & Support',
                icon: Icons.help_outline,
                isExpanded: false,
                onTap: () => context.push('/customer/support'),
                expandedContent: const SizedBox.shrink(),
              ),

              const SizedBox(height: 48),

              // Logout Button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: handleLogout,
                  icon: const Icon(Icons.logout),
                  label: const Text('Logout'),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

IconData _addressIcon(String label) {
  final l = label.toLowerCase();
  if (l.contains('home') || l.contains('house')) return Icons.home;
  if (l.contains('work') || l.contains('office')) return Icons.work;
  return Icons.place;
}

class _SettingsTile extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool isExpanded;
  final VoidCallback onTap;
  final Widget expandedContent;

  const _SettingsTile({
    required this.title,
    required this.icon,
    required this.isExpanded,
    required this.onTap,
    required this.expandedContent,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        leading: Icon(icon, color: theme.colorScheme.primary),
        initiallyExpanded: isExpanded,
        onExpansionChanged: (expanded) => onTap(),
        children: [
          Padding(
            padding: const EdgeInsets.only(
              left: 16.0,
              right: 16.0,
              bottom: 16.0,
            ),
            child: expandedContent,
          ),
        ],
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  final String label;
  final bool val;
  final ValueChanged<bool> onChanged;

  const _SwitchRow({
    required this.label,
    required this.val,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      value: val,
      onChanged: onChanged,
      title: Text(
        label,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
      ),
      activeThumbColor: const Color(0xFFF0A500),
    );
  }
}
