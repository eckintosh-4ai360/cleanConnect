import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../widgets/customer_nav_bar.dart';
import '../../../../core/shared/widgets/eco_button.dart';
import '../../../../core/shared/widgets/eco_text_field.dart';

class ProfileSettingsScreen extends HookConsumerWidget {
  const ProfileSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Current active expanded section ('none', 'info', 'address', 'payment', 'notifications')
    final activeSection = useState('none');

    // Personal Info state
    final nameController = useTextEditingController(text: 'Eckintosh');
    final emailController = useTextEditingController(
      text: 'Mark.aggrey@ecowaste.com',
    );
    final phoneController = useTextEditingController(text: '+1 (555) 019-2834');
    final dobController = useTextEditingController(text: '12/11/1992');

    // Address Management state
    final addresses = useState<List<Map<String, String>>>([
      {'label': 'Home', 'details': '123 Green St, Eco City, 95210'},
      {'label': 'Office', 'details': '456 Corporate Way, Eco City, 95215'},
    ]);
    final newAddressLabelController = useTextEditingController();
    final newAddressDetailsController = useTextEditingController();

    // Payment Methods state
    final cardMethods = useState<List<Map<String, String>>>([
      {'type': 'Visa', 'last4': '4240', 'expiry': '12/28'},
      {'type': 'Mastercard', 'last4': '9938', 'expiry': '05/29'},
    ]);

    // Notifications state
    final pickupReminders = useState(true);
    final serviceUpdates = useState(true);
    final paymentConfirmations = useState(true);
    final marketingOffers = useState(false);
    final emailNotifications = useState(true);
    final smsNotifications = useState(false);

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    void handleLogout() {
      ref.read(authStateControllerProvider.notifier).logout();
      context.go('/login');
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      extendBody: true,
      bottomNavigationBar: const CustomerBottomNavBar(currentIndex: 4),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(left: 24.0, right: 24.0, top: 24.0, bottom: 100.0),
          child: Column(
            children: [
              // Avatar details
              const CircleAvatar(
                radius: 48,
                backgroundImage: NetworkImage(
                  'https://images.unsplash.com/photo-1534528741775-53994a69daeb',
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Mark Aggrey',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              const Text(
                'mark.aggrey@ecowaste.com',
                style: TextStyle(color: Colors.grey, fontSize: 13),
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
                    EcoTextField(
                      labelText: 'Full Name',
                      hintText: 'Mark Aggrey',
                      controller: nameController,
                    ),
                    EcoTextField(
                      labelText: 'Email Address',
                      hintText: 'mark.aggrey@ecowaste.com',
                      controller: emailController,
                    ),
                    EcoTextField(
                      labelText: 'Phone Number',
                      hintText: '+1 (555) 019-2834',
                      controller: phoneController,
                    ),
                    EcoTextField(
                      labelText: 'Date of Birth',
                      hintText: 'MM/DD/YYYY',
                      controller: dobController,
                    ),
                    const SizedBox(height: 8),
                    EcoButton(
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
                    ...addresses.value.map(
                      (addr) => Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: Icon(
                            addr['label'] == 'Home' ? Icons.home : Icons.work,
                            color: theme.colorScheme.primary,
                          ),
                          title: Text(
                            addr['label']!,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            addr['details']!,
                            style: const TextStyle(fontSize: 12),
                          ),
                          trailing: IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Colors.red,
                            ),
                            onPressed: () {
                              final list = List<Map<String, String>>.from(
                                addresses.value,
                              );
                              list.remove(addr);
                              addresses.value = list;
                            },
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
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: newAddressLabelController,
                            decoration: const InputDecoration(
                              labelText: 'Label (e.g. Work)',
                              contentPadding: EdgeInsets.all(12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: newAddressDetailsController,
                            decoration: const InputDecoration(
                              labelText: 'Full Address details',
                              contentPadding: EdgeInsets.all(12),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    EcoButton(
                      text: 'Add Address',
                      onPressed: () {
                        if (newAddressLabelController.text.isNotEmpty &&
                            newAddressDetailsController.text.isNotEmpty) {
                          final list = List<Map<String, String>>.from(
                            addresses.value,
                          );
                          list.add({
                            'label': newAddressLabelController.text.trim(),
                            'details': newAddressDetailsController.text.trim(),
                          });
                          addresses.value = list;
                          newAddressLabelController.clear();
                          newAddressDetailsController.clear();
                        }
                      },
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
                    EcoButton(
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
      activeColor: const Color(0xFFF0A500),
    );
  }
}
